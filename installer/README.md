# OmniSharp Installers

The OmniSharp installers are scripts that OmniSharp-vim uses to install the OmniSharp Roslyn server if it is not able to find it when opening a .cs file. There is a shell (.sh) version for Linux, macOS, & Cygwin/WSL and there is a PowerShell (.ps1) version for Windows.

## PowerShell

### Usage

```powershell
.\omnisharp-manager.ps1 [-v \<VersionNumber\>] [-l \<InstallLocation\>] [-u] [-H]
```

Flags | Description
----- | -----------
 -v \<VersionNumber\> | version number of server to install (default: the latest version)
 -l \<InstallLocation\> | where to install the server (default: '%USERPROFILE%\\.omnisharp\')
 -u | help / usage info
 -H | install the HTTP version of the server

### Output

After downloading and installing the server the script will check for the `OmniSharp.Roslyn.dll` library in the install directory. If it locates the file an exit code of `0` will be returned. If it does not it will return a `1`. You can check exit codes in PowerShell by running `$LASTEXITCODE` in the console after running the script.

### Examples

In PowerShell the following will install the v1.32.1 HTTP version of the OmniSharp Roslyn server in `\.omnisharp\omnisharp-roslyn` in the %USERPROFILE% directory:
>`./omnisharp-manager.ps1 -v 'v1.32.1' -H -l "$env:USERPROFILE/.omnisharp/omnisharp-roslyn"`

*Note:* You must run this from the directory that contains the script to run it. This will vary but is typically `\omnisharp-vim\installer` inside the directory where your vim plugins are located.

> On completion the `omnisharp-manager.ps1` script will check that the `OmniSharp.Roslyn.dll` file is in the expected directory. If it finds the file it will return and exit code of `0`. If it does not find the file it will return `1`. You can check exit codes in PowerShell by running `$LASTEXITCODE` in the console after running the script.

---

#### Footnotes [fn \#]

[1]: Each time a .cs file is opened the OmniSharp-vim plugin checks if OmniSharp Roslyn server is already installed. If not then it runs the `omnisharp-manager.ps1` script. It typically checks the `%USERPROFILE%\.omnisharp\omnisharp-roslyn` directory.
