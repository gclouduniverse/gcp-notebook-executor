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

function execute_notebook() {
    local ZONE="us-west1-b"
    local IMAGE_FAMILY="tf-latest-cu100"
    local INPUT_NOTEBOOK=""
    local GPU_TYPE=""
    local GPU_COUNT=1
    local INSTANCE_TYPE="n1-standard-8"
    local GCS_OUTPUT=""

    while getopts "i:z:f:g:c:t:l:o:" opt; do
    case ${opt} in
        i )
        INPUT_NOTEBOOK=$OPTARG
        ;;
        z )
        ZONE=$OPTARG
        ;;
        z )
        IMAGE_FAMILY=$OPTARG
        ;;
        g )
        GPU_TYPE=$OPTARG
        ;;
        c )
        GPU_COUNT=$OPTARG
        ;;
        t )
        INSTANCE_TYPE=$OPTARG
        ;;
        o )
        GCS_OUTPUT=$OPTARG
        ;;
        \? )
        echo "Invalid option: $OPTARG" 1>&2
        ;;
        : )
        echo "Invalid option: $OPTARG requires an argument" 1>&2
        ;;
    esac
    done
    shift $((OPTIND -1))

    if [ "$#" -ne 4 ]; then
        echo "Usage: "
        echo "   ./execute_notebook_with_gpu [INPUT_NOTEBOOK] [GCS_LOCATION] [GPU_TYPE] [GPU_COUNT]"
        echo ""
        echo "example:"
        echo "   ./execute_notebook_with_gpu test.ipynb gs://my-bucket p100 4"
        echo ""
        return 1
    fi 
    readonly BUILD_ID=$(date +%s)
    echo "Build id: ${BUILD_ID}"
    local INPUT_NOTEBOOK=$1
    local GCS_LOCATION=$2
    local GPU_TYPE=$3
    local GPU_COUNT=$4
    NOTEBOOK_NAME=$(basename ${INPUT_NOTEBOOK})
    INPUT_NOTEBOOK_GCS_PATH="${GCS_LOCATION}/staging/${BUILD_ID}/${NOTEBOOK_NAME}"
    if [[ ! -z ${PARAM_FILE} ]]; then
        INPUT_PARAM_GCS_PATH="${GCS_LOCATION}/staging/${BUILD_ID}/params.yaml"
        gsutil cp "${PARAM_FILE}" "${INPUT_PARAM_GCS_PATH}"
        PARAM_METADATA=",parameters_file=${INPUT_PARAM_GCS_PATH}"
    fi
    OUTPUT_NOTEBOOK_GCS_FOLDER=$(output_for_mode "${TESTING_MODE}" "${GCS_LOCATION}" "${OUTPUT_DATE}")
    OUTPUT_NOTEBOOK_GCS_PATH="${OUTPUT_NOTEBOOK_GCS_FOLDER}/${NOTEBOOK_NAME}"
    echo "Staging notebook: ${INPUT_NOTEBOOK_GCS_PATH}"
    echo "Output notebook: ${OUTPUT_NOTEBOOK_GCS_PATH}"
    gsutil cp "${INPUT_NOTEBOOK}" "${INPUT_NOTEBOOK_GCS_PATH}"
    if [[ $? -eq 1 ]]; then
        echo "Upload to the temp GCS location (${INPUT_NOTEBOOK_GCS_PATH}) of the notebook (${INPUT_NOTEBOOK}) has failed."
        return 1
    fi
    IMAGE_FAMILY="tf-latest-cu100" # or put any required
    ZONE="us-west1-b"
    INSTANCE_NAME="${DEFAULT_NOTEBOOK_EXECUTOR_INSTANCE_NAME}"
    INSTANCE_TYPE="n1-standard-8"
    gcloud compute instances create "${INSTANCE_NAME}" \
            --zone="${ZONE}" \
            --image-family="${IMAGE_FAMILY}" \
            --image-project=deeplearning-platform-release \
            --maintenance-policy=TERMINATE \
            --accelerator="type=nvidia-tesla-${GPU_TYPE},count=${GPU_COUNT}" \
            --machine-type="${INSTANCE_TYPE}" \
            --boot-disk-size=200GB \
            --scopes=https://www.googleapis.com/auth/cloud-platform \
            --metadata="api_key=${API_KEY},input_notebook=${INPUT_NOTEBOOK_GCS_PATH},output_notebook=${OUTPUT_NOTEBOOK_GCS_FOLDER}${PARAM_METADATA:-}" \
            --metadata-from-file="startup-script=gcp-notebook-executor/notebook_executor.sh" \
            --quiet
    if [[ $? -eq 1 ]]; then
        echo "Creation of background instance for training has failed."
        return 1
    fi
    wait_till_instance_not_exist "${INSTANCE_NAME}" "${ZONE}"
    echo "execution has been finished, checking result"
    OUTPUT_CONTENTS=$(gsutil ls "${OUTPUT_NOTEBOOK_GCS_FOLDER}")
    if [[ $? -ne 0 ]] || grep -q "FAILED" <<< "${OUTPUT_CONTENTS}"; then
        echo "Job failed or unable to get output."
        return 1
    fi
    echo "done"
    return 0
}
