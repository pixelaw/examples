#!/bin/bash

wait_for_local_katana() {
  while true; do
    response=$(curl --write-out '%{http_code}' --silent --output /dev/null http://localhost:5050)
    if [ "$response" -eq 200 ]; then
      break
    else
      echo "Waiting for katana at http://localhost:5050 - on MacOS this can take a while"
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

deploy_dojo() {
  APP_NAME=$1
  PROFILE=dojo
  MANIFEST_URL="https://dojo.pixelaw.xyz/manifests"
  deploy $APP_NAME $PROFILE $MANIFEST_URL
}



# Function to start app
deploy() {
    echo "Deploying $1 to $2"
    APP_NAME=$1
    PROFILE=$2
    pushd $APP_NAME

    sozo --profile $PROFILE build
    sozo --profile $PROFILE migrate plan
    sozo --profile $PROFILE migrate apply

    export ACTIONS_ADDRESS=$(cat ./manifests/$PROFILE/manifest.json | jq -r --arg APP_NAME "$APP_NAME" '.contracts[] | select(.name | contains($APP_NAME)) | .address')

    echo "---------------------------------------------------------------------------"
    echo app : $APP_NAME
    echo " "
    echo actions : $ACTIONS_ADDRESS
    echo "---------------------------------------------------------------------------"

    # enable system -> component authorizations
    COMPONENTS=($(jq -r --arg APP_NAME "$APP_NAME" '.models[] | select(.name | contains($APP_NAME)) | .name' ./manifests/$PROFILE/manifest.json))

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
            sozo --profile $PROFILE auth grant --wait writer $component,$ACTIONS_ADDRESS
        done
    fi
    echo "Write permissions for ACTIONS: Done"

    echo "Initialize ACTIONS: (sozo --profile $PROFILE execute -v $ACTIONS_ADDRESS init)"
    sozo --profile $PROFILE execute --wait -v $ACTIONS_ADDRESS init
    echo "Initialize ACTIONS: Done"

    echo "Default authorizations have been successfully set."

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
