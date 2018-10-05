# OmniSharp-roslyn Management tool
#
# Works on: Microsoft Windows

# Options:
# -v | version to use (otherwise use latest)
# -l | where to install the server
# -u | help / usage info
# -H | install the HTTP version of the server

[CmdletBinding()]
Param(
    [Parameter()][Alias('v')][string]$version,
    [Parameter()][Alias('l')][string]$location = "$($env:USERPROFILE)\.omnisharp\",
    [Parameter()][Alias('u')][switch]$usage,
    [Parameter()][Alias('H')][switch]$http_check
)

if ($usage) {
    Write-Host "usage:" $MyInvocation.MyCommand.Name "[-Hu] [-v version] [-l location]"
    exit
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function get_latest_version() {
    $tmp = Invoke-RestMethod -Uri "https://api.github.com/repos/OmniSharp/omnisharp-roslyn/releases/latest"
    return $tmp.tag_name
}

if ([string]::IsNullOrEmpty($version)) {
    $version = get_latest_version
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

$url = "https://github.com/OmniSharp/omnisharp-roslyn/releases/download/$($version)/omnisharp$($http)-win-$($machine).zip"
$out = "$($location)\omnisharp$($http)-win-$($machine).zip"

if (Test-Path -Path $location) {
    Remove-Item $location -Force -Recurse
}
New-Item -ItemType Directory -Force -Path $location | Out-Null

#Run as SilentlyContinue to avoid progress bar that can't be seen
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $url -OutFile $out

#Run Expand-Archive in versions that support it
if ($PSVersionTable.PSVersion.Major -gt 4)
{
    Expand-Archive $out -DestinationPath $location -Force
}
else
{
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory( $out, $location )
}

#Check for file to confirm download and unzip were successful
if(Test-Path -path "$($location)\OmniSharp.Roslyn.dll")
{
    exit 0
}
else
{
    exit 1
}
