#!/usr/bin/env bash
curl --header "Content-Type: application/json" \
  --request POST \
  --data '{"username":"xyz","password":"xyz", "dhufjdfh": "fff", "dddd": true}' \
  http://localhost:8080/test?param1=2