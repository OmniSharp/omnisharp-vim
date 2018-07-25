#!/bin/sh
# OmniSharp-roslyn Management tool
#
# Works on: Linux, macOS & Cygwin/WSL

usage() {
    printf "usage: %s [-HMu] [-v version] [-l location]\\n" "$0"
}

# From: https://gist.github.com/lukechilds/a83e1d7127b78fef38c2914c4ececc3c
get_latest_version() {
    curl --silent "https://api.github.com/repos/OmniSharp/omnisharp-roslyn/releases/latest" |
    grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Options:
# -v | version to use (otherwise use latest)
# -l | where to install the server
# -u | help / usage info
# -H | install the HTTP version of the server
# -M | type of server: mono or regular

location="$HOME/.omnisharp/"

while getopts v:l:HMu o "$@"
do
    case "$o" in
        v)      version="$OPTARG";;
        l)      location="$OPTARG";;
        H)      http=".http";;
        M)      mono=1;;
        u)      usage && exit 0;;
        [?])    usage && exit 1;;
    esac
done

ext="tar.gz"

case "$(uname -m)" in
    "x86_64")   machine="x64";;
    "i368")     machine="x86";;
    *)          exit 1;;
esac
case "$(uname -s)" in
    "Linux")    os="linux-${machine}";;
    "Darwin")   os="osx";;
    *)
        if [ "$(uname -o)" = "Cygwin" ]; then
            os="win-${machine}"
            ext="zip"
        else
            printf "Error: unknown system: %s\\n" "$(uname -s)"
            exit 1
        fi
        ;;
esac
[ ! -z "$mono" ] && os="mono"
file_name="omnisharp${http}-${os}.${ext}"
[ -z "$version" ] && version="$(get_latest_version)"
base_url="https://github.com/OmniSharp/omnisharp-roslyn/releases/download"
full_url="${base_url}/${version}/${file_name}"
echo "$full_url"

rm -r "$location"
mkdir -p "$location"
curl -L "$full_url" -o "$location/$file_name"
if [ "$ext" = "zip" ]; then
    unzip "$location/$file_name" -d "$location/"
    chmod +x $(find "$location" -type f)
else
    tar -zxvf "$location/$file_name" -C "$location/"
fi
