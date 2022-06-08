# OmniSharp-roslyn Management tool
#
# Works on: Microsoft Windows

# Options:
# -v | version to use (otherwise use latest)
# -l | where to install the server
# -6 | install the net6.0 server version
# -u | help / usage info
# -H | install the HTTP version of the server

[CmdletBinding()]
param(
    [Parameter()][Alias('v')][string]$version,
    [Parameter()][Alias('l')][string]$location = "$($Env:USERPROFILE)\.omnisharp\",
    [Parameter()][Alias('6')][Switch]$use_net6,
    [Parameter()][Alias('u')][Switch]$usage,
    [Parameter()][Alias('H')][Switch]$http_check
)

if ($usage) {
    Write-Host "usage:" $MyInvocation.MyCommand.Name "[-Hu] [-v version] [-6] [-l location]"
    exit
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function get_latest_version() {
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/OmniSharp/omnisharp-roslyn/releases/latest"
    return $response.tag_name
}

if ([string]::IsNullOrEmpty($version)) {
    $version = get_latest_version
}

if ($use_net6) {
    $net6 = "-net6.0"
} else {
    $net6 = ""
}

if ($http_check) {
    $http = ".http"
} else {
    $http = ""
}

if ([Environment]::Is64BitOperatingSystem) {
    $machine = "x64"
} else {
    $machine = "x86"
}

$url = "https://github.com/OmniSharp/omnisharp-roslyn/releases/download/$($version)/omnisharp$($http)-win-$($machine)$($net6).zip"
$out = "$($location)\omnisharp$($http)-win-$($machine).zip"

if (Test-Path -Path $location) {
    Remove-Item $location -Force -Recurse
}

New-Item -ItemType Directory -Force -Path $location | Out-Null

Invoke-WebRequest -Uri $url -OutFile $out

# Run Expand-Archive in versions that support it
if ($PSVersionTable.PSVersion.Major -gt 4) {
    Expand-Archive $out $location -Force
} else {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($out, $location)
}

# Check for file to confirm download and unzip were successful
if (Test-Path -Path "$($location)\OmniSharp.Roslyn.dll") {
    Set-Content -Path "$($location)\OmniSharpInstall-version.txt" -Value "$($version)"
    exit 0
} else {
    exit 1
}
