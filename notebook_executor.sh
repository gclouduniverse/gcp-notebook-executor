if lspci -vnn | grep NVIDIA > /dev/null 2>&1; then
  # Nvidia card found, need to check if driver is up
  if ! nvidia-smi > /dev/null 2>&1; then
    echo "Installing driver"
    /opt/deeplearning/install-driver.sh
  fi
fi

readonly NOTEBOOKS_FOLDER="/tmp"

readonly OUTPUT_NOTEBOOK_NAME="notebook.ipynb"
readonly OUTPUT_NOTEBOOK_ERROR_NAME="notebook_error.ipynb"
readonly OUTPUT_NOTEBOOK_PATH="${NOTEBOOKS_FOLDER}/${OUTPUT_NOTEBOOK_NAME}"
readonly OUTPUT_NOTEBOOK_ERROR_PATH="${NOTEBOOKS_FOLDER}/${OUTPUT_NOTEBOOK_ERROR_NAME}"

readonly INPUT_NOTEBOOK_GCS_FILE=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/input_notebook -H "Metadata-Flavor: Google")
readonly OUTPUT_NOTEBOOK_GCS_FOLDER=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/output_notebook -H "Metadata-Flavor: Google")
readonly PARAMETERS_GCS_FILE=$(curl --fail http://metadata.google.internal/computeMetadata/v1/instance/attributes/parameters_file -H "Metadata-Flavor: Google")
readonly TESTING_MODE=$(curl --fail http://metadata.google.internal/computeMetadata/v1/instance/attributes/testing_mode -H "Metadata-Flavor: Google")

echo "Going to download ${INPUT_NOTEBOOK_GCS_FILE} to ${NOTEBOOKS_FOLDER}/"
gsutil cp "${INPUT_NOTEBOOK_GCS_FILE}" "${NOTEBOOKS_FOLDER}/"
readonly INPUT_NOTEBOOK_PATH=`find ${NOTEBOOKS_FOLDER}/ | grep ipynb`
echo "Local path to the input notebook: ${INPUT_NOTEBOOK_PATH}"

TESTING_MODE_FLAG=""
if [[ -z "${TESTING_MODE}" ]]; then
  TESTING_MODE_FLAG="--report-mode"
fi

if [[ -z "${PARAMETERS_GCS_FILE}" ]]; then
  echo "No input parameters present"
  papermill "${INPUT_NOTEBOOK_PATH}" "${OUTPUT_NOTEBOOK_PATH}" "${TESTING_MODE_FLAG}"
else
  echo "input parameters present"
  echo "GCS file with parameters: ${PARAMETERS_GCS_FILE}"
  gsutil cp "${PARAMETERS_GCS_FILE}" params.yaml
  papermill "${INPUT_NOTEBOOK_PATH}" "${OUTPUT_NOTEBOOK_PATH}" -f params.yaml "${TESTING_MODE_FLAG}"
fi

if [[ -z "${TESTING_MODE}" && ! $? -eq 0 ]]; then
  echo "Going to upload result notebook ${OUTPUT_NOTEBOOK_PATH} to ${OUTPUT_NOTEBOOK_GCS_FOLDER}"
  gsutil cp "${OUTPUT_NOTEBOOK_PATH}" "${OUTPUT_NOTEBOOK_GCS_FOLDER}"
else
  echo "Looks like we are in testing mode and notebook is broken."
  cp "${OUTPUT_NOTEBOOK_PATH}" "${OUTPUT_NOTEBOOK_ERROR_PATH}"
  gsutil cp "${OUTPUT_NOTEBOOK_ERROR_PATH}" "${OUTPUT_NOTEBOOK_GCS_FOLDER}"
fi

readonly INSTANCE_NAME=$(curl http://metadata.google.internal/computeMetadata/v1/instance/name -H "Metadata-Flavor: Google")
INSTANCE_ZONE="/"$(curl http://metadata.google.internal/computeMetadata/v1/instance/zone -H "Metadata-Flavor: Google")
INSTANCE_ZONE="${INSTANCE_ZONE##/*/}"
readonly INSTANCE_PROJECT_NAME=$(curl http://metadata.google.internal/computeMetadata/v1/project/project-id -H "Metadata-Flavor: Google")
gcloud --quiet compute instances delete "${INSTANCE_NAME}" --zone "${INSTANCE_ZONE}" --project "${INSTANCE_PROJECT_NAME}"
