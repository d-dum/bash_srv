#!/usr/bin/env bash

# shellcheck source=lib.sh
source "./lib.sh"

# $1 json request body
# $2 header JSON object
# $3 request parameters
function helloRequestHandler {
    resp=$(http_response "<p>${2}</p><p>${1}</p><p>${3}</p>" 'text/html' '200')
    echo "${resp}"
}

function helloGetRequestHandler {
    resp=$(http_response "${2}" "application/json" "200")
    echo "${resp}"
}

add_handler "POST" "/test" "$(declare -f helloRequestHandler)" helloRequestHandler
add_handler "GET" "/" "$(declare -f helloGetRequestHandler)" helloGetRequestHandler
start_server 8080