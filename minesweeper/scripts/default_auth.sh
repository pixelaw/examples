#!/bin/bash
set -euo pipefail
pushd $(dirname "$0")/..


# Check if a command line argument is supplied
if [ $# -gt 0 ]; then
    # If an argument is supplied, use it as the RPC_URL
    RPC_URL=$1
fi

export WORLD_ADDRESS=$(cat ./target/dev/manifest.json | jq -r '.world.address')
export DOJO_WORLD_ADDRESS=$WORLD_ADDRESS
export STARKNET_RPC="http://localhost:5050/"

export ACTIONS_ADDRESS=$(cat ./target/dev/manifest.json | jq -r '.contracts | first | .address')

echo "---------------------------------------------------------------------------"
echo world : $WORLD_ADDRESS
echo " "
echo actions : $ACTIONS_ADDRESS
echo "---------------------------------------------------------------------------"

# enable system -> component authorizations
COMPONENTS=($(cat ./target/dev/manifest.json | jq -r '.models[] | .name'))

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
        sozo auth grant writer $component,$ACTIONS_ADDRESS
    done
fi
echo "Write permissions for ACTIONS: Done"

echo "Initialize ACTIONS: Done"
sleep 0.1
sozo execute $ACTIONS_ADDRESS init
echo "Initialize ACTIONS: Done"


echo "Default authorizations have been successfully set."
