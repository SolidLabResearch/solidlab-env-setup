#!/bin/bash -e

exe_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "${exe_dir}"

# stderr to stdout for all of script
exec 2>&1

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

if [ -z "$NOTIFICATION_CHANNEL_TYPE" ]
then
  echo 'Missing env var NOTIFICATION_CHANNEL_TYPE.'
  exit 1
fi

if [ "$NOTIFICATION_CHANNEL_TYPE" == "webhooks" ]
then
  NOTIFICATION_CHANNEL_TYPE="webhook"
fi

if [ "$NOTIFICATION_CHANNEL_TYPE" == "websockets" ]
then
  NOTIFICATION_CHANNEL_TYPE="websocket"
fi

if [ -z "$NOTIFICATION_SUBSCRIPTION_COUNT" ]
then
  echo 'Missing env var NOTIFICATION_SUBSCRIPTION_COUNT.'
  exit 1
fi

if [ -z "$NOTIFICATION_IGNORE" ]
then
  echo 'Missing env var NOTIFICATION_IGNORE.'
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


OUTPUT_FILE="${output_dir}/notification-subscribe-output.txt"
if [ -e "$OUTPUT_FILE" ]
then
  rm "$OUTPUT_FILE"
fi
SUBSCRIBE_REPORT="${output_dir}/notification-subscribe-report.json"
if [ -e "$SUBSCRIBE_REPORT" ]
then
  rm "$SUBSCRIBE_REPORT"
fi

if [ -z "${SOLID_FLOOD_SINGLE_TIMEOUT_MS}" ]
then
  SOLID_FLOOD_SINGLE_TIMEOUT_MS=4000
fi

echo "AUTH_COMMANDLINE: $AUTH_COMMANDLINE"


echo
set -v
/usr/bin/timeout -v -k '15s' --signal=INT "${SOLID_FLOOD_TIMEOUT}s" /usr/local/bin/solid-flood  \
                  --accounts USE_EXISTING --account-source FILE --account-source-file ${ACCOUNTS_FILE} \
                  --notificationSubscriptionCount "${NOTIFICATION_SUBSCRIPTION_COUNT}" \
                  --notificationChannelType "${NOTIFICATION_CHANNEL_TYPE}" \
                  --notificationIgnore "${NOTIFICATION_IGNORE,,}" \
                  --reportFile "${SUBSCRIBE_REPORT}" \
                  --steps 'loadAC,validateAC,notificationsSubscribe' \
                  --fetchCount 1 \
                  --podCount ${SOLID_FLOOD_USER_COUNT} \
                  --parallel 1 \
                  --processCount 1 \
                  --scenario NOTIFICATION \
                  --authenticate --authenticateCache all \
                  --verb POST \
                  --fetchTimeoutMs "${SOLID_FLOOD_SINGLE_TIMEOUT_MS}" \
                  --filename "${POD_FILENAME}" --authCacheFile ${AUTH_CACHE_FILE} \
                   2>&1 | head -c 4M | tee "$OUTPUT_FILE" | head -c 500K
flood_ret_code=${PIPESTATUS[0]}
set +v
echo
echo "solid-flood exited with exit code $flood_ret_code" | tee -a "$OUTPUT_FILE"
echo

if [ -e "$SUBSCRIBE_REPORT" ]
then
  echo "notification-subscribe report '$SUBSCRIBE_REPORT' created:"
  ls -l "$SUBSCRIBE_REPORT" || true  # show output file
else
  echo "notification-subscribe report '$SUBSCRIBE_REPORT' not found after running solid-flood"
fi

if [ -e "$OUTPUT_FILE" ]
then
  echo "notification-subscribe stdout+stderr output file '$OUTPUT_FILE' created:"
  ls -l "$OUTPUT_FILE" || true  # show output file
else
  echo "notification-subscribe stdout+stderr output file '$OUTPUT_FILE' not found after running solid-flood"
fi

if [ -n "$PERFTEST_UPLOAD_ENDPOINT" ]
then
  echo "Uploading notification-subscribe output to: '${PERFTEST_UPLOAD_ENDPOINT}' with auth '{${PERFTEST_UPLOAD_AUTH_TOKEN}}'"
  solidlab-perftest-upload "${PERFTEST_UPLOAD_ENDPOINT}" "$OUTPUT_FILE" \
            --auth-token "${PERFTEST_UPLOAD_AUTH_TOKEN}" \
            --type OTHER --sub-type 'notification-subscribe output' \
            --description "Notification Subscribe stdout+stderr"

  if [ -e "$SUBSCRIBE_REPORT" ]
  then
    echo "Uploading notification-subscribe report to: '${PERFTEST_UPLOAD_ENDPOINT}' with auth '{${PERFTEST_UPLOAD_AUTH_TOKEN}}'"
    solidlab-perftest-upload "${PERFTEST_UPLOAD_ENDPOINT}" "$SUBSCRIBE_REPORT" \
              --auth-token "${PERFTEST_UPLOAD_AUTH_TOKEN}" \
              --type OTHER --sub-type 'notification-subscribe report' \
              --mime-type 'application/json' \
              --description "Notification Subscribe Report"
  fi
fi
exit $flood_ret_code
