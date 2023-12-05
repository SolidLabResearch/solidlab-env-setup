#!/bin/bash -e

# setup_ss_init.sh requires ${env_file} to be set!

exe_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "${exe_dir}"

# import functions from generate_content.sh
source "${exe_dir}/generate_content.sh"

# install_prefix is /, /usr/ or /usr/local/
# will be auto-detected by looking at exe_dir

install_prefix="/usr/local/"
etc_dir="/usr/local/etc/"
share_dir="/usr/local/share/"

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

data_dir="${install_prefix}share/"

if [ -z "$env_file_base" ]
then
  echo 'setup_ss_init.sh requires ${env_file} to be set!'
  exit 1
fi

env_file="${etc_dir}/${env_file_base}"

if [ ! -e "${env_file}" ]
then
  echo "env file not found: '${env_file}'"
  exit 1
fi

# Load environment variables from setup_css.env
#   (allexport adds "export" to all of them)
set -o allexport
source "${env_file}"
set +o allexport

if [ -z "$SERVER_UNDER_TEST" ]
then
  echo 'Missing env var SERVER_UNDER_TEST.'
  exit 1
fi

if [ "$SERVER_UNDER_TEST" == "css" ] && [ -z "$SERVER_FACTORY" ]
then
  echo 'Missing env var SERVER_FACTORY.'
  exit 1
fi

# The caller of setup_css.sh can set the FQDN
# If not set by caller, use /etc/host_fqdn
if [ -z "$SS_PUBLIC_DNS_NAME" ]
then
  # $SERVER_FACTORY -> CSS
  # $IS_HTTPS_SERVER -> KSS
  if [ "$SERVER_FACTORY" == "https" ] || [ "${IS_HTTPS_SERVER,,}" == "true" ]
  then
    SS_PUBLIC_DNS_NAME="$(cat /etc/host_fqdn)"
  else
    SS_PUBLIC_DNS_NAME="localhost"
  fi
fi

if [ -z "$SERVER_UNDER_TEST" ]
then
  echo 'Missing required env var SERVER_UNDER_TEST'
  exit 1
fi

# Make sure all service files are up to date
systemctl daemon-reload

# Start by stopping any old servers
echo "Stopping CSS, traefik, KSS and nginx (if running)."
systemctl stop css traefik nginx kss || echo 'ignoring stop failure'
# If the above fails, there's typically an error in a systemd unit .service file
# Or the services simply don't exist on this specific setup

HTTP_PROTO_PREFIX="http"
USED_SS_PORT=3000
USED_SS_PORT_SUFFIX=":3000"
if [ "${IS_HTTPS_SERVER,,}" == "true" ] || [ "${SERVER_FACTORY}" = 'https' ]
then
  HTTP_PROTO_PREFIX="https"
  USED_SS_PORT=443
  USED_SS_PORT_SUFFIX=""  # none needed: http is already 443

  # Then make sure we have the SSL cert we might need
  "${exe_dir}/provide_certs.sh"
fi

GLOBAL_BASE_URL="${HTTP_PROTO_PREFIX}://${SS_PUBLIC_DNS_NAME}${USED_SS_PORT_SUFFIX}/"
if [ -n "${OVERRIDE_BASE_URL}" ]
then
  GLOBAL_BASE_URL="${OVERRIDE_BASE_URL}"
fi

if [ -n "${OVERRIDE_PORT}" ]
then
  USED_SS_PORT="${OVERRIDE_PORT}"
  USED_SS_PORT_SUFFIX=":${OVERRIDE_PORT}"
fi
