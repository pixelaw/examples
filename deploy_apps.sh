#!/bin/bash

# Simple deployment script for PixeLAW example apps

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

deploy_app() {
    APP_NAME=$1
    WORLD_ADDRESS=$2
    PROFILE=dev
    
    echo "Deploying $APP_NAME..."
    pushd $APP_NAME

    # Build and migrate
    sozo --profile $PROFILE build
    
    if [ -n "$WORLD_ADDRESS" ]; then
        echo "Deploying to existing world: $WORLD_ADDRESS"
        sozo --profile $PROFILE migrate --wait --world $WORLD_ADDRESS
    else
        echo "Deploying to new world"
        sozo --profile $PROFILE migrate --wait
    fi

    # Modern Dojo handles initialization automatically via dojo_init function
    # No manual init or permission setup needed!

    echo "Deployment of $APP_NAME completed!"
    popd
}

# Main script logic
if [ -z "$1" ]; then
    echo "Usage: $0 <app_name> [vanilla]"
    echo "Examples:"
    echo "  $0 chest          # Deploy locally"
    echo "  $0 chest vanilla  # Deploy to vanilla core"
    exit 1
fi

APP_NAME=$1
DEPLOY_TYPE=$2

wait_for_local_katana

if [ "$DEPLOY_TYPE" = "vanilla" ]; then
    VANILLA_WORLD="0x022b2a8f75422d28500cb40b8b8f49f761f8a9206a870e22c3b1859cd4f07bed"
    deploy_app $APP_NAME $VANILLA_WORLD
else
    deploy_app $APP_NAME
fi