NOTEBOOK_EXECUTOR_REMOTE_PATH="https://raw.githubusercontent.com/b0noI/gcp-notebook-executor/master/notebook_executor.sh"
NOTEBOOK_EXECUTOR_NAME="notebook_executor"
NOTEBOOK_EXECUTOR_LOCAL_PATH="/etc/init.d/${NOTEBOOK_EXECUTOR_NAME}.sh"

wget "${NOTEBOOK_EXECUTOR_REMOTE_PATH}" -O "${NOTEBOOK_EXECUTOR_LOCAL_PATH}"
chmod 755 "${NOTEBOOK_EXECUTOR_LOCAL_PATH}"
update-rc.d "${NOTEBOOK_EXECUTOR_NAME}" defaults
