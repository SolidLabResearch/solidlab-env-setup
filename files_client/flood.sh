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

if [ -z "$CONTENT_FILES_RDF_SIZE" ]
then
  # default 100k
  CONTENT_FILES_RDF_SIZE='100_000'
  export CONTENT_FILES_RDF_SIZE='100_000'
fi
CONTENT_FILES_RDF_SIZE=$(echo "${CONTENT_FILES_RDF_SIZE}" | tr -d '_\n')
CONTENT_FILES_RDF_SIZE_NICK=$(echo "${CONTENT_FILES_RDF_SIZE}" | sed -e 's/000$/k/' | sed -e 's/000k$/M/' | sed -e 's/000M$/G/' )


if [ "${FLOOD_TOOL}" != 'SOLID-FLOOD' ]
then
  echo "flood.sh only supports FLOOD_TOOL='SOLID-FLOOD' not '$FLOOD_TOOL'"
  exit 1
fi

OUTPUT_FILE="${output_dir}/solid-flood-output.txt"
if [ -e "$OUTPUT_FILE" ]
then
  rm "$OUTPUT_FILE"
fi
SOLID_FLOOD_REPORT="${output_dir}/solid-flood-report.json"
if [ -e "$SOLID_FLOOD_REPORT" ]
then
  rm "$SOLID_FLOOD_REPORT"
fi

echo "Note: SERVER_UNDER_TEST='${SERVER_UNDER_TEST}'"

AUTH_COMMANDLINE=''
if [ "${AUTHENTICATED_CALLS,,}" == 'true' ]
then
  if [ "${SERVER_UNDER_TEST,,}" != "nginx" ]
  then
    AUTH_COMMANDLINE='--authenticate'
    echo 'Will use authenticated solidlab calls'
  else
    # Note: nginx cannot use authenticated solid calls. But the tests do sometimes specify this.
    #       in that case, we ignore the request for authenticated calls.
    echo "Will use UNauthenticated solidlab calls because SERVER_UNDER_TEST is ${SERVER_UNDER_TEST}"
  fi
else
  echo 'Will use UNauthenticated solidlab calls'
fi

if [ -n "$AUTHENTICATE_CACHE" ] && [ "${SERVER_UNDER_TEST,,}" != "nginx" ]
then
  AUTH_COMMANDLINE="${AUTH_COMMANDLINE} --authenticateCache ${AUTHENTICATE_CACHE}"
  echo "Will use authenticateCache ${AUTHENTICATE_CACHE}"
fi

if [ -z "${SOLID_FLOOD_SINGLE_TIMEOUT_MS}" ]
then
  SOLID_FLOOD_SINGLE_TIMEOUT_MS=4000
fi

STOP_CONDITION_COMMANDLINE="--error "
if [ -z "${SOLID_FLOOD_STOP_CONDITION}" ] || [ "${SOLID_FLOOD_STOP_CONDITION}" = 'time' ]
then
  # default
  STOP_CONDITION_COMMANDLINE="--duration ${SOLID_FLOOD_DURATION} "
elif [ "${SOLID_FLOOD_STOP_CONDITION}" = 'count' ]
then
  STOP_CONDITION_COMMANDLINE="--fetchCount ${SOLID_FLOOD_FILECOUNT} "
else
  echo "Unsupported SOLID_FLOOD_STOP_CONDITION='${SOLID_FLOOD_STOP_CONDITION}'. Must be 'time' or 'count'."
  exit 1
fi

if [ -z "${SOLID_FLOOD_SCENARIO}" ]
then
  SCENARIO_COMMANDLINE="--scenario BASIC"
else
  SCENARIO_COMMANDLINE="--scenario ${SOLID_FLOOD_SCENARIO}"
fi

if [ "${SOLID_FLOOD_HTTP_VERB^^}" != 'GET' ] && [ "${SERVER_UNDER_TEST,,}" != "nginx" ]
then
  echo "nginx does not support tests with HTTP verb ${SOLID_FLOOD_HTTP_VERB}"
  exit 1
fi

if [ "${SOLID_FLOOD_HTTP_VERB}" = 'PUT' ]
then
  if [ "${SOLID_FLOOD_STOP_CONDITION,,}" = 'time' ]
  then
     # Always the same file to PUT
     VERB_COMMANDLINE="--verb PUT --uploadSizeByte ${SOLID_FLOOD_UPLOAD_FILESIZE} "
  else
     # PUT a different file each time
     VERB_COMMANDLINE="--verb PUT --filenameIndexing --uploadSizeByte ${SOLID_FLOOD_UPLOAD_FILESIZE} "
  fi
fi
if [ "${SOLID_FLOOD_HTTP_VERB}" = 'POST' ]
then
  VERB_COMMANDLINE="--verb POST --filenameIndexing --uploadSizeByte ${SOLID_FLOOD_UPLOAD_FILESIZE} "
fi
if [ "${SOLID_FLOOD_HTTP_VERB}" = 'DELETE' ]
then
  VERB_COMMANDLINE="--verb DELETE --filenameIndexing"
fi
if [ "${SOLID_FLOOD_HTTP_VERB}" = 'PATCH' ]
then
  # this implies that ${SCENARIO_COMMANDLINE} contains: --scenario N3_PATCH
   if [ "${CONTENT_FILES_RDF_SIZE}" == '100000' ]
   then
      VERB_COMMANDLINE="--verb PATCH --n3PatchGenFile ${share_dir}/infobox-properties_lang\=nl__head750_100kB.nt"
   elif [ "${CONTENT_FILES_RDF_SIZE}" == '1000000' ]
   then
      VERB_COMMANDLINE="--verb PATCH --n3PatchGenFile ${share_dir}/infobox-properties_lang\=nl__head7500_1MB.nt"
   elif [ "${CONTENT_FILES_RDF_SIZE}" == '10000000' ]
   then
      VERB_COMMANDLINE="--verb PATCH --n3PatchGenFile ${share_dir}/infobox-properties_lang\=nl__head75000_10MB.nt"
   else
      echo "RDF file size ${CONTENT_FILES_RDF_SIZE} (${CONTENT_FILES_RDF_SIZE_NICK}) not supported"
      exit 1
   fi
fi

STEPS='loadAC,validateAC,flood'
if [ "${SERVER_UNDER_TEST,,}" != 'css' ] || [ "${AUTHENTICATED_CALLS,,}" != 'true' ]
then
  STEPS='flood'
fi

echo "AUTH_COMMANDLINE: $AUTH_COMMANDLINE"

echo
set -v
/usr/bin/timeout -v -k '15s' --signal=INT "${SOLID_FLOOD_TIMEOUT}s" /usr/local/bin/solid-flood \
                  --accounts USE_EXISTING --account-source FILE --account-source-file ${ACCOUNTS_FILE} \
                  --reportFile "${SOLID_FLOOD_REPORT}" \
                  --steps "${STEPS}" \
                  ${STOP_CONDITION_COMMANDLINE} \
                  --podCount ${SOLID_FLOOD_USER_COUNT} \
                  --parallel ${SOLID_FLOOD_PARALLEL_DOWNLOADS} \
                  --processCount ${SOLID_FLOOD_WORKERS} \
                  ${SCENARIO_COMMANDLINE} \
                  ${AUTH_COMMANDLINE} \
                  ${VERB_COMMANDLINE} \
                   --fetchTimeoutMs "${SOLID_FLOOD_SINGLE_TIMEOUT_MS}" \
                  --filename "${NESTED_POD_FILENAME}" --authCacheFile ${AUTH_CACHE_FILE} \
                   2>&1 | head -c 4M | tee "$OUTPUT_FILE" | head -c 500K
flood_ret_code=${PIPESTATUS[0]}
set +v
echo
echo "solid-flood exited with exit code $flood_ret_code" | tee -a "$OUTPUT_FILE"
echo

if [ -e "$SOLID_FLOOD_REPORT" ]
then
  echo "solid-flood report '$SOLID_FLOOD_REPORT' created:"
  ls -l "$SOLID_FLOOD_REPORT" || true  # show output file
else
  echo "solid-flood report '$SOLID_FLOOD_REPORT' not found after running solid-flood"
fi

if [ -e "$OUTPUT_FILE" ]
then
  echo "solid-flood stdout+stderr output file '$OUTPUT_FILE' created:"
  ls -l "$OUTPUT_FILE" || true  # show output file
else
  echo "solid-flood stdout+stderr output file '$OUTPUT_FILE' not found after running solid-flood"
fi

if [ -n "$PERFTEST_UPLOAD_ENDPOINT" ]
then
  echo "Uploading solid-flood output to: '${PERFTEST_UPLOAD_ENDPOINT}' with auth '{${PERFTEST_UPLOAD_AUTH_TOKEN}}'"
  solidlab-perftest-upload "${PERFTEST_UPLOAD_ENDPOINT}" "$OUTPUT_FILE" \
            --auth-token "${PERFTEST_UPLOAD_AUTH_TOKEN}" \
            --type OTHER --sub-type 'solid-flood output' \
            --description "solid-flood stdout+stderr"

  if [ -e "$SOLID_FLOOD_REPORT" ]
  then
    echo "Uploading solid-flood report to: '${PERFTEST_UPLOAD_ENDPOINT}' with auth '{${PERFTEST_UPLOAD_AUTH_TOKEN}}'"
    solidlab-perftest-upload "${PERFTEST_UPLOAD_ENDPOINT}" "$SOLID_FLOOD_REPORT" \
              --auth-token "${PERFTEST_UPLOAD_AUTH_TOKEN}" \
              --type OTHER --sub-type 'solid-flood report' \
              --mime-type 'application/json' \
              --description "solid-flood Report"
  fi
fi

exit $flood_ret_code

