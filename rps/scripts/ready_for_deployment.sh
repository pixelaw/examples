#!/bin/bash

while true; do
  response=$(curl -s http://localhost:3000/manifests/core)
  if [[ $response != *"Not Found"* ]]; then
    echo "Ready for app deployment"
    break
  fi
  sleep 1
done
