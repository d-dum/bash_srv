#!/usr/bin/env bash

rm -f response
mkfifo response

declare -A HTTP_HANDLERS=()


# $1 = METHOD
# $2 = PATH
# $3 = handler body (function body) see example
# $4 = handler name
function add_handler {
    local METHOD="${1}"
    local HANDLER_PATH="${2}"
    local REQUEST_PATH="${METHOD} ${HANDLER_PATH}"
    HTTP_HANDLERS["${REQUEST_PATH}"]="${3};${4}"
}

function parse_headers {
    declare -a argAry1=("${!1}")
    local out_headers="{"
    local first=true
    IFS=": "
    for header in "${!argAry1[@]}"; do
        read -ra header_arr <<< "${argAry1[${header}]}"
        local key="${header_arr[0]}"
        local val="${header_arr[1]}"
        if [[ "${first}" = true ]]
        then
            out_headers="${out_headers}\"${key}\": \"${val}\""
            first=false
        else
            out_headers="${out_headers},\"${key}\": \"${val}\""
        fi
    done
    out_headers="${out_headers}}"
    echo "${out_headers}"
}

# $1 = response body
# $2 = content type
# $3 = status
function http_response {
    local HTTP_HEAD="HTTP/1.1"
    local body="${1}"
    local status="${3}"
    if [[ ${status} = "" ]]
    then
        status="200"
    fi

    case "${status}" in
        "200") status="200 OK" ;;
        "404") status="404 NotFound" ;;
            *) status="${status}" ;;
    esac

    local content_type="${2}"

    if [[ ${status} = "200 OK" ]]
    then
        echo "${HTTP_HEAD} ${status}\r\nContent-Type: ${content_type}\r\n\r\n${body}"
    else
        echo "${HTTP_HEAD} ${status}\r\n\r\n\r\n${status}"
    fi
}

function general_request_handler {
    local headers=()
    local REQUEST=""
    local CONTENT_LENGTH=""
    local JSON=""
    while read -r line; do
        echo "${line}"
        trline=$(echo "${line}" | tr -d '\r\n')

        [[ -z "${trline}" ]] && break

        [[ ! "${trline}" =~ ${HEADLINE_REGEX} ]] &&
            headers+=("${trline}")
        
        local HEADLINE_REGEX='(.*?)\s(.*?)\sHTTP.*?'
        [[ "${trline}" =~ ${HEADLINE_REGEX} ]] &&
            REQUEST=$(echo "${trline}" | sed -E "s/${HEADLINE_REGEX}/\1 \2/")
        
        local CONTENT_LENGTH_REGEX='Content-Length:\s(.*?)'
        [[ "${trline}" =~ ${CONTENT_LENGTH_REGEX} ]] &&
            CONTENT_LENGTH=$(echo "${trline}" | sed -E "s/${CONTENT_LENGTH_REGEX}/\1/")
    done

    echo "REQUEST: ${REQUEST}"
    if [[ ! -z "${CONTENT_LENGTH}" ]]
    then
        echo "HERE"
        while read -r -n"${CONTENT_LENGTH}" -t1 body; do
            JSON="${body}"
            break
        done
    fi

    local parsed_headers=""
    parsed_headers=$(parse_headers headers[@])
    
    local RESPONSE=""

    if [[ -n "${HTTP_HANDLERS[${REQUEST}]}" ]]
    then
        local handler="${HTTP_HANDLERS[${REQUEST}]}"
        RESPONSE=$(eval "${handler} '${JSON}' '${parsed_headers}'")
    else
        RESPONSE="HTTP/1.1 404 NotFound\r\n\r\n\r\nNot Found"
    fi

    echo -e "${RESPONSE}" > response
}

# $1 = port
function start_server {
    if [[ "${1}" = "" ]] 
    then
        LPORT="3000"
    else
        LPORT="${1}"
    fi
    while true; do
        cat response | nc -lvN "${LPORT}" | general_request_handler
    done
}