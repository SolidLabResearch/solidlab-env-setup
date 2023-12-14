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

# Rhis supports multiple servers, merging multiple accounts.json and auth-cache.json in that case
_cur_index=0
for ATC_URL in ${ATC_URLS}
do
  echo "Fetching active test server info from ${ATC_URL}"

  _cur_accounts_file="/tmp/accounts${_cur_index}.json"
  _all_account_files[_cur_index]="${_cur_accounts_file}"
  curl "${ATC_URL}/accounts.json" > "${_cur_accounts_file}"
  echo "  Downloaded accounts.json from ${ATC_URL}/accounts.json: $(ls -l ${_cur_accounts_file})"

  if [ "${AUTHENTICATED_CALLS,,}" = 'true' ]
  then
    _cur_auth_cache_file="/tmp/auth-cache${_cur_index}.json"
    _all_auth_cache_files[_cur_index]="${_cur_auth_cache_file}"
    curl "${ATC_URL}/auth-cache.json" > "${_cur_auth_cache_file}"
    echo "  Downloaded auth-cache.json from ${ATC_URL}/auth-cache.json: $(ls -l ${_cur_auth_cache_file})"
  else
    echo "  Not downloaded ${ATC_URL}/auth-cache.json because not needed"
  fi

  _cur_index="$((_cur_index + 1))"
done

ACCOUNTS_FILE="/tmp/accounts.json"
if [ "${#_all_account_files[@]}" = '1' ]
then
  cp -v "${_all_account_files[0]}" "${ACCOUNTS_FILE}"
else
  echo "Merging ${#_all_account_files[@]} account files into ${ACCOUNTS_FILE}: ${_all_account_files[*]}"
  solid-account-file-merger ${_all_account_files[*]} > "${ACCOUNTS_FILE}"
fi

AUTH_CACHE_FILE="/tmp/auth-cache.json"
if [ "${AUTHENTICATED_CALLS,,}" = 'true' ]
then
  if [ "${#_all_auth_cache_files[@]}" = '1' ]
  then
    cp -v "${_all_auth_cache_files[0]}" "${AUTH_CACHE_FILE}"
  else
    echo "Merging ${#_all_auth_cache_files[@]} auth caches into ${AUTH_CACHE_FILE}: ${_all_auth_cache_files[*]}"
    solid-auth-cache-merger ${_all_auth_cache_files[*]} > "${AUTH_CACHE_FILE}"
  fi
fi


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