#!/bin/bash -e

exe_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "${exe_dir}"

etc_dir="/etc"
if [ "$(dirname "${exe_dir}")" == '/usr/local' ]
then
  etc_dir="/usr/local/etc"
fi

CSS_PUBLIC_DNS_NAME="$(cat /etc/host_fqdn)"

HTTPS_CERT_FILE="${etc_dir}/css/server_cert.pem"
HTTPS_KEY_FILE="${etc_dir}/css/server_key.pem"

if [ ! -e "/etc/letsencrypt/live/${CSS_PUBLIC_DNS_NAME}/fullchain.pem" ]
then
  echo 'First run! Setting up certbot certificate.'
  # Stop any service listening on port 80 or 443
  systemctl stop css nginx traefik || true
  sleep 1
  certbot certonly --standalone --non-interactive --domain "${CSS_PUBLIC_DNS_NAME}" --agree-tos --register-unsafely-without-email

  if [ ! -e "/etc/letsencrypt/live/${CSS_PUBLIC_DNS_NAME}/fullchain.pem" ]
  then
    echo "Failed to setup certbot certificate"
    set -x
    ls -R /etc/letsencrypt/live/
    exit 1
  fi
fi

########################################################################################################################

# Certbit sets up auto-renew, so we just always have to copy the latest certificate to where we expect it
cp -v "/etc/letsencrypt/live/${CSS_PUBLIC_DNS_NAME}/fullchain.pem" "${HTTPS_CERT_FILE}"
cp -v "/etc/letsencrypt/live/${CSS_PUBLIC_DNS_NAME}/privkey.pem" "${HTTPS_KEY_FILE}"

CERT_NOT_AFTER=$(openssl x509 -noout -enddate -in "${HTTPS_CERT_FILE}" | sed -e 's/^.*=//' | xargs -I '@' date -u --date='@' '+%FT%TZ')
CERT_NOT_AFTER_EPOCH=$(date --date="${CERT_NOT_AFTER}" +%s)
#NOW_EPOCH=$(date +%s)
#YESTERDAY_EPOCH=$(echo "$NOW_EPOCH - 24*60*60" | bc)
YESTERDAY_EPOCH=$(date -d "yesterday" +%s)

if [ "${CERT_NOT_AFTER_EPOCH}" -gt "${YESTERDAY_EPOCH}" ]
then
  echo 'certificates are still valid long enough'
  exit 0
fi

# Certbot will auto-renew, BUT it's always possible some service is using port 80 or 443 when it does.
# We need to stop servers and call renew ourself in that case.

echo "Need to update cert! Certificate expires at ${CERT_NOT_AFTER}. Now is $(date '+%FT%TZ')."
set -x
systemctl stop css nginx traefik || true
sleep 1
certbot renew --standalone --non-interactive
set +x

cp -v "/etc/letsencrypt/live/${CSS_PUBLIC_DNS_NAME}/fullchain.pem" "${HTTPS_CERT_FILE}"
cp -v "/etc/letsencrypt/live/${CSS_PUBLIC_DNS_NAME}/privkey.pem" "${HTTPS_KEY_FILE}"

########################################################################################################################

# Now just check if all is OK
CERT_NOT_AFTER=$(openssl x509 -noout -enddate -in "${HTTPS_CERT_FILE}" | sed -e 's/^.*=//' | xargs -I '@' date -u --date='@' '+%FT%TZ')
CERT_NOT_AFTER_EPOCH=$(date --date="${CERT_NOT_AFTER}" +%s)
YESTERDAY_EPOCH=$(date -d "yesterday" +%s)

if [ "${CERT_NOT_AFTER_EPOCH}" -lt "${YESTERDAY_EPOCH}" ]
then
  echo 'ERROR: After certbot renew, certificates are not valid long enough!'
  openssl x509 -noout -enddate -in "${HTTPS_CERT_FILE}"
  exit 1
fi

########################################################################################################################


# OLD ALT method: get certs them from traefik
#echo "Making sure SSL certificate and key are up to date"
#jq -r --arg dns "${CSS_PUBLIC_DNS_NAME}" '.letsencrypt.Certificates[] | select(.domain.main==$dns) | .certificate' < /etc/traefik/acme.json | base64 -d > "${HTTPS_CERT_FILE}"
#jq -r --arg dns "${CSS_PUBLIC_DNS_NAME}" '.letsencrypt.Certificates[] | select(.domain.main==$dns) | .key' < /etc/traefik/acme.json | base64 -d > "${HTTPS_KEY_FILE}"
