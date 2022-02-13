#!/bin/sh
# OmniSharp-Roslyn Installer
#
# Works on: Linux, macOS & Cygwin/WSL & MinGW

usage() {
    printf "usage: %s [-HMuh] [-v version] [-l location]\\n" "$0"
}

print_help() {
    cat << EOF
$(usage)

Options:
    -v <version>  | Version to install (if omitted, fetch latest)
    -l <location> | Directory to install the server to (upon install, this directory will be cleared)
    -6            | Use the net6.0 server version
    -u            | Usage info
    -h            | Help message
    -H            | Install the HTTP version of the server
    -M            | Use the system Mono rather than the bundled Mono
    -W            | Use the Windows version of the server (used from WSL)
EOF
}

get_latest_version() {
    if command -v curl >/dev/null 2>&1 ; then
        curl --user-agent "curl" --silent "https://api.github.com/repos/OmniSharp/omnisharp-roslyn/releases/latest"
    elif command -v wget >/dev/null 2>&1 ; then
        wget -qO- "https://api.github.com/repos/OmniSharp/omnisharp-roslyn/releases/latest"
    fi | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

location="$HOME/.omnisharp/"

while getopts v:l:6HMWuh o "$@"
do
    case "$o" in
        v)      version="$OPTARG";;
        l)      location="$OPTARG";;
        6)      net6=1;;
        H)      http=".http";;
        M)      mono=1;;
        W)      windows=1;;
        u)      usage && exit 0;;
        h)      print_help && exit 0;;
        [?])    usage && exit 1;;
    esac
done

# Ensure that either 'curl' or 'wget' is installed
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1 ; then
    echo "Error: the installer requires either 'curl' or 'wget'"
    exit 1
fi

# Check that either 'tar' or 'unzip' is installed
# (and set the file extension appropriately)
if command -v tar >/dev/null 2>&1 && command -v gzip >/dev/null 2>&1 ; then
    ext="tar.gz"
elif command -v unzip >/dev/null 2>&1 ; then
    ext="zip"
else
    echo "Error: the installer requires either 'tar' or 'unzip'"
    exit 1
fi

# If not installing in mono mode
if [ -z "$mono" ]; then
    # Check the machine architecture
    case "$(uname -m)" in
        "x86_64")   machine="x64";;
        "i368")     machine="x86";;
        "arm64")    machine="arm64";;
        "aarch64")    machine="arm64";;
        *)
            echo "Error: architecture not supported"
            exit 1
            ;;
    esac
fi

if [ -n "$mono" ]; then
    os="mono"
else
    case "$(uname -s)" in
        "Linux")
            if [ -n "$net6" ]; then
                os="linux-${machine}-net6.0"
            else
                os="linux-${machine}"
            fi
            ;;
        "Darwin")
            if [ -n "$net6" ]; then
                os="osx-${machine}-net6.0"
            else
                os="osx"
            fi
            ;;
        *)
            if [ "$(uname -o)" = "Cygwin" ]; then
                os="win-${machine}"

                if command -v unzip >/dev/null 2>&1 ; then
                    ext="zip"
                else
                    echo "Error: the installer requires 'unzip' to work on Cygwin"
                    exit 1
                fi
            elif [ "$(uname -o)" = "Msys" ]; then
                os="win-${machine}"

                if command -v unzip >/dev/null 2>&1 ; then
                    ext="zip"
                else
                    echo "Error: the installer requires 'unzip' to work on MinGW"
                    exit 1
                fi
            else
                printf "Error: unknown system: %s\\n" "$(uname -s)"
                exit 1
            fi
            ;;
    esac
fi

if [ -n "$windows" ]; then
  os="win-${machine}"

  if command -v unzip >/dev/null 2>&1 ; then
    ext="zip"
  else
    echo "Error: the installer requires 'unzip' to work on WSL"
    exit 1
  fi
fi

file_name="omnisharp${http}-${os}.${ext}"

[ -z "$version" ] && version="$(get_latest_version)"

base_url="https://github.com/OmniSharp/omnisharp-roslyn/releases/download"
full_url="${base_url}/${version}/${file_name}"
# echo "$full_url"

download_location="${location}-${version}"

rm -rf "$download_location"
mkdir -p "$download_location"

if command -v curl >/dev/null 2>&1 ; then
    curl -L "$full_url" -o "$download_location/$file_name"
elif command -v wget >/dev/null 2>&1 ; then
    wget -P "$download_location" "$full_url"
fi

# Check if the server was successfully downloaded
if [ $? -gt 0 ] || [ ! -f "$download_location/$file_name" ]; then
    echo "Error: failed to download the server, possibly a network issue"
    exit 1
fi

set -eu
if [ "$ext" = "zip" ]; then
    unzip "$download_location/$file_name" -d "$download_location/"
    find "$download_location" -type f -exec chmod +x {} +
else
    tar -zxvf "$download_location/$file_name" -C "$download_location/"
fi

rm -rf "$location"
mv "$download_location" "$location"
set +eu

# If using the system Mono, make the files executable
if [ -n "$mono" ] && [ $mono -eq 1 ]; then
    find "$location" -type f -exec chmod +x {} +
fi

echo "$version" > "$location/OmniSharpInstall-version.txt"

exit 0
