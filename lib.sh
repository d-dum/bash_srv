#!/usr/bin/env bash

rm -f response
mkfifo response

declare -A HTTP_HANDLERS=()


# $1 = METHOD
# $2 = PATH
# $3 = handler body (function body) see example
# $4 = handler name
function add_handler {
    METHOD="${1}"
    HANDLER_PATH="${2}"
    REQUEST_PATH="${METHOD} ${HANDLER_PATH}"
    HTTP_HANDLERS["${REQUEST_PATH}"]="${3};${4}"
}

# $1 = response body
# $2 = content type
# $3 = status
function http_response {
    # TODO: headers
    HTTP_HEAD="HTTP/1.1"
    body="${1}"
    status="${3}"
    if [[ ${status} = "" ]]
    then
        status="200"
    fi

    # TODO: implement all status codes
    case "${status}" in
        "200") status="200 OK" ;;
        "404") status="404 NotFound" ;;
            *) status="200 OK" 
    esac

    content_type="${2}"

    if [[ ${status} = "200 OK" ]]
    then
        echo "${HTTP_HEAD} ${status}\r\nContent-Type: ${content_type}\r\n\r\n${body}"
    else
        echo "${HTTP_HEAD} ${status}\r\n\r\n\r\n${status}"
    fi
}

function general_request_handler {
    while read -r line; do
        echo "${line}"
        trline=$(echo "${line}" | tr -d '\r\n')

        [[ -z "${trline}" ]] && break

        HEADLINE_REGEX='(.*?)\s(.*?)\sHTTP.*?'
        [[ "${trline}" =~ ${HEADLINE_REGEX} ]] &&
            REQUEST=$(echo "${trline}" | sed -E "s/${HEADLINE_REGEX}/\1 \2/")
        
        CONTENT_LENGTH_REGEX='Content-Length:\s(.*?)'
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

    echo "${JSON}"

    # case "${REQUEST}" in
    #     "GET /") RESPONSE="HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n</h1>PONG</h1>" ;;
    #           *) RESPONSE="HTTP/1.1 404 NotFound\r\n\r\n\r\nNot Found" ;;
    # esac

    if [[ -n "${HTTP_HANDLERS[${REQUEST}]}" ]]
    then
        handler="${HTTP_HANDLERS[${REQUEST}]}"
        RESPONSE=$(eval "${handler} '${JSON}'")
    else
        RESPONSE="HTTP/1.1 404 NotFound\r\n\r\n\r\nNot Found"
    fi

    echo "${RESPONSE}"

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