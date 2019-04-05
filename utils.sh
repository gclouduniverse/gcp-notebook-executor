#!/bin/bash -eu

function wait_till_instance_not_exist() {
    local INSTANCE_NAME=$1
    local ZONE=$2
    if [ "$#" -ne 2 ]; then
        echo "Usage: "
        echo "   ./wait_till_instance_not_exist [INSTANCE_NAME] [ZONE]"
        echo ""
        echo "example:"
        echo "   ./wait_till_instance_not_exist instance1 us-west1-b"
        echo ""
        return 1
    fi
    gcloud compute instances tail-serial-port-output "${INSTANCE_NAME}" --zone="${ZONE}" || true
    return 0
}