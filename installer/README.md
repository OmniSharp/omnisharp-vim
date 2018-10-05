# OmniSharp Installers
The OmniSharp installers are scripts that omnisharp-vim uses to install the OmniSharp Roslyn server if it is not able to find it when opening a .cs file. There is a shell (.sh) version for Linux, macOS, & Cygwin/WSL and there is a PowerShell (.ps1) version for Windows.

## omnisharp-manager PowerShell script

### Usage Syntax
> omnisharp-manager.ps1 [-v \<VersionNumber\>] [-l \<InstallLocation\>] [-u] [-H]

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


## PowerShell Restrictions
By default PowerShell will prevent scripts being executed through what it terms its *Execution Policy*. But on Windows the `omnisharp-manager.ps1` script needs to execute to install the OmniSharp Roslyn server. In the __Install Omnisharp-Roslyn with PowerShell__ section below there are instructions for changing your PowerShell Execution Policy and getting the latest version of the server installed. Alternatively, if you change your Power Execution Policy to Unrestricted using the first few steps below you can open a .cs file in Vim and omnisharp-vim will offer to do the installation for you.

### Install Omnisharp-Roslyn with PowerShell
1. Locate PowerShell in the Windows Start Menu
1. Right-click and choose `Run as administrator`
1. Use `Get-ExecutionPolicy -List` in PowerShell to verify and record your current settings
1. Use `Set-ExecutionPolicy Unrestricted` to change your policy followed by `Y` to confirm
1. Browse to the `\omnisharp-vim\installer` directory.
	* It should be wherever your vim plugins are located
1. Use `./omnisharp-manager.ps1 -H -l "$env:USERPROFILE/.omnisharp/omnisharp-roslyn"` from that directory to install the server [fn 1]
	* You can copy the command above and right-click will paste the clipboard into the PowerShell console
1. Once this has completed you can use `Set-ExecutionPolicy {previous setting}` using the previous setting recorded earlier. [fn 2]

> On completion the `omnisharp-manager.ps1` script will check that the `OmniSharp.Roslyn.dll` file is in the expected directory. If it finds the file it will return and exit code of `0`. If it does not find the file it will return `1`. You can check exit codes in PowerShell by running `$LASTEXITCODE` in the console after running the script.

---

#### Footnotes [fn \#]
[1]: Each time a .cs file is opened the OmniSharp-vim plugin checks if OmniSharp Roslyn server is already installed. If not then it runs the `omnisharp-manager.ps1` script. It typically checks the `%USERPROFILE%\.omnisharp\omnisharp-roslyn` directory.

[2]: By default this setting is `Undefined`; which means the restriction may be determined elsewhere but defaults to `Restricted`. Setting to `RemoteSigned` on a typical setup will allow omnisharp-vim to internally run the script in the future.  More at [About Execution Policies | Microsoft Docs](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-6)
