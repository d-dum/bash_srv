#!/usr/bin/env bash

# shellcheck source=lib.sh
source "./lib.sh"

# $1 json request body
function helloRequestHandler {
    resp=$(http_response "<p>${1}<p>" 'text/html' '200')
    echo "${resp}"
}

add_handler "POST" "/" "$(declare -f helloRequestHandler)" helloRequestHandler
start_server 8080