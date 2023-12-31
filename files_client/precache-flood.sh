#!/bin/bash -e

exe_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "${exe_dir}"

# stderr to stdout for all of script
exec 2>&1

# common initialisation:
# - load flood.env vars
# - detect: $install_prefix $etc_dir $share_dir $output_dir
# - use $ATC_URLS to set $AUTH_CACHE_FILE and $ACCOUNTS_FILE
# - add /usr/local/bin to $PATH
# - set $NESTED_POD_FILENAME
source "${exe_dir}/flood-init.sh"

if [ "${SERVER_UNDER_TEST}" != "css" ] && [ "${SERVER_UNDER_TEST}" != "kss" ]
then
  echo "precache-flood.sh should only be called when SERVER_UNDER_TEST='css' or 'kss'. Not for SERVER_UNDER_TEST='$SERVER_UNDER_TEST'"
  exit 1
fi

# Pre-cache authentication (if needed)

flood_ret_code=0

if [ "$FLOOD_TOOL" != 'SOLID-FLOOD' ] && [ "$FLOOD_TOOL" != 'ARTILLERY' ]
then
  echo "Nothing to do for FLOOD_TOOL $FLOOD_TOOL"
  exit 0
fi

# Both solid-flood and artillery use the solid-flood cache for authentication

OUTPUT_FILE="${output_dir}/solid-flood-precache-output.txt"
if [ -e "$OUTPUT_FILE" ]
then
  rm "$OUTPUT_FILE"
fi


AUTH_COMMANDLINE=''
if [ "$AUTHENTICATED_CALLS" == 'true' ]
then
  AUTH_COMMANDLINE='--authenticate'
  echo 'Will use authenticated solidlab calls'
else
  echo 'Will use UNauthenticated solidlab calls. So no pre-cache needed.'
  exit 0
fi

if [ -n "$AUTHENTICATE_CACHE" ]
then
  AUTH_COMMANDLINE="${AUTH_COMMANDLINE} --authenticateCache ${AUTHENTICATE_CACHE}"
  echo "Will use authenticateCache ${AUTHENTICATE_CACHE}"
else
  echo 'Will not use authenticateCache. So no pre-cache needed.'
  exit 0
fi

if [ -z "${SOLID_FLOOD_SINGLE_TIMEOUT_MS}" ]
then  SOLID_FLOOD_SINGLE_TIMEOUT_MS=4000
fi

echo "AUTH_COMMANDLINE: $AUTH_COMMANDLINE"

# Note: setup_css.sh makes sure that the cache downloaded above is up to date.
#       But you can never be sure, so we check below (and refresh when needed).

# overwrite for --testAuth
POD_FILENAME='dummy.txt'  # always exists in our tests, whatever other content is present/not present on the pod

echo
set -x
/usr/bin/timeout -v -k '15s' --signal=INT "${SOLID_FLOOD_TIMEOUT}s" \
             /usr/local/bin/solid-flood \
                  --accounts USE_EXISTING --account-source FILE --account-source-file ${ACCOUNTS_FILE} \
                  --steps 'loadAC,fillAC,saveAC' \
                  --duration ${SOLID_FLOOD_DURATION} \
                  --podCount ${SOLID_FLOOD_USER_COUNT} \
                  --parallel ${SOLID_FLOOD_PARALLEL_DOWNLOADS} \
                  ${AUTH_COMMANDLINE} \
                  --filename "${POD_FILENAME}" \
                  --fetchTimeoutMs "${SOLID_FLOOD_SINGLE_TIMEOUT_MS}" \
                  --authCacheFile ${AUTH_CACHE_FILE} \
                  --ensure-auth-expiration 600 \
             2>&1 | head -c 4M | tee "$OUTPUT_FILE" | head -c 500K
flood_ret_code=${PIPESTATUS[0]}
set +x
echo
echo "solid-flood fill exited with exit code $flood_ret_code"
echo

# 2 steps, to be sure that cache save/load works correctly
#  The expiration required by this second step checks is 30 seconds earlier to avoid expiration race condition.

set -x
/usr/bin/timeout -v -k '15s' --signal=INT "${SOLID_FLOOD_TIMEOUT}s" \
             /usr/local/bin/solid-flood \
                  --accounts USE_EXISTING --account-source FILE --account-source-file ${ACCOUNTS_FILE} \
                  --steps 'loadAC,validateAC,testRequest' \
                  --duration ${SOLID_FLOOD_DURATION} \
                  --podCount ${SOLID_FLOOD_USER_COUNT} \
                  --parallel ${SOLID_FLOOD_PARALLEL_DOWNLOADS} \
                  ${AUTH_COMMANDLINE} \
                  --filename "${POD_FILENAME}" \
                  --fetchTimeoutMs "${SOLID_FLOOD_SINGLE_TIMEOUT_MS}" \
                  --authCacheFile ${AUTH_CACHE_FILE} \
                  --ensure-auth-expiration 570 \
             2>&1 | head -c 4M | tee "$OUTPUT_FILE" | head -c 500K
flood_ret_code=${PIPESTATUS[0]}
set +x
echo
echo "solid-flood extra validate exited with exit code $flood_ret_code"
echo

if [ -e "$OUTPUT_FILE" ]
then
  echo "Output file '$OUTPUT_FILE' created:"
  ls -l "$OUTPUT_FILE" || true  # show output file
else
  echo "Output file '$OUTPUT_FILE' not found after running solid-flood --onlyPreCacheAuth"
fi

if [ -n "$PERFTEST_UPLOAD_ENDPOINT" ]
then
  echo "Uploading solid-flood --onlyPreCacheAuth output to: '${PERFTEST_UPLOAD_ENDPOINT}' with auth '{${PERFTEST_UPLOAD_AUTH_TOKEN}}'"
  solidlab-perftest-upload "${PERFTEST_UPLOAD_ENDPOINT}" "$OUTPUT_FILE" \
            --auth-token "${PERFTEST_UPLOAD_AUTH_TOKEN}" \
            --type OTHER --sub-type 'solid-flood precache output' \
            --description "solid-flood --onlyPreCacheAuth stdout+stderr"
fi
exit $flood_ret_code
