#!/bin/bash -e

install_prefix="/usr/local/"
etc_dir="/usr/local/etc/"
share_dir="/usr/local/share/"
output_dir="/tmp/"

if [ "$(dirname "${exe_dir}")" == '/usr/local' ]
then
  install_prefix="/usr/local/"
  etc_dir="/usr/local/etc"
elif [ "$(dirname "${exe_dir}")" ==  '/usr' ]
then
  install_prefix="/usr/"
  etc_dir="/etc"
elif [ "$(dirname "${exe_dir}")" ==  '/' ]
then
  install_prefix="/"
  etc_dir="/etc"
else
  echo "$(basename "${BASH_SOURCE[0]}") is installed in an unsupported dir: ${exe_dir}"
  exit 1
fi

# Load environment variables from flood.env
#   (allexport adds "export" to all of them)
set -o allexport
source "${etc_dir}/flood.env"
set +o allexport

if echo "$PATH" | grep -q '/usr/local/bin'
then
    echo '$PATH OK'
else
    echo 'Adding /usr/local/bin to $PATH'
    PATH="/usr/local/bin:$PATH"
    export PATH="/usr/local/bin:$PATH"
fi

if [ -z "${ATC_URLS}" ]
then
  echo "ATC_URLS must contain at least one active test config URL"
  exit 1
fi

AUTH_CACHE_FILE="/tmp/auth-cache.json"
ACCOUNTS_FILE="/tmp/accounts.json"

for ATC_URL in ${ATC_URLS}
do
  # TODO support multiple servers
  #      requires merging accounts.json and auth-cache.json
  echo "Fetching active test server info from ${ATC_URL}"

  curl "${ATC_URL}/accounts.json" > "${ACCOUNTS_FILE}"
  echo "  Downloaded auth-cache.json from ${ATC_URL}/auth-cache.json: $(ls -l ${AUTH_CACHE_FILE})"

  curl "${ATC_URL}/auth-cache.json" > "${AUTH_CACHE_FILE}"
  echo "  Downloaded accounts.json from ${ATC_URL}/accounts.json: $(ls -l ${ACCOUNTS_FILE})"
done


if [ -z "$GENERATED_FILES_NEST_DEPTH" ]
then
  echo 'Missing env var GENERATED_FILES_NEST_DEPTH. Defaulting to GENERATED_FILES_NEST_DEPTH=0'
  GENERATED_FILES_NEST_DEPTH=0
  export GENERATED_FILES_NEST_DEPTH=0
fi

NESTED_POD_FILENAME="${POD_FILENAME}"
if [ "${GENERATED_FILES_NEST_DEPTH}" != '0' ]
then
  for i in $(seq 1 "${GENERATED_FILES_NEST_DEPTH}");
  do
      NESTED_POD_FILENAME="data/${NESTED_POD_FILENAME}"
  done
fi