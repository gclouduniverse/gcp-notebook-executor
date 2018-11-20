NOTEBOOKS_FOLDER="/tmp"

OUTPUT_NOTEBOOK_NAME="notebook.ipynb"
OUTPUT_NOTEBOOK_PATH="${NOTEBOOKS_FOLDER}/${OUTPUT_NOTEBOOK_NAME}"

INPUT_NOTEBOOK_GCS_FILE=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/input_notebook -H "Metadata-Flavor: Google")
OUTPUT_NOTEBOOK_GCS_FOLDER=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/output_notebook -H "Metadata-Flavor: Google")

gsutil cp "${INPUT_NOTEBOOK_GCS_FILE}" "${NOTEBOOKS_FOLDER}/"
INPUT_NOTEBOOK_PATH=`find ${NOTEBOOKS_FOLDER}/ | grep ipynb`

papermill "${INPUT_NOTEBOOK_PATH}" "${OUTPUT_NOTEBOOK_PATH}"

INSTANCE_NAME=$(curl http://metadata.google.internal/computeMetadata/v1/instance/name -H "Metadata-Flavor: Google")
INSTANCE_ZONE=$(curl http://metadata.google.internal/computeMetadata/v1/instance/zone -H "Metadata-Flavor: Google")
INSTANCE_PROJECT_NAME=$(curl http://metadata.google.internal/computeMetadata/v1/project/project-id -H "Metadata-Flavor: Google")
gcloud compute instances delete "${INSTANCE_NAME}" --zone "${INSTANCE_ZONE}" --project "${INSTANCE_PROJECT_NAME}"
