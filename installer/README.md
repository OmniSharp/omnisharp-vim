#PowerShell Restrictions
PowerShell's default will disable scripts from being run. But on Windows the `omnisharp-manager.ps1` script needs to run to install the OmniSharp Roslyn server.

##Change PowerShell's Execution Policy
1. Locate PowerShell in the Windows Start Menu
2. Right-click and choose `Run as administrator`
3. Use `Get-ExecutionPolicy -List` in PowerShell to verify your current settings
4. Use `Set-ExecutionPolicy Unrestricted` to allow script to install OmniSharp Roslyn server
5. Run the `omnisharp-manager.ps1` script from the `omnisharp-vim\installer\` directory or you can simply open a .cs file in Vim[^1] with omnisharp-vim installed
6. Once this has completed you can use `Set-ExecutionPolicy {previous setting}` using the previous setting from step 3.[^2]
* On completion the `omnisharp-manager.ps1` script will check that the `OmniSharp.Roslyn.dll` files is in the expected directory. If it finds the file it will return a confirmation to that directory path. If it does not find the file it will return `Failure`.
[^1]: Each time a .cs file is opened the OmniSharp-vim plugin checks if OmniSharp Roslyn server is already installed. If not then it runs the `omnisharp-manager.ps1` script. It typically checks `$HOME\.omnisharp\omnisharp-roslyn\`.
[^2]: By default this setting is `Undefined`. The safest option is explicitly setting `Restricted` which will not allow PowerShell to run any scripts.
