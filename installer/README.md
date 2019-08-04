# OmniSharp-Roslyn server management scripts

The OmniSharp installer scripts are used by OmniSharp-vim to automate the installation and updating of the [OmniSharp-Rosyln server](https://github.com/OmniSharp/omnisharp-roslyn). There is a script for [Linux, macOS and Cygwin/WSL](#unix-like-oss), and another for [Microsoft Windows](#microsoft-windows).

## Unix-like OSs

_Works on: Linux, Apple macOS, Cygwin and Windows Subsystem for Linux._

### Usage

```
./omnisharp-manager.sh [-v VERSION] [-l PATH] [-HMuh]
```

| Option       | Description                                                                                 |
|--------------|---------------------------------------------------------------------------------------------|
| `-v VERSION` | Version number of the server to install (defaults to the latest verison).                   |
| `-l PATH`    | Location to install the server to (defaults to `$HOME/.omnisharp/`).                        |
| `-H`         | Install the HTTP variant of the server (if not given, the stdio variant will be installed). |
| `-M`         | Use the system Mono installation rather than the one packaged with OmniSharp-Roslyn.        |
| `-u`         | Display simple usage information.                                                           |
| `-h`         | Display this help message.                                                                  |

## Microsoft Windows

_Works on: Microsoft Windows._

### Usage

```
.\omnisharp-manager.ps1 [-v VERSION] [-l PATH] [-Hu]
```

| Option       | Description                                                                                 |
|--------------|---------------------------------------------------------------------------------------------|
| `-v VERSION` | Version number of server to install (defaults to the latest version).                       |
| `-l PATH`    | Location to install the server to (defaults to `%USERPROFILE%\.omnisharp\`).                |
| `-H`         | Install the HTTP variant of the server (if not given, the stdio variant will be installed). |
| `-u`         | Display simple usage information.                                                           |

### Output

After downloading and installing the server the script will check for the `OmniSharp.Roslyn.dll` library in the install directory. If it locates the file an exit code of `0` will be returned. If it does not it will return a `1`. You can check exit codes in PowerShell by running `$LASTEXITCODE` in the console after running the script.

### Examples

In PowerShell, the following will install version 1.32.1 of the HTTP OmniSharp Roslyn server in the `%USERPROFILE%\.omnisharp\omnisharp-roslyn` directory.

```powershell
cd "C:\Users\My Name\vimfiles\pack\plugins\opt\omnisharp-vim" # Navigate to the OmniSharp-vim plugin directory
.\installer\omnisharp-manager.ps1 -v "v1.32.1" -H -l "$Env:USERPROFILE\.omnisharp\omnisharp-roslyn"
```
