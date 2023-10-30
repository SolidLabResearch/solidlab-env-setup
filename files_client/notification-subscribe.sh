#!/bin/bash -e

base_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "${base_dir}"

# stderr to stdout for all of script
exec 2>&1

# Load environment variables from flood.env
#   (allexport adds "export" to all of them)
set -o allexport
source "${base_dir}/flood.env"
set +o allexport

if echo "$PATH" | grep -q '/usr/local/bin'
then
    echo '$PATH OK'
else
    echo 'Adding /usr/local/bin to $PATH'
    PATH="/usr/local/bin:$PATH"
    export PATH="/usr/local/bin:$PATH"
fi

CLIENT_PUBLIC_DNS_NAME="$(cat /etc/client_dns_name)"
CSS_PUBLIC_DNS_NAME="$(cat /etc/css_dns_name)"

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

if [ -z "NOTIFICATION_SUBSCRIPTION_COUNT" ]
then
  echo 'Missing env var NOTIFICATION_SUBSCRIPTION_COUNT.'
  exit 1
fi

if [ -z "$NOTIFICATION_IGNORE" ]
then
  echo 'Missing env var NOTIFICATION_IGNORE.'
  exit 1
fi


OUTPUT_FILE="${base_dir}/notification-subscribe-output.txt"
if [ -e "$OUTPUT_FILE" ]
then
  rm "$OUTPUT_FILE"
fi
SUBSCRIBE_REPORT="${base_dir}/notification-subscribe-report.json"
if [ -e "$SUBSCRIBE_REPORT" ]
then
  rm "$SUBSCRIBE_REPORT"
fi

SERVER_URL="https://${CSS_PUBLIC_DNS_NAME}"
if [ -z "${CSS_FLOOD_SINGLE_TIMEOUT_MS}" ]
then
  CSS_FLOOD_SINGLE_TIMEOUT_MS=4000
fi

echo "AUTH_COMMANDLINE: $AUTH_COMMANDLINE"

AUTH_CACHE_FILE="${base_dir}/auth-cache.json"

echo
set -v
/usr/bin/timeout -v -k '15s' --signal=INT "${CSS_FLOOD_TIMEOUT}s" /usr/local/bin/css-flood --url "$SERVER_URL" \
                  --notificationSubscriptionCount "${NOTIFICATION_SUBSCRIPTION_COUNT}" \
                  --notificationChannelType "${NOTIFICATION_CHANNEL_TYPE}" \
                  --notificationIgnore "${NOTIFICATION_IGNORE,,}" \
                  --reportFile "${SUBSCRIBE_REPORT}" \
                  --steps 'loadAC,validateAC,notificationsSubscribe' \
                  --fetchCount 1 \
                  --userCount ${CSS_FLOOD_USER_COUNT} \
                  --parallel 1 \
                  --processCount 1 \
                  --scenario NOTIFICATION \
                  --authenticate --authenticateCache all \
                  --verb POST \
                  --fetchTimeoutMs "${CSS_FLOOD_SINGLE_TIMEOUT_MS}" \
                  --filename "${POD_FILENAME}" --authCacheFile ${AUTH_CACHE_FILE} \
                   2>&1 | head -c 4M | tee "$OUTPUT_FILE" | head -c 500K
flood_ret_code=${PIPESTATUS[0]}
set +v
echo
echo "css-flood exited with exit code $flood_ret_code" | tee -a "$OUTPUT_FILE"
echo

if [ -e "$SUBSCRIBE_REPORT" ]
then
  echo "notification-subscribe report '$SUBSCRIBE_REPORT' created:"
  ls -l "$SUBSCRIBE_REPORT" || true  # show output file
else
  echo "notification-subscribe report '$SUBSCRIBE_REPORT' not found after running css-flood"
fi

if [ -e "$OUTPUT_FILE" ]
then
  echo "notification-subscribe stdout+stderr output file '$OUTPUT_FILE' created:"
  ls -l "$OUTPUT_FILE" || true  # show output file
else
  echo "notification-subscribe stdout+stderr output file '$OUTPUT_FILE' not found after running css-flood"
fi

{% if cookiecutter.perftest_start_agent|string|lower == 'true' %}
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
{% endif %}
exit $flood_ret_code
