#!/bin/bash

# Download the ruleset converter if we dont have it already
BIN="ruleset_converter"
if [[ ! -x ${BIN} ]]; then
    URL="$(curl -sLI -o /dev/null -w '%{url_effective}' 'https://github.com/bromite/bromite/releases/latest/')"
    URL="${URL//tag/download}/${BIN}"
    echo "Downloading ${URL}"
    curl -L "${URL}" -o ${BIN}
    if file ${BIN}|grep -q "ELF"; then
        echo "file ok"
        chmod +x ${BIN}
    else
        rm ${BIN}
        echo "Download failed" 1>&2
        exit 1
    fi;
fi;

NOW=$(date "+%s")
DOWNLOADED=false
FILES=""
unset IFS

shopt -s lastpipe
sed 's/#.*//' filters.conf | grep -E '\S+*\s+https?://\S+\s*$' | readarray -t CONFIG

if [[ ! -d lists ]]; then
    mkdir lists
fi

for LINE in "${CONFIG[@]}"; do
    # Shellcheck: SC2206
    read -r -a ARGS <<< "${LINE}"
    FILE="lists/${ARGS[0]}.txt"
    URL="${ARGS[1]}"
    if [[ -f "${FILE}" ]]; then
        FTIME=$(stat -L --format %Y "$FILE")
        if [[ $(( (NOW - FTIME) > 8*3600 )) == 1 ]]; then
                echo "Updating ${FILE}"
            curl -Lsf --connect-timeout 8 -o "${FILE}" -z "${FILE}" "${URL}" && DOWNLOADED=true
        fi
    else
        echo "Downloading ${FILE}"
        curl -Lsf --connect-timeout 8 -o "${FILE}" "${URL}" && DOWNLOADED=true
    fi
    [[ -f "${FILE}" ]] && FILES="${FILES},${FILE}"
done

FILES="${FILES:1}"

if [[ "$DOWNLOADED" == "true" || ! -f filters.dat ]]; then
    echo Creating filters.dat
    if [[ ! -d build ]]; then
        mkdir build
    fi
    ./ruleset_converter --input_format=filter-list --output_format=unindexed-ruleset \
    --input_files="${FILES}" --output_file=build/filters.dat &> /dev/null
    exit 0
fi

exit 2
