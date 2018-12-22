#!/bin/sh
# OmniSharp-Roslyn Installer
#
# Works on: Linux, macOS & Cygwin/WSL

usage() {
    printf "usage: %s [-HMuh] [-v version] [-l location]\\n" "$0"
}

print_help() {
    cat << EOF
$(usage)

Options:
    -v <version>  | Version to install (if omitted, fetch latest)
    -l <location> | Directory to install the server to (upon install, this directory will be cleared)
    -u            | Usage info
    -h            | Help message
    -H            | Install the HTTP version of the server
    -M            | Use the system Mono rather than the bundled Mono
EOF
}

get_latest_version() {
    if [ "$(command -v curl)" ]; then
        curl --silent "https://api.github.com/repos/OmniSharp/omnisharp-roslyn/releases/latest"
    elif [ "$(command -v wget)" ]; then
        wget -qO- "https://api.github.com/repos/OmniSharp/omnisharp-roslyn/releases/latest"
    fi | grep '"tag_name":' | sed 's/.*"\([^"]\+\)".*/\1/'
}

location="$HOME/.omnisharp/"

# TODO: Remove this default when omnisharp-roslyn #1274 is fixed:
# https://github.com/OmniSharp/omnisharp-roslyn/issues/1274
version='v1.32.1'

while getopts v:l:HMuh o "$@"
do
    case "$o" in
        v)      version="$OPTARG";;
        l)      location="$OPTARG";;
        H)      http=".http";;
        M)      mono=1;;
        u)      usage && exit 0;;
        h)      print_help && exit 0;;
        [?])    usage && exit 1;;
    esac
done

# Ensure that either 'curl' or 'wget' is installed
if [ ! "$(command -v curl)" ] && [ ! "$(command -v wget)" ]; then
    echo "Error: the installer requires either 'curl' or 'wget'"
    exit 1
fi

# Check that either 'tar' or 'unzip' is installed
# (and set the file extension appropriately)
if [ "$(command -v tar)" ] && [ "$(command -v gzip)" ]; then
    ext="tar.gz"
elif [ "$(command -v unzip)" ]; then
    ext="zip"
else
    echo "Error: the installer requires either 'tar' or 'unzip'"
    exit 1
fi

# Check the machine architecture
case "$(uname -m)" in
    "x86_64")   machine="x64";;
    "i368")     machine="x86";;
    *)
        echo "Error: OmniSharp-Roslyn only works on x86 CPU architecture"
        exit 1
        ;;
esac

# Check the operating system
case "$(uname -s)" in
    "Linux")    os="linux-${machine}";;
    "Darwin")   os="osx";;
    *)
        if [ "$(uname -o)" = "Cygwin" ]; then
            os="win-${machine}"

            if [ "$(command -v unzip)" ]; then
                ext="zip"
            else
                echo "Error: the installer requires 'unzip' to work on Cygwin"
                exit 1
            fi
        else
            printf "Error: unknown system: %s\\n" "$(uname -s)"
            exit 1
        fi
        ;;
esac

[ -n "$mono" ] && os="mono"

file_name="omnisharp${http}-${os}.${ext}"

[ -z "$version" ] && version="$(get_latest_version)"

base_url="https://github.com/OmniSharp/omnisharp-roslyn/releases/download"
full_url="${base_url}/${version}/${file_name}"
# echo "$full_url"

rm -r "$location"
mkdir -p "$location"

if [ "$(command -v curl)" ]; then
    curl -L "$full_url" -o "$location/$file_name"
elif [ "$(command -v wget)" ]; then
    wget -P "$location" "$full_url"
fi

# Check if the server was successfully downloaded
if [ $? -gt 0 ] || [ ! -f "$location/$file_name" ]; then
    echo "Error: failed to download the server, possibly a network issue"
    exit 1
fi

if [ "$ext" = "zip" ]; then
    unzip "$location/$file_name" -d "$location/"
    chmod +x $(find "$location" -type f)
else
    tar -zxvf "$location/$file_name" -C "$location/"
fi

# If using the system Mono, make the files executable
if [ -n "$mono" ] && [ $mono -eq 1 ]; then
    chmod +x $(find "$location" -type f)
fi

exit 0
