#!/bin/bash

wait_for_local_katana() {
  while true; do
    response=$(curl --write-out '%{http_code}' --silent --output /dev/null http://localhost:5050)
    if [ "$response" -eq 200 ]; then
      break
    else
      echo "Waiting for katana at http://localhost:5050"
      sleep 2
    fi
  done
}

deploy_local() {
  APP_NAME=$1
  PROFILE=dev
  wait_for_local_katana
  deploy $APP_NAME $PROFILE
}

# Function to start app
deploy() {
    echo "Starting $1"
    APP_NAME=$1
    PROFILE=$2
    pushd $APP_NAME

    sozo --profile $PROFILE migrate

    export ACTIONS_ADDRESS=$(cat ./target/dev/manifest.json | jq -r --arg APP_NAME "$APP_NAME" '.contracts[] | select(.name | contains($APP_NAME)) | .address')

    echo "---------------------------------------------------------------------------"
    echo app : $APP_NAME
    echo " "
    echo actions : $ACTIONS_ADDRESS
    echo "---------------------------------------------------------------------------"

    # enable system -> component authorizations
    COMPONENTS=($(jq -r --arg APP_NAME "$APP_NAME" '.models[] | select(.name | contains($APP_NAME)) | .name' ./target/dev/manifest.json))

    for index in "${!COMPONENTS[@]}"; do
        IFS='::' read -ra NAMES <<< "${COMPONENTS[index]}"
        LAST_INDEX=${#NAMES[@]}-1
        NEW_NAME=`echo ${NAMES[LAST_INDEX]} | sed -r 's/_/ /g' | awk '{for(j=1;j<=NF;j++){ $j=toupper(substr($j,1,1)) substr($j,2) }}1' | sed -r 's/ //g'`
        COMPONENTS[index]=$NEW_NAME
    done

    # if #COMPONENTS is 0, then there are no models in the manifest. This might be error,
    echo "Write permissions for ACTIONS"
    if [ ${#COMPONENTS[@]} -eq 0 ]; then
        echo "Warning: No models found in manifest.json. Are you sure you don't have new any components?"
    else
        for component in ${COMPONENTS[@]}; do
            echo "For $component"
            sozo --profile $PROFILE auth grant writer $component,$ACTIONS_ADDRESS
            sleep 0.1
        done
    fi
    echo "Write permissions for ACTIONS: Done"

    echo "Initialize ACTIONS: (sozo --profile $PROFILE execute -v $ACTIONS_ADDRESS init)"
    sleep 0.1
    sozo --profile $PROFILE execute -v $ACTIONS_ADDRESS init
    echo "Initialize ACTIONS: Done"

    echo "Default authorizations have been successfully set."

    MANIFEST_URL="http://localhost:3000/manifests"
    MANIFEST_URL="$MANIFEST_URL/$APP_NAME"
    JSON_FILE="./target/$PROFILE/manifest.json"


    echo "---------------------------------------------------------------------------"
    echo URL : $MANIFEST_URL
    echo "---------------------------------------------------------------------------"

    # Send a POST request to the URL with the contents of the JSON file
    echo "Uploading $JSON_FILE to $MANIFEST_URL"
    curl -X POST -H "Content-Type: application/json" -d @"$JSON_FILE" "$MANIFEST_URL"
    echo " "

    popd
}

# Function to stop app
stop_app() {
    echo "Stopping $1"
    # Add your command to stop the app here
}

# Function to restart app
restart_app() {
    echo "Restarting $1"
    # Add your command to restart the app here
}

# Check if APP_NAME is provided
if [ -z "$1" ]
then
    echo "No APP_NAME provided"
    exit 1
fi

APP_NAME=$1

# Call functions
deploy_local $APP_NAME
