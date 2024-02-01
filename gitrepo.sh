#! /bin/bash

repo=""
zip=""
filter=""
tar=""

_usage="

    Usage: gitrepo -r <repo author/repo name> [-f] <filter> [-z] [-t]
    ---
    -r      Repo owner/name (ie awesomeauthorsname/greatrepo)
    -f      Filter applied to the list of the repo's asset names.
            If the filter doesn't match anything, none will be displayed
    -z      Download the zip file of the latest release
    -t      Download the tarball of the latest release
"
_prereqs="Script relies on Fzf for selection. Please install before continuing"

if [[ -z $(which fzf) ]]; then
    echo $_prereqs
    exit 2
fi

while getopts ":r:ftz:" o; do
case $o in
    z)
        zip="true"
        ;;
    t)
        tar="true"
        ;;
    r)
        repo=${OPTARG}
        ;;
    f)
        filter=${OPTARG}
        ;;
    *)
        echo $_usage
    esac
done

if [[ -z $repo ]]; then
    $_usage
fi

releases=$(curl -s https://api.github.com/repos/$repo/releases/latest)
assets_length=$(echo $releases | jq '.assets | length')

if [[ -n $zip ]]; then
    wget $(echo $releases | jq -r '.zipball_url')
fi

if [[ -n $tar ]]; then
    wget $(echo $releases | jq -r '.tarball_url')
fi

if [[ $assets_length -gt 0 ]]; then

    if [[ -z $filter ]]; then
        name=$(echo $releases | jq -r '.assets[] | .name' | fzf)
    else
        name=$(echo $releases | jq -r --arg filter "$filter" '.assets[] | select(.name | contains($filter)) | .name' | fzf)
    fi
    if [[ -n $name ]]; then
        wget -q --show-progress --content-disposition $(echo $releases | jq -r --arg name "$name" '.assets[] | select(.name | contains($name)) | .browser_download_url')
        exit 0
    else
        echo "No name specified. Canceling download"
        exit 0
    fi
else
    echo "No assets available. Possibly only available as a tarball or zip file."
    exit 0
fi
