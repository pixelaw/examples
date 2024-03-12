#!/bin/bash

APP_NAME=$(grep "^name" Scarb.toml | awk -F' = ' '{print $2}' | tr -d '"')

MANIFEST_URL=$(scarb metadata --format-version 1 | jq -r --arg APP_NAME "$APP_NAME" '.packages[] | select(.name | index($APP_NAME)) | .tool.dojo.env.manifest_url')
MANIFEST_URL="http://localhost:3000/manifests"
MANIFEST_URL="$MANIFEST_URL/$APP_NAME"
JSON_FILE="./target/$SCARB_PROFILE/manifest.json"


echo "---------------------------------------------------------------------------"
echo URL : $MANIFEST_URL
echo "---------------------------------------------------------------------------"

# Send a POST request to the URL with the contents of the JSON file
echo "Uploading $JSON_FILE to $MANIFEST_URL"
curl -X POST -H "Content-Type: application/json" -d @"$JSON_FILE" "$MANIFEST_URL"
echo " "
