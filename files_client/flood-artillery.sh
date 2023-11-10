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

NESTED_POD_FILENAME="${POD_FILENAME}"
if [ "${GENERATED_FILES_NEST_DEPTH}" != '0' ]
then
  for i in $(seq 1 "${GENERATED_FILES_NEST_DEPTH}");
  do
      NESTED_POD_FILENAME="data/${NESTED_POD_FILENAME}"
  done
fi


if [ "$FLOOD_TOOL" != 'ARTILLERY' ]
then
  echo "flood.sh only supports FLOOD_TOOL='ARTILLERY' not '$FLOOD_TOOL'"
  exit 1
fi

export ARTILLERY_DISABLE_TELEMETRY='true'
# Vars from PerfTest:
#ARTILLERY_SCENARIO="fixed arrivalRate" or "rampUp"
#ARTILLERY_ARRIVAL_RATE=100  # or 1000 or ...   -> artillery will read this var from env itself.

TEMPLATE_ARTILLERY_CONFIG='unknown'
if [ "$AUTHENTICATED_CALLS" == 'true' ]
then
  if [ "$ARTILLERY_SCENARIO" == 'fixed arrivalRate' ]
  then
     TEMPLATE_ARTILLERY_CONFIG='artillery-with-solid-auth-fixedRate.yaml'
  fi

  if [ "$ARTILLERY_SCENARIO" == 'rampUp' ]
  then
     TEMPLATE_ARTILLERY_CONFIG='artillery-with-solid-auth-rampUp.yaml'
  fi
else
  if [ "$ARTILLERY_SCENARIO" == 'fixed arrivalRate' ]
  then
     TEMPLATE_ARTILLERY_CONFIG='todo'
  fi

  if [ "$ARTILLERY_SCENARIO" == 'rampUp' ]
  then
     TEMPLATE_ARTILLERY_CONFIG='todo'
  fi
fi

if [ ! -e "${TEMPLATE_ARTILLERY_CONFIG}" ]
then
  echo "TEMPLATE_ARTILLERY_CONFIG not found: TEMPLATE_ARTILLERY_CONFIG=${TEMPLATE_ARTILLERY_CONFIG} (ARTILLERY_SCENARIO=$ARTILLERY_SCENARIO)"
  exit 1
fi

ARTILLERY_CONFIG='active-artillery-config.yaml'
# ARTILLERY has templates between double curly brackets, like jinja2, but these are very limited
# We need to pre-process some things ourselves  (not ideal to do it here in bash... but it works for now.)
sed -e 's#{{ $processEnvironment.ARTILLERY_ARRIVAL_RATE // 10 }}#'$(echo "${ARTILLERY_ARRIVAL_RATE}/10"|bc)'#g' \
    -e 's#{{ $processEnvironment.ARTILLERY_ARRIVAL_RATE // 5 }}#'$(echo "${ARTILLERY_ARRIVAL_RATE}/5"|bc)'#g' \
    -e 's#{{ $processEnvironment.ARTILLERY_ARRIVAL_RATE // 2 }}#'$(echo "${ARTILLERY_ARRIVAL_RATE}/2"|bc)'#g' \
    -e 's#{{ $processEnvironment.ARTILLERY_ARRIVAL_RATE }}#'"${ARTILLERY_ARRIVAL_RATE}"'#g' \
      < "${TEMPLATE_ARTILLERY_CONFIG}" > "${ARTILLERY_CONFIG}"

if [ -n "$PERFTEST_UPLOAD_ENDPOINT" ]
then
  echo "Uploading artillery conf file to: '${PERFTEST_UPLOAD_ENDPOINT}' with auth '{${PERFTEST_UPLOAD_AUTH_TOKEN}}'"
  solidlab-perftest-upload "${PERFTEST_UPLOAD_ENDPOINT}" "$ARTILLERY_CONFIG" \
            --auth-token "${PERFTEST_UPLOAD_AUTH_TOKEN}" \
            --type OTHER --sub-type 'artillery config' --mime-type 'text/yaml' \
            --description "Artillery config $ARTILLERY_CONFIG"
fi

OUTPUT_FILE="${output_dir}/artillery.json"
if [ -e "$OUTPUT_FILE" ]
then
  rm "$OUTPUT_FILE"
fi

CHATTER_FILE="${output_dir}/artillery-stdout.txt"
if [ -e "$CHATTER_FILE" ]
then
  rm "$CHATTER_FILE"
fi

echo "ARTILLERY_ARRIVAL_RATE=${ARTILLERY_ARRIVAL_RATE}"
echo "POD_FILENAME=${POD_FILENAME}"
echo "NESTED_POD_FILENAME=${NESTED_POD_FILENAME}"

set -vx
# artillery config specifies test of 90 seconds (10s + 20s + 60s)
# but these can take a lot longer, as they wait for everything to finish
# this was set to 180s, but that wasn't enough.
# sadly, artillery doesn't write it's output file when you send SIGINT
# --quiet
/usr/bin/timeout -v -k '15s' --signal=INT '360s' \
       artillery run -e "$SERVER_UNDER_TEST" \
                     --output "$OUTPUT_FILE" "$ARTILLERY_CONFIG" 2>&1 | head -c 4M > "$CHATTER_FILE"
artillery_ret_code=${PIPESTATUS[0]}
set +vx
echo
echo "artillery exited with exit code ${artillery_ret_code}" >> "$CHATTER_FILE"
echo

if [ -n "$PERFTEST_UPLOAD_ENDPOINT" ]
then
  if [ -e "$OUTPUT_FILE" ]
  then
    echo "Output file '$OUTPUT_FILE' created:"
    ls -l "$OUTPUT_FILE" || true  # show output file

    echo "Uploading artillery output file to: '${PERFTEST_UPLOAD_ENDPOINT}' with auth '{${PERFTEST_UPLOAD_AUTH_TOKEN}}'"
    solidlab-perftest-upload "${PERFTEST_UPLOAD_ENDPOINT}" "$OUTPUT_FILE" \
              --auth-token "${PERFTEST_UPLOAD_AUTH_TOKEN}" \
              --type OTHER --sub-type 'artillery report' \
              --description "Artillery report $OUTPUT_FILE"
  else
    echo "Output file '$OUTPUT_FILE' not found after running artillery."
  fi

  echo "Uploading artillery stdout chatter file to: '${PERFTEST_UPLOAD_ENDPOINT}'"
  solidlab-perftest-upload "${PERFTEST_UPLOAD_ENDPOINT}" "$CHATTER_FILE" \
            --auth-token "${PERFTEST_UPLOAD_AUTH_TOKEN}" \
            --type OTHER --sub-type 'artillery debug' \
            --description "Artillery stdout $CHATTER_FILE"
fi
exit "${artillery_ret_code}"
