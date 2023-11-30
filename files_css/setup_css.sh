#!/bin/bash -e


# Configure and start CSS before a test
#
# This will:
#    - Stop CSS if running
#    - Configure it based on environment variables
#    - Start CSS
#    - Wait until CSS is running


##################################################################################################################

# First: handle env vars

exe_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "${exe_dir}"
# exe_dir should be /usr/local/bin/

# stderr to stdout for all of script
exec 2>&1

env_file_base="setup_css.env"
source "${exe_dir}/setup_ss_init.sh"

if [ -z "$SERVER_FACTORY" ]
then
  echo 'Missing env var SERVER_FACTORY. Defaulting to SERVER_FACTORY="http"'
  SERVER_FACTORY='http'
  export SERVER_FACTORY='http'
fi

if [ -z "$WORKERS" ]
then
  echo 'Missing required env var WORKERS'
  exit 1
fi

if [ -z "$GIT_REPO_URL" ]
then
  echo 'Missing required env var GIT_REPO_URL'
  exit 1
fi

if [ -z "$GIT_CHECKOUT_ARG" ]
then
  echo 'Missing required env var GIT_CHECKOUT_ARG'
  exit 1
fi

if [ -z "$AUTHORIZATION" ]
then
  echo 'Missing required env var AUTHORIZATION'
  exit 1
fi

if [ -z "${GENERATE_USERS}" ]
then
  GENERATE_USERS='false'
fi

if [ -z "${GENERATE_CONTENT}" ]
then
  GENERATE_CONTENT='false'
fi

if [ "${GENERATE_CONTENT,,}" == "true" ] && [ "${GENERATE_USERS,,}" != "true" ]
then
  echo "Env var error: Cannot generate content without generating users: GENERATE_USERS=${GENERATE_USERS} GENERATE_CONTENT=${GENERATE_CONTENT}"
  exit 1
fi

if [ -z "$RESOURCE_LOCKER" ]
then
  echo 'Missing env var RESOURCE_LOCKER. Defaulting to RESOURCE_LOCKER="file"'
  RESOURCE_LOCKER='file'
  export RESOURCE_LOCKER='file'
fi

if [ -z "$STORAGE_BACKEND" ]
then
  echo 'Missing env var STORAGE_BACKEND. Defaulting to STORAGE_BACKEND="file"'
  STORAGE_BACKEND='file'
  export STORAGE_BACKEND='file'
fi

if [ -z "$NOTIFICATION_SERVER_CONFIG" ]
then
  echo 'Missing env var NOTIFICATION_SERVER_CONFIG. Defaulting to NOTIFICATION_SERVER_CONFIG="xxxx"'
  NOTIFICATION_SERVER_CONFIG='http'
  export NOTIFICATION_SERVER_CONFIG='http'
fi

if [ -z "$GENERATED_FILES_NEST_DEPTH" ]
then
  echo 'Missing env var GENERATED_FILES_NEST_DEPTH. Defaulting to GENERATED_FILES_NEST_DEPTH=0'
  GENERATED_FILES_NEST_DEPTH=0
  export GENERATED_FILES_NEST_DEPTH=0
fi

if [ -z "$GENERATED_FILES_ADD_AC_PER_RESOURCE" ]
then
  echo 'Missing env var GENERATED_FILES_ADD_AC_PER_RESOURCE. Defaulting to GENERATED_FILES_ADD_AC_PER_RESOURCE=true'
  GENERATED_FILES_ADD_AC_PER_RESOURCE='true'
  export GENERATED_FILES_ADD_AC_PER_RESOURCE='true'
fi

if [ -z "$GENERATED_FILES_ADD_AC_PER_DIR" ]
then
  echo 'Missing env var GENERATED_FILES_ADD_AC_PER_DIR. Defaulting to GENERATED_FILES_ADD_AC_PER_DIR=true'
  GENERATED_FILES_ADD_AC_PER_DIR='true'
  export GENERATED_FILES_ADD_AC_PER_DIR='true'
fi

if [ -z "$CONTENT_FILES_RDF_SIZE" ]
then
  # default 100k
  CONTENT_FILES_RDF_SIZE='100_000'
  export CONTENT_FILES_RDF_SIZE='100_000'
fi
CONTENT_FILES_RDF_SIZE=$(echo "${CONTENT_FILES_RDF_SIZE}" | tr -d '_\n')
CONTENT_FILES_RDF_SIZE_NICK=$(echo "${CONTENT_FILES_RDF_SIZE}" | sed -e 's/000$/k/' | sed -e 's/000k$/M/' | sed -e 's/000M$/G/' )

systemctl start redis-server || echo 'ignoring start redis failed'

echo "Using CSS commit: $GIT_CHECKOUT_ARG"

NICK=$(echo "$GIT_CHECKOUT_ARG" | tr -d -c '[:alnum:]')
SERVER_SOURCE_DIR="/usr/local/src/css-$NICK/"
#SERVER_DATA_CLEAN_DIR="/srv/css-$NICK-clean/"
INSTALL_PREFIX="/usr/local/css-$NICK"
CONFIG_DIR="/etc/css/$NICK"
CONFIG_FILE="${CONFIG_DIR}/perftest.json"
SERVER_NEUTRAL_HTTP_CONFIG_FILE="/usr/local/src/css-$NICK/config/perftest-$AUTHORIZATION-http.json"
SERVER_NEUTRAL_HTTPS_CONFIG_FILE="/usr/local/src/css-$NICK/config/perftest-$AUTHORIZATION-https.json"

HTTPS_CERT_FILE="${etc_dir}/css/server_cert.pem"
HTTPS_KEY_FILE="${etc_dir}/css/server_key.pem"

# Exe can be in 2 places, and both are fine
if [ -e "${INSTALL_PREFIX}/bin/community-solid-server" ]
then
  EXE="${INSTALL_PREFIX}/bin/community-solid-server"
else
  EXE="${SERVER_SOURCE_DIR}/bin/community-solid-server"
fi

echo "    NICK=$NICK"

make_content_id  # sets CONTENT_ID see generate_content.sh

##################################################################################################################
##################################################################################################################

function start_css() {
  # Start currently configured CSS
  #
  # Assumptions:
  #   - /etc/systemd/system/css.service is setup as needed
  #   - /etc/systemd/system/css.service points to the correct server dir and config file
  #   - the port and https/http is passed as args

  local _SS_PORT="$1"
  local _SS_PROTO="$2"

  echo "Starting server on port ${_SS_PORT} with proto ${_SS_PROTO}..."

  systemctl daemon-reload
  _USED_SS_PORT=$(sed -n -e 's/^ExecStart.*--port \([0-9][0-9]*\).*/\1/p' /etc/systemd/system/css.service)
  echo "   USED_SS_PORT in css.service=${_USED_SS_PORT}"

  # We never use traefik anymore. If this IS needed, re-enable this correctly
  #if [ "${_USED_SS_PORT}" -eq 443 ]
  #then
  #  echo 'Making sure traefik is stopped'
  #  systemctl stop traefik  || echo 'ignoring traefik stop failure'
  #elif [ "${_USED_SS_PORT}" -eq 3000 ]
  #then
  #  echo 'Making sure traefik is running'
  #  systemctl start traefik || true
  #  sleep 1
  #else
  #  echo "Failed to find CSS port in css.service. Can't know if traefik is needed."
  #  exit 1
  #fi

  systemctl start css

  echo "   Waiting until CSS is ready"

  #wait until CSS is ready
  _CSS_READY=false
  for wait in $(seq 1 120)  # wait max 2 minutes, then just give up
  do
    if ss -Hlnp --tcp sport "${_SS_PORT}" | grep -q '*:'"${_SS_PORT}"
    then
       echo "      OK: Something seems to be listening on port ${_SS_PORT}!"
       _CSS_READY=true
#       sleep 0.1
       break
    fi
    sleep 1  #wait until CSS is ready
    echo "   Waiting for CSS to listen to port ${_SS_PORT} ($wait)..."
  done

  if ! ${_CSS_READY}
  then
    echo 'ERROR: CSS did not start correctly'
    exit 1
  fi

  if [ "$_SS_PROTO" == "https" ]
  then
    # Wait until server under test has a valid cert
    #   (in most cases, that is from the start, but in the case of traefik, it might have to be fetched from letsencrypt)
    # Or CSS to be ready with SSL
    _CSS_CERT_READY=false
    for wait in $(seq 1 120)  # wait max 2 minutes, then just give up
    do
      if echo -n | openssl s_client -connect "${SS_PUBLIC_DNS_NAME}:${_SS_PORT}" -verify_return_error > /dev/null 2>&1;
      then
        echo "      OK: Got a valid certificate from ${SS_PUBLIC_DNS_NAME}:${_SS_PORT}"
        _CSS_CERT_READY=true
        sleep 0.2
        break
      else
        echo "      Not (yet) OK: Failed to get valid cert on ${SS_PUBLIC_DNS_NAME}:${_SS_PORT}"
      fi
      sleep 1  #wait until cert is ready
      echo "   Waiting for a valid certificate ($wait)..."
    done

    if ! ${_CSS_CERT_READY}
    then
      echo 'ERROR: CSS did not start correctly'
      exit 1
    fi
  else
    sleep 5
  fi

  # test SSL on 3000: openssl s_client -connect localhost:3000 -servername $(cat /etc/host_fqdn) -msg

  echo
  echo -n "   Test CSS at ${_SS_PROTO}://${SS_PUBLIC_DNS_NAME}:${_SS_PORT}/ ..."
#  echo -e "GET ${SS_PUBLIC_DNS_NAME}/ HTTP/1.1\nHost: selftest\nConnection: close\n\n" | tee /dev/stdout | openssl s_client -connect "${SS_PUBLIC_DNS_NAME}:443" -quiet
  _CSS_TEST_OUTPUT="$(curl -s -I "${_SS_PROTO}://${SS_PUBLIC_DNS_NAME}:${_SS_PORT}/" || true)"

  if ! echo "${_CSS_TEST_OUTPUT}" | grep -i -q 'x-powered-by: Community Solid Server'
  then
    echo " FAILED"
    echo 'ERROR: CSS Test failed.'
    echo "       Ran command: curl -s -I ${_SS_PROTO}://${SS_PUBLIC_DNS_NAME}:${_SS_PORT}/"
    echo "       Hint: check CSS service log for more info"
    echo '       Output:'
    echo "${_CSS_TEST_OUTPUT}"
    echo
    echo
    exit 1
  else
    echo " SUCCESS"
  fi

  return 0
}

##################################################################################################################
##################################################################################################################

function update_css_service_file() {
  # Rewrite css.service with the correct settings
  #
  # Input env vars:
  #   $GLOBAL_BASE_URL
  #   $CSS_PUBLIC_DNS_NAME
  #   $env_file
  #   $EXE
  #
  # parameters:
  #   $1 = CONFIG_FILE
  #   $2 = SERVER_DATA_DIR
  #   $3 = CSS_PORT_TO_USE
  #   $4 = neutral ("true" or "false")

  echo "Updating CSS systemd service to use config '$1' and root '$2'"

  BASE_URL="${GLOBAL_BASE_URL}"

#  cp -v "/etc/systemd/system/css.service.template" /etc/systemd/system/
  sed -e "s/<<CSS_DNS_NAME>>/${SS_PUBLIC_DNS_NAME}/g" \
      -e "s#<<CSS_BASE_URL>>#${BASE_URL}#g" \
      -e "s#<<ENV_FILE>>#${env_file}#g" \
      -e "s#<<CSS_EXE>>#${EXE}#g" \
      -e "s#<<CSS_ROOT_PATH>>#${2}#g" \
      -e "s#<<CSS_CONFIG_FILE>>#${1}#g" \
      -e "s/--port [0-9][0-9]*/--port ${3}/" \
        < "/etc/systemd/system/css.service.template" \
        > "/etc/systemd/system/css.service"

  systemctl daemon-reload
  return 0
}

##################################################################################################################
##################################################################################################################

function create_neutral_config() {
  # Create a neutral config

  # Input env vars:
  #   $GIT_REPO_URL
  #   $GIT_CHECKOUT_ARG
  #   $SERVER_SOURCE_DIR
  #   SERVER_NEUTRAL_HTTP_CONFIG_FILE
  #   SERVER_NEUTRAL_HTTPS_CONFIG_FILE
  #   $INSTALL_PREFIX
  #   $EXE
  #   $HTTPS_CERT_FILE
  #   $HTTPS_KEY_FILE
  #
  # Output env vars:
  #

  ##### create "neutral" config

  #   - uses http, so needs traefik for tls termination (reason: tls failure seen in a version)
  #   - file based
  #   - no setup
  #   - identity/registration/enabled.json (6.0) or identity/interaction/default.json (7.0)
  #   - resource-locker/file.json (not really important)
  #   - no http/middleware/websockets because not threadsafe
  #   - http/notifications/disabled.json

  cd "${SERVER_SOURCE_DIR}"

  # CSS upto 6
  CSS_CONFIG_BASE="config/file-no-setup.json"
  if [ ! -e "${CSS_CONFIG_BASE}" ]
  then
    # CSS 7.0.0
    CSS_CONFIG_BASE="config/file-root.json"
  fi

  if [ ! -e "${CSS_CONFIG_BASE}" ]
  then
    echo "Could not find a base CSS config file in ${SERVER_SOURCE_DIR}: $(ls config/)"
    exit 1
  fi

  # Neutral file REQUIRES authorization to be correct! (since it is used to generate data and thus authZ files.)
  LDP_AUTHORIZATION='error'
  AUXILIARY='error'
  if [ "${AUTHORIZATION}" == 'webacl' ] || [ "${AUTHORIZATION}" == 'wac' ]
  then
    LDP_AUTHORIZATION='webacl'
    AUXILIARY='acl'
  elif [ "${AUTHORIZATION}" == 'acp' ]
  then
    LDP_AUTHORIZATION='acp'
    AUXILIARY='acr'
  elif [ "${AUTHORIZATION}" == 'allow-all' ]
  then
    LDP_AUTHORIZATION='allow-all'
    AUXILIARY='empty'
  else
     echo "Unsupported AUTHORIZATION=${AUTHORIZATION}"
     exit 1
  fi

  jq '."@graph"[].comment = "SolidLab PerfTest neutral HTTP config with AUTHORIZATION='"${AUTHORIZATION}"' LDP_AUTHORIZATION='"${LDP_AUTHORIZATION}"' AUXILIARY='"${AUXILIARY}"'"
        | (..|strings|select(contains("http/server-factory/"))) |= sub("/[\\w._-]+$"; "/http.json")
        | (..|strings|select(contains("identity/registration/"))) |= sub("/[\\w._-]+$"; "/enabled.json")
        | (..|strings|select(contains("identity/handler/"))) |= sub("/[\\w._-]+$"; "/default.json")
        | (..|strings|select(contains("identity/interaction/"))) |= sub("/[\\w._-]+$"; "/default.json")
        | (..|strings|select(contains("http/middleware/websockets.json"))) |= sub("/[\\w._-]+$"; "/no-websockets.json")
        | (..|strings|select(contains("http/notifications/"))) |= sub("/[\\w._-]+$"; "/disabled.json")
        | (..|strings|select(contains("ldp/authorization/"))) |= sub("/[\\w._-]+$"; "/'"${LDP_AUTHORIZATION}"'.json")
        | (..|strings|select(contains("util/auxiliary/"))) |= sub("/[\\w._-]+$"; "/'"${AUXILIARY}"'.json")
        ' \
     < "${CSS_CONFIG_BASE}" \
     > "${SERVER_NEUTRAL_HTTP_CONFIG_FILE}"

  jq '."@graph"[].comment = "SolidLab PerfTest neutral HTTPS config with AUTHORIZATION='"${AUTHORIZATION}"' LDP_AUTHORIZATION='"${LDP_AUTHORIZATION}"' AUXILIARY='"${AUXILIARY}"'"
        | (..|strings|select(contains("http/server-factory/"))) |= sub("/[\\w._-]+$"; "/https.json")
        | (..|strings|select(contains("identity/registration/"))) |= sub("/[\\w._-]+$"; "/enabled.json")
        | (..|strings|select(contains("identity/handler/"))) |= sub("/[\\w._-]+$"; "/default.json")
        | (..|strings|select(contains("identity/interaction/"))) |= sub("/[\\w._-]+$"; "/default.json")
        | (..|strings|select(contains("http/middleware/websockets.json"))) |= sub("/[\\w._-]+$"; "/no-websockets.json")
        | (..|strings|select(contains("http/notifications/"))) |= sub("/[\\w._-]+$"; "/disabled.json")
        | (..|strings|select(contains("ldp/authorization/"))) |= sub("/[\\w._-]+$"; "/'"${LDP_AUTHORIZATION}"'.json")
        | (..|strings|select(contains("util/auxiliary/"))) |= sub("/[\\w._-]+$"; "/'"${AUXILIARY}"'.json")
        ' \
     < "${CSS_CONFIG_BASE}" \
     > "${SERVER_NEUTRAL_HTTPS_CONFIG_FILE}"
  echo -n 'DEBUG neutral config http: '
  grep -H 'server-factory' "${SERVER_NEUTRAL_HTTP_CONFIG_FILE}"
  echo -n 'DEBUG neutral config https: '
  grep -H 'server-factory' "${SERVER_NEUTRAL_HTTPS_CONFIG_FILE}"
}

##################################################################################################################
##################################################################################################################

function install_css() {
  # Install a specific CSS version
  # This also creates a neutral config, and a dirty config

  # Input env vars:
  #   $GIT_REPO_URL
  #   $GIT_CHECKOUT_ARG
  #   $SERVER_SOURCE_DIR
  #   $SERVER_NEUTRAL_HTTP_CONFIG_FILE
  #   $SERVER_NEUTRAL_HTTPS_CONFIG_FILE
  #   $INSTALL_PREFIX
  #   $EXE
  #   HTTPS_CERT_FILE
  #   HTTPS_KEY_FILE
  #
  # Output env vars:
  #

  mkdir -p /usr/local/src/
  cd /usr/local/src/

  rm -rf "${SERVER_SOURCE_DIR}" "${INSTALL_PREFIX}"

  git clone "${GIT_REPO_URL}" "${SERVER_SOURCE_DIR}"
  cd "${SERVER_SOURCE_DIR}"
  git checkout "$GIT_CHECKOUT_ARG"

  # Check which version we checked out. Informative only!
  _CSS_VERSION=$(jq -r '.version' package.json)
  if [ -z "${_CSS_VERSION}" ]
  then
    echo "Failed to get CSS version"
  else
    echo "CSS VERSION according to package.json is: ${_CSS_VERSION}"
  fi

  ##### Modify config in source code

  # Make access tokens valid for 10 years
  echo 'Increasing access token ttl to 10 years:'
  ttl_file='config/identity/handler/provider-factory/identity.json'  # v6
  if [ ! -e "${ttl_file}" ]
  then
     ttl_file='config/identity/handler/base/provider-factory.json'  # v7
  fi
  cp "${ttl_file}" "${ttl_file}.orig"
  # identity.json contained trailing comma in json at some point . We use rjson to fix it (if present).
  if which rjson > /dev/null 2> /dev/null
  then
     # rjson is the cli tool of relaxed-json. See https://github.com/phadej/relaxed-json
     # see also https://github.com/jqlang/jq/wiki/FAQ#processing-not-quite-valid-json
     rjson "${ttl_file}.orig" > "${ttl_file}"
  fi
  jq '."@graph"[].config.ttl.AccessToken = 315576000 | ."@graph"[].config.ttl.ClientCredentials = 315576000' \
      > "${ttl_file}" \
      < "${ttl_file}.orig"
  jq '."@graph"[].config.ttl' < "${ttl_file}"
  echo

#  if [ "$SERVER_FACTORY" == "https" ]  # do this always, we just don't use https.json if "$SERVER_FACTORY" != "https"
#  then
    echo 'Hardcoding HTTPS certificate locations:'
    https_no_cli_config_file="config/http/server-factory/https-no-cli-example.json"
    if [ -e "${https_no_cli_config_file}" ]
      then
        cp "${https_no_cli_config_file}" "${https_no_cli_config_file}.orig"
        jq '(..|.options_key? // empty) = "'"${HTTPS_KEY_FILE}"'"  | (..|.options_cert? // empty) = "'"${HTTPS_CERT_FILE}"'"' \
               < "${https_no_cli_config_file}.orig" \
               > "${https_no_cli_config_file}"
        grep -H 'options_' "${https_no_cli_config_file}"
        echo

        # Use https-no-cli-example.json instead of https.json
        if [ -e "config/http/server-factory/https.json" ]
        then
           cp -v "config/http/server-factory/https.json" "config/http/server-factory/https.json.orig"
        fi
        cp -v "${https_no_cli_config_file}" "config/http/server-factory/https.json"
    else
      for https_config_file in 'config/http/server-factory/https.json' 'config/http/server-factory/https-websockets.json' 'config/http/server-factory/https-no-websockets.json'
      do
        if [ -e "${https_config_file}" ]
        then
          cp "${https_config_file}" "${https_config_file}.orig"
          jq '(..|.options_key? // empty) = "'"${HTTPS_KEY_FILE}"'"  | (..|.options_cert? // empty) = "'"${HTTPS_CERT_FILE}"'"' \
                 < "${https_config_file}.orig" \
                 > "${https_config_file}"
    #      jq '."@graph"[].options_key = "'"${HTTPS_KEY_FILE}"'" | ."@graph"[].options_cert = "'"${HTTPS_CERT_FILE}"'"' \
    #    jq '."@graph"[].baseServerFactory.options_key = "'"${HTTPS_KEY_FILE}"'" | ."@graph"[].baseServerFactory.options_cert = "'"${HTTPS_CERT_FILE}"'"' \
          grep -H 'options_' "${https_config_file}"
          echo
        fi
      done
    fi
#  fi

  ##### make copies to be backward compatible:
  #####    server-factory/https -> server-factory/https-no-websockets or server-factory/https-example
  #####    server-factory/http -> server-factory/no-websockets
  #####    middleware/no-websockets -> middleware/default

  # make older config forward compatible by creating http.json and https.json
  if [ -e 'config/http/server-factory/https-no-websockets.json' ] && [ ! -e 'config/http/server-factory/https.json' ]
  then
    cp -v 'config/http/server-factory/https-no-websockets.json' 'config/http/server-factory/https.json'
  fi
  if [ -e 'config/http/server-factory/no-websockets.json' ] && [ ! -e 'config/http/server-factory/http.json' ]
  then
    cp -v 'config/http/server-factory/no-websockets.json' 'config/http/server-factory/http.json'
  fi
  if [ -e 'config/http/server-factory/http.json' ] && [ ! -e 'config/http/server-factory/https.json' ]
  then
    echo 'Creating https.json from http.json'
    #"options_https": true,
    jq 'del(..|.webSocketHandler?) | (..|."@type"? | select(. == "WebSocketServerFactory")) = "BaseHttpServerFactory" | ."@graph"[].options_https = "true" | ."@graph"[].options_key = "'"${HTTPS_KEY_FILE}"'" | ."@graph"[].options_cert = "'"${HTTPS_CERT_FILE}"'"' \
       < 'config/http/server-factory/http.json' \
       > 'config/http/server-factory/https.json'
  fi
  # make older config forward compatible by creating middleware/default.json
  if [ -e 'config/http/middleware/no-websockets.json' ] && [ ! -e 'config/http/middleware/default.json' ]
  then
    cp -v 'config/http/middleware/no-websockets.json' 'config/http/middleware/default.json'
  fi

  # make pre file locker configs compatible by replacing file locker with debug-void
  # This is obviously not "fair", but we need something to compare to.
  if [ -e 'config/util/resource-locker/debug-void.json' ] && [ ! -e 'config/util/resource-locker/file.json' ]
  then
    echo 'There is no file locker. Using debug-void instead.'
    cp -v 'config/util/resource-locker/debug-void.json' 'config/util/resource-locker/file.json'
  fi

  if [ ! -e 'config/util/resource-locker/redis.json' ]
  then
    echo 'There is no redis locker! Cannot continue.' >&2
    exit 1
  fi

  ##### create "neutral" config

  #   - uses http, so needs traefik for tls termination (reason: tls failure seen in a version)
  #   - file based
  #   - no setup
  #   - identity/registration/enabled.json
  #   - resource-locker/file.json (not really important)
  #   - no http/middleware/websockets because not threadsafe
  #   - http/notifications/disabled.json

  create_neutral_config

  ##### build

  if ! which tsc >/dev/null 2>&1
  then
    echo "typescript (tsc) is not installed, but it is required. PATH='$PATH'"
    exit 1
  fi
  echo "'tsc' is at: $(which tsc 2>&1 || true) and is version $(tsc --version || true)"

  echo "Building in: $(pwd)"

  npm config set prefix "${INSTALL_PREFIX}"
  echo "npm prefix set to: $(npm prefix -g)"
  export PATH="$PATH:${SERVER_SOURCE_DIR}node_modules/.bin/:${INSTALL_PREFIX}/bin/"
  npm ci 2>&1  # same as npm install, but faster and stricter. This also requires package-lock.json to exist

  npm run build 2>&1

  if [ ! -d dist ]
  then
    echo "Failed to install CSS: 'npm run build' did not generate dist dir in $(pwd)"
    echo "PATH='$PATH'"
    set -x
    ls dist
    ls "${SERVER_SOURCE_DIR}node_modules/.bin/"
    ls "${INSTALL_PREFIX}/bin/"
    exit 1
  fi

  npm install -g 2>&1
  echo 'After "npm install -g", exes: '
  (ls "${INSTALL_PREFIX}/bin/community-solid-server" "${SERVER_SOURCE_DIR}bin/community-solid-server" 2>&1) || echo
  echo

  npm link 2>&1  # install -g should have done this, but it doesn't always happen?
  echo 'After "npm link", exes: '
  (ls "${INSTALL_PREFIX}/bin/community-solid-server" "${SERVER_SOURCE_DIR}bin/community-solid-server" 2>&1) || echo
  echo

  npm config delete prefix
  echo -n "npm prefix reset to: "
  npm prefix -g

  # Figure out where npm put the exe
  if [ -e "${INSTALL_PREFIX}/bin/community-solid-server" ]
  then
    EXE="${INSTALL_PREFIX}/bin/community-solid-server"
  else
    EXE="${SERVER_SOURCE_DIR}bin/community-solid-server"
  fi

  if [ -e "$EXE" ]
  then
    echo "CSS exe: $EXE"
  else
    echo "Failed to install CSS: no exe"
    echo "   No exe at '${INSTALL_PREFIX}/bin/community-solid-server' or '${SERVER_SOURCE_DIR}bin/community-solid-server'"
    echo "PATH='$PATH'"
    set -x
    ls -R "$INSTALL_PREFIX" "${SERVER_SOURCE_DIR}bin"
    exit 1
  fi

  return 0
}

##################################################################################################################
##################################################################################################################

function generate_css_data() {
  local _CSS_DATA_DIR="$1"
  local _USERS_JSON_FILE_OUT="$2"

  if [ -z "${_CSS_DATA_DIR}" ]
  then
    echo 'Missing arg _CSS_DATA_DIR'
    exit 1
  fi

  if [ -z "${_USERS_JSON_FILE_OUT}" ]
  then
    echo 'Missing arg _USERS_JSON_FILE_OUT'
    exit 1
  fi

  if [ "${GENERATE_CONTENT,,}" != "true" ] && [ "${GENERATE_USERS,,}" != "true" ]
  then
    # Nothing to do
    echo "Nothing to do: GENERATE_CONTENT=${GENERATE_CONTENT} GENERATE_USERS=${GENERATE_USERS}"
    # Well OK, we do have to make the empty dir
    if [ ! -d "${CSS_NICKCONT_CLEAN_DATA_DIR}" ]
    then
      mkdir "${CSS_NICKCONT_CLEAN_DATA_DIR}"
    fi
    return 0;
  fi

  if [ "${STORAGE_BACKEND}" == 'file' ] || [ "${STORAGE_BACKEND}" == 'tmpfs' ]
  then
    rm -rf "${_CSS_DATA_DIR}"
    mkdir "${_CSS_DATA_DIR}"
  fi

  local _START_SS=true
  if [ "${STORAGE_BACKEND}" == 'memory' ]
  then
    _START_SS=false
  fi

#  local _used_port=3000
#  local _used_proto=http
  local _used_port="${USED_SS_PORT}"
  local _used_proto="${HTTP_PROTO_PREFIX}"

  if "${_START_SS}"
  then
    update_css_service_file "${SERVER_NEUTRAL_HTTPS_CONFIG_FILE}" "${_CSS_DATA_DIR}" "${_used_port}"
    start_css "${_used_port}" "${_used_proto}"
  fi

  generate_ss_data $1 "${_used_port}" "${_used_proto}" "${_USERS_JSON_FILE_OUT}"
  _GEN_RET="$?"

  if "${_START_SS}"
  then
    systemctl stop css traefik || true
  fi

  return ${_GEN_RET}
}

##################################################################################################################
##################################################################################################################

function collect_access_tokens() {
  # Collect access tokens for all users, and store them in cache in well known location
  #
  # Input env vars:
  #   $CSS_PUBLIC_DNS_NAME
  #   $SERVER_NEUTRAL_HTTP_CONFIG_FILE
  #   $SERVER_NEUTRAL_HTTPS_CONFIG_FILE

  # Parameters:
  #   $1 = running CSS server data dir
  #   $2 = target auth cache file
  local _CSS_DATA_DIR="$1"
  local _AUTH_CACHE_FILE="$2"
  local _ACCOUNTS_FILE="$3"

  if [ -e "${_CSS_DATA_DIR}/ERROR" ]
  then
    echo "Cannot collect access tokens: ${_CSS_DATA_DIR}/ERROR exists before start!"
    exit 1
  fi

#  local _used_port=3000
#  local _used_proto=http
  local _used_port="${USED_SS_PORT}"
  local _used_proto="${HTTP_PROTO_PREFIX}"

  update_css_service_file "${SERVER_NEUTRAL_HTTPS_CONFIG_FILE}" "${_CSS_DATA_DIR}" "${_used_port}"
  start_css "${_used_port}" "${_used_proto}"

  # Note: _ACCOUNTS_FILE has basename and port matching USED_SS_PORT and HTTP_PROTO_PREFIX

  echo "Collecting access tokens for all users"
  set -x
  solid-flood --accounts USE_EXISTING --account-source FILE --account-source-file ${_ACCOUNTS_FILE} \
            --duration 1 --parallel 1 \
            --authenticate --authenticateCache all --filename dummy.txt \
            --steps 'loadAC,fillAC,validateAC,saveAC' \
            --ensure-auth-expiration 600 \
            --authCacheFile "${_AUTH_CACHE_FILE}" || touch "${_CSS_DATA_DIR}/ERROR"
  set +x

  systemctl stop css traefik || true

  if [ -e "${_CSS_DATA_DIR}/ERROR" ]
  then
    echo 'Failed to collect access tokens'
    exit 1
  fi

  sleep 1

  return 0
}

##################################################################################################################
##################################################################################################################

function create_css_config_file() {
  # Create a clean CSS config file using values from setup_css.env

  # Parameters:
  #   $1 = CONFIG DIR
  #   $2 = CONFIG FILE

  local _CONFIG_DIR="$1"
  local _CONFIG_FILE="$2"

  # Input env vars:
  #   $env_file

  cd "${SERVER_SOURCE_DIR}"

  # CSS upto 6
  CSS_CONFIG_BASE="config/file-no-setup.json"
  if [ ! -e "${CSS_CONFIG_BASE}" ]
  then
    # CSS 7.0.0
    CSS_CONFIG_BASE="config/file-root.json"
  fi

  if [ ! -d "${_CONFIG_DIR}" ]
  then
    echo "Creating ${_CONFIG_DIR}"
    mkdir -p "${_CONFIG_DIR}"
  fi

#  cp "${SERVER_NEUTRAL_CONFIG_FILE}" "${_CONFIG_FILE}"
  chmod -R uog+r "${_CONFIG_DIR}"
  chmod -R og-w "${_CONFIG_DIR}"

  echo "Updating CSS config using vars in '${env_file}'"
  # Used env vars from setup_css.env:
  #   AUTHORIZATION='allow-all' (default) or 'webacl' or 'acp'
  #   RESOURCE_LOCKER='file' (default) or 'debug-void' or 'redis' or 'memory'
  #   STORAGE_BACKEND='file' (default) or 'memory' or 'tmpfs'
  #   SERVER_FACTORY='no-websockets' (default) or 'websockets' or 'https-no-websockets' or 'https-websockets' for CSS 5
  #   SERVER_FACTORY='http' (default) or 'https' for CSS 6
  #     the https options add server config parameters: --httpsKey and --httpsCert
  #   NOTIFICATION_SERVER_CONFIG='disabled' or 'websockets' or 'webhooks' or 'all'
  #
  # Indirectly used env vars:
  #  -> not configured here, as EnvironmentFile= in /etc/systemd/system/css.service picks this up automatically
  #   WORKERS='1' or '2' or any other number   -> --workers ${WORKERS}

  ###

  USED_STORAGE_BACKEND="${STORAGE_BACKEND}"
  if [ "${STORAGE_BACKEND}" == 'tmpfs' ]
  then
    USED_STORAGE_BACKEND="file"
  fi

  LDP_AUTHORIZATION='error'
  AUXILIARY='error'
  if [ "${AUTHORIZATION}" == 'webacl' ] || [ "${AUTHORIZATION}" == 'wac' ]
  then
    LDP_AUTHORIZATION='webacl'
    AUXILIARY='acl'
  elif [ "${AUTHORIZATION}" == 'acp' ]
  then
    LDP_AUTHORIZATION='acp'
    AUXILIARY='acr'
  elif [ "${AUTHORIZATION}" == 'allow-all' ]
  then
    LDP_AUTHORIZATION='allow-all'
    AUXILIARY='empty'
  else
     echo "Unsupported AUTHORIZATION=${AUTHORIZATION}"
     exit 1
  fi

  if [ ! -e "${_CONFIG_FILE}" ]
  then
    cp -v "${CSS_CONFIG_BASE}" "${_CONFIG_FILE}"
  fi
  cp -v "${_CONFIG_FILE}" "${_CONFIG_FILE}.bck"

  # Finally, rewrite the config file

  # notifications were alwayss disable before:
#            | (..|strings|select(contains("http/notifications/"))) |= sub("/[\\w._-]+$"; "/disabled.json")
  jq '."@graph"[].comment = "SolidLab PerfTest config for AUTHORIZATION='"${AUTHORIZATION}"' LDP_AUTHORIZATION='"${LDP_AUTHORIZATION}"' AUXILIARY='"${AUXILIARY}"' RESOURCE_LOCKER='"${RESOURCE_LOCKER}"' STORAGE_BACKEND='"${USED_STORAGE_BACKEND}"' ('"${STORAGE_BACKEND}"') NOTIFICATION_SERVER_CONFIG='"${NOTIFICATION_SERVER_CONFIG}"' SERVER_FACTORY='"${SERVER_FACTORY}"'"
            | (..|strings|select(contains("http/server-factory/"))) |= sub("/[\\w._-]+$"; "/'"${SERVER_FACTORY}"'.json")
            | (..|strings|select(contains("ldp/authorization/"))) |= sub("/[\\w._-]+$"; "/'"${LDP_AUTHORIZATION}"'.json")
            | (..|strings|select(contains("util/auxiliary/"))) |= sub("/[\\w._-]+$"; "/'"${AUXILIARY}"'.json")
            | (..|strings|select(contains("util/resource-locker/"))) |= sub("/[\\w._-]+$"; "/'"${RESOURCE_LOCKER}"'.json")
            | (..|strings|select(contains("storage/backend/"))) |= sub("/[\\w._-]+$"; "/'"${USED_STORAGE_BACKEND}"'.json")
            | (..|strings|select(contains("http/notifications/"))) |= sub("/[\\w._-]+$"; "/'"${NOTIFICATION_SERVER_CONFIG}"'.json")
            | (..|strings|select(contains("identity/registration/"))) |= sub("/[\\w._-]+$"; "/enabled.json")
            | (..|strings|select(contains("identity/handler/"))) |= sub("/[\\w._-]+$"; "/default.json")
            | (..|strings|select(contains("identity/interaction/"))) |= sub("/[\\w._-]+$"; "/default.json")
            | (..|strings|select(contains("http/middleware/websockets.json"))) |= sub("/[\\w._-]+$"; "/no-websockets.json")
            ' \
         < "${_CONFIG_FILE}.bck" \
         > "${_CONFIG_FILE}"

  # TODO if LOCK_EXPIRATION is enabled, add this to @graph:
  #  {
  #      "comment": "The new expiration time for inactive locks, in milliseconds.",
  #      "@type": "Override",
  #      "overrideInstance": {
  #        "@id": "urn:solid-server:default:ResourceLocker"
  #      },
  #      "overrideParameters": {
  #        "@type": "WrappedExpiringReadWriteLocker",
  #        "expiration": 6000
  #      }
  #    }
}

##################################################################################################################
##################################################################################################################

echo "Stopping CSS"
systemctl stop css traefik || echo 'ignoring stop failed'

echo '#########################################################'

echo "Cleaning up any old tmpfs mounts"

# the final cat is to ignore greps exit status. (Because MOUNTS can be empty)
MOUNTS=$(grep tmpfs '/proc/mounts' | cut -d ' ' -f 2 | grep '/srv/' | cat)
for TMOUNT in $MOUNTS
do
  echo "Unmounting tmpfs at '${TMOUNT}'"
  umount "${TMOUNT}"
done

echo '#########################################################'

# Now, make sure that we have:
#  - a CSS install for this version
#  - a CSS server data dir with data for this version
#  - the same dir + a cache with access tokens

if [ ! -d "${SERVER_SOURCE_DIR}" ] || [ ! -e "${EXE}" ]
then
  echo "No CSS install for $NICK. Will create one in ${SERVER_SOURCE_DIR} with exe ${EXE}"
  install_css
else
  echo "Using existing CSS install for $NICK: ${SERVER_SOURCE_DIR} with exe ${EXE}"
fi

#if [ ! -e "$SERVER_NEUTRAL_CONFIG_FILE" ]
#then
#  create_neutral_config
#fi

echo '#########################################################'

# Dir to store metadata (account info and auth cache) for this NICK+CONTENT_ID
CSS_NICKCONT_METADATA_DIR="/srv/css-commit-$NICK-${CONTENT_ID}-meta/"

# Datadir of empty CSS server for this NICK+CONTENT_ID
CSS_NICKCONT_CLEAN_DATA_DIR="/srv/css-commit-$NICK-${CONTENT_ID}-clean/"

# Datadir of empty CSS server for this NICK+CONTENT_ID + with internal account info (user and access tokens etc) matching auth-cache
CSS_NICKCONT_CLEAN_AUTH_DIR="/srv/css-commit-$NICK-${CONTENT_ID}-clean-auth/"

# Actual dir used by running CSS (which means it can get "dirty" during testing)
SERVER_DATA_DIR="/srv/css-$NICK-${CONTENT_ID}/"

# File(s) in which we make the authentication cache easily available
CSS_NICKCONT_AUTH_CACHE_FILE="${CSS_NICKCONT_METADATA_DIR}auth-cache.json"
CSS_NICKCONT_USER_JSON_FILE="${CSS_NICKCONT_METADATA_DIR}accounts.json"

if [ ! -d "${CSS_NICKCONT_METADATA_DIR}" ]
then
  mkdir -p "${CSS_NICKCONT_METADATA_DIR}"
fi

if [ "${STORAGE_BACKEND}" == 'file' ] || [ "${STORAGE_BACKEND}" == 'tmpfs' ]
then
  # Generate clean content dir
  LAST_USER_ID=$(( CONTENT_USER_COUNT - 1 ))
  if [ ! -d "${CSS_NICKCONT_CLEAN_DATA_DIR}" ] || \
     [ ! -d "${CSS_NICKCONT_CLEAN_DATA_DIR}/user${LAST_USER_ID}" ] || \
     [ ! -d "${CSS_NICKCONT_CLEAN_DATA_DIR}/.internal" ] || \
     [ -e "${CSS_NICKCONT_CLEAN_DATA_DIR}/ERROR" ]
  then
    echo "Need to generate data for $NICK-${CONTENT_ID} in ${CSS_NICKCONT_CLEAN_DATA_DIR}"
    if [ -e "${CSS_NICKCONT_USER_JSON_FILE}" ]
    then
      rm "${CSS_NICKCONT_USER_JSON_FILE}"
    fi
    generate_css_data "${CSS_NICKCONT_CLEAN_DATA_DIR}" "${CSS_NICKCONT_USER_JSON_FILE}"
  else
    echo "Will use existing generated data for $NICK-${CONTENT_ID} in ${CSS_NICKCONT_CLEAN_DATA_DIR}"
  fi

  echo '#########################################################'

  if [ "${GENERATE_USERS,,}" == "true" ]
  then
    # Add auth cache to content dir
    if [ ! -d "${SERVER_DATA_CLEAN_AUTH_DIR}" ] || \
       [ ! -d "${SERVER_DATA_CLEAN_AUTH_DIR}/.internal/accounts" ] || \
       [ ! -e "${CSS_NICKCONT_AUTH_CACHE_FILE}" ] || \
       [ -e "${SERVER_DATA_CLEAN_AUTH_DIR}/ERROR" ]
    then
      if [ ! -d "${CSS_NICKCONT_CLEAN_DATA_DIR}" ]
      then
        echo 'Fatal: No CSS dir clean copy available. (Should have been created earlier by this script)'
        exit 1
      fi

      echo "Need to make an auth-cache for $NICK-${CONTENT_ID} in ${CSS_NICKCONT_AUTH_CACHE_FILE} with server dir ${CSS_NICKCONT_CLEAN_AUTH_DIR}"
      echo "Filling '${CSS_NICKCONT_CLEAN_AUTH_DIR}' with clean data for CSS commit $NICK"
      rm -rf "${CSS_NICKCONT_CLEAN_AUTH_DIR}"
      cp -a "${CSS_NICKCONT_CLEAN_DATA_DIR}" "${CSS_NICKCONT_CLEAN_AUTH_DIR}"
      # copied all files, including hidden files and CSS server internal data

      collect_access_tokens "${CSS_NICKCONT_CLEAN_AUTH_DIR}" "${CSS_NICKCONT_AUTH_CACHE_FILE}" "${CSS_NICKCONT_USER_JSON_FILE}"

      du -hs "${CSS_NICKCONT_CLEAN_DATA_DIR}" "${CSS_NICKCONT_CLEAN_AUTH_DIR}" || echo ''
    else
      echo "Will use exiting auth-cache for $NICK-${CONTENT_ID} in ${CSS_NICKCONT_CLEAN_DATA_DIR} with server dir ${CSS_NICKCONT_CLEAN_AUTH_DIR}"
    fi
  else
    if [ ! -d "${CSS_NICKCONT_CLEAN_AUTH_DIR}" ]
    then
      if [ ! -d "${CSS_NICKCONT_CLEAN_DATA_DIR}" ]
      then
        echo 'Fatal: No CSS dir clean copy available. (Should have been created earlier by this script)'
        exit 1
      fi

      echo "Creating clean '${CSS_NICKCONT_CLEAN_AUTH_DIR}' for CSS commit $NICK"
      cp -a "${CSS_NICKCONT_CLEAN_DATA_DIR}" "${CSS_NICKCONT_CLEAN_AUTH_DIR}"
    fi
  fi
fi

echo '#########################################################'

# Ok, we have the required install and dirs. Now make everything fully ready for use

echo '***********************'
echo '* CSS Install ready ***'
echo '***********************'

create_css_config_file "${CONFIG_DIR}" "${CONFIG_FILE}"
update_css_service_file "${CONFIG_FILE}" "${SERVER_DATA_DIR}" "${USED_SS_PORT}"

if [ "${STORAGE_BACKEND}" == 'file' ] || [ "${STORAGE_BACKEND}" == 'tmpfs' ]
then
  echo "Resetting CSS data dir at ${SERVER_DATA_DIR} to clean version"

  if [ -d "${CSS_NICKCONT_CLEAN_AUTH_DIR}" ]
  then
    if [ -d "${SERVER_DATA_DIR}" ]
    then
      echo "Removing CSS content dir '${SERVER_DATA_DIR}' and replacing with clean copy with auth"
      rm -rf "${SERVER_DATA_DIR}"
    else
      echo "Creating CSS content dir '${SERVER_DATA_DIR}' from clean copy with auth"
    fi

    if [ "${STORAGE_BACKEND}" == 'tmpfs' ]
    then
      echo "mounting tmpfs at '${SERVER_DATA_DIR}'"
      mkdir "${SERVER_DATA_DIR}"
      mount -t tmpfs css-dir-tmp "${SERVER_DATA_DIR}"
      echo -n 'Mounted /srv/ tmpfs dirs:'
      grep tmpfs '/proc/mounts' | grep '/srv/'
      shopt -s dotglob  # include hidden files in *
      cp -a "${CSS_NICKCONT_CLEAN_AUTH_DIR}/"* "${SERVER_DATA_DIR}"
      shopt -u dotglob
    else
      # file
      cp -a "${CSS_NICKCONT_CLEAN_AUTH_DIR}" "${SERVER_DATA_DIR}"
    fi
  else
    echo 'Fatal: No CSS dir clean copy available. (Should have been created earlier by this script)'
    exit 1
  fi
fi

echo '#########################################################'

# Let testing.solidlab.be know about our final CONFIG_FILE content
if [ "$SERVER_UNDER_TEST" == "css" ] && [ -n "${PERFTEST_UPLOAD_ENDPOINT}" ] && [ -n "${PERFTEST_UPLOAD_AUTH_TOKEN}" ]
then
    solidlab-perftest-upload "${PERFTEST_UPLOAD_ENDPOINT}" "${CONFIG_FILE}" \
              --auth-token "${PERFTEST_UPLOAD_AUTH_TOKEN}" \
              --mime-type 'application/json' \
              --type OTHER --sub-type 'css config' \
              --description 'CSS main config (perftest.json)' || echo "Failed to log CSS config ${CONFIG_FILE}. Will ignore."

    MODIFIED_CSS_CONFIG_FILES='config/identity/handler/provider-factory/identity.json config/http/server-factory/https.json config/http/server-factory/http.json config/http/server-factory/https-websockets.json config/http/server-factory/https-no-websockets.json config/http/middleware/default.json config/http/middleware/no-websockets.json config/util/resource-locker/file.json'
    for SUB_CONFIG_FILE in ${MODIFIED_CSS_CONFIG_FILES}
    do
      SUB_CONFIG_FILE="${SERVER_SOURCE_DIR}${SUB_CONFIG_FILE}"
      if [ -e "${SUB_CONFIG_FILE}" ]
      then
        solidlab-perftest-upload "${PERFTEST_UPLOAD_ENDPOINT}" "${SUB_CONFIG_FILE}" \
                  --auth-token "${PERFTEST_UPLOAD_AUTH_TOKEN}" \
                  --mime-type 'application/json' \
                  --type OTHER --sub-type 'css config' \
                  --description "CSS config ${SUB_CONFIG_FILE}" || echo "Failed to log CSS config ${SUB_CONFIG_FILE}. Will ignore."
      fi
    done
else
  echo 'Will not log CSS config'
fi

echo '#########################################################'

if [ "$SERVER_UNDER_TEST" == "nginx" ]
then
  echo "Starting nginx (+ configuring it)"

  # Configure nginx if needed
  if [ "$SERVER_FACTORY" == "https" ] && [ ! -e /etc/letsencrypt/options-ssl-nginx.conf ]
  then
    cp -v /etc/nginx/sites-enabled/default /tmp/backup-nginx-sites-enabled-default
    certbot run --nginx --domain "${SS_PUBLIC_DNS_NAME}" --agree-tos --register-unsafely-without-email

    cp -v /etc/nginx/sites-enabled/default /tmp/backup-nginx-sites-enabled-default-after-certbot
    cp -v /tmp/backup-nginx-sites-enabled-default /etc/nginx/sites-enabled/default

    cat >> '/etc/nginx/sites-enabled/default' <<"EOF"
server {
	root ${SERVER_DATA_DIR};

	index index.html index.htm index.nginx-debian.html;
  server_name ${SS_PUBLIC_DNS_NAME};

	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		try_files $uri $uri/ =404;
	}

  listen [::]:443 ssl ipv6only=on;
  listen 443 ssl;
  ssl_certificate ${HTTPS_CERT_FILE};
  ssl_certificate_key ${HTTPS_KEY_FILE};
  include /etc/letsencrypt/options-ssl-nginx.conf;
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}
EOF
  fi

  # Change "worker_processes auto;" in "/etc/nginx/nginx.conf" to $WORKERS. It's not that important and relevant.
  # We're not testing nginx, we just want a baseline, but this gives some sort of equal comparison.
  # (note that nginx is very async, and thus typically doesn't need a lot of workers.)
  echo "Configuring Nginx workers. (Set to ${WORKERS})"
  sed -e "s/worker_processes [a0-9][auto0-9]*;/worker_processes ${WORKERS};/" -i /etc/nginx/nginx.conf
  grep -H worker_processes /etc/nginx/nginx.conf

  if [ "${STORAGE_BACKEND}" == 'file' ] || [ "${STORAGE_BACKEND}" == 'tmpfs' ]
  then
    # if nginx is running, reload would be enough
    echo "Restart nginx to use ${SERVER_DATA_DIR} as root"
    sed -e "s#root /srv/css.*;#root ${SERVER_DATA_DIR};#" -i /etc/nginx/sites-enabled/default
    systemctl restart nginx
  else
    echo "Stopping nginx as STORAGE_BACKEND is not file"
    systemctl stop nginx
    exit 1  # We can't really test this!
  fi

else
  # probably already stopped
  echo "Stopping nginx as it is not needed"
  systemctl stop nginx || true
fi

echo '#########################################################'

if [ "$SERVER_UNDER_TEST" == "css" ]
then
  echo "Starting CSS (with config ${CONFIG_FILE} server_root ${SERVER_DATA_DIR})"
  start_css "${USED_SS_PORT}" "${HTTP_PROTO_PREFIX}"
fi

#########################################################

if [ "$SERVER_UNDER_TEST" == "css" ] && [ "${STORAGE_BACKEND}" == 'memory' ]
then
  # we can only add the users and data now that the actual CSS has started
  echo "Need to generate data for $NICK-${CONTENT_ID} in ${CSS_COMMIT_CLEAN_DATA_DIR}"
  # this uses :3000, but we might not be running on that port. So this will probably fail.
    if [ -e "${CSS_NICKCONT_USER_JSON_FILE}" ]
    then
      rm "${CSS_NICKCONT_USER_JSON_FILE}"
    fi
  generate_css_data "${CSS_COMMIT_CLEAN_DATA_DIR}" "${CSS_NICKCONT_USER_JSON_FILE}"
fi

#########################################################

# Update authentication cache available
if [ "${GENERATE_USERS,,}" == "true" ] && [ "$SERVER_UNDER_TEST" == "css" ]
then
  # BEWARE: running CSS is uses ${SERVER_DATA_DIR} instead of ${CSS_NICKCONT_CLEAN_AUTH_DIR}
  #         so if we update auth-cache, any new tokens get written to the SERVER_DATA_DIR internal storage!
  #         So at the end of this step, we need to copy the internal data...

  # This step is allowed to fail
  set +e

  # make sure authentication cache can be downloaded using nginx
  echo "Update ${CSS_NICKCONT_AUTH_CACHE_FILE}"

  echo "Making sure that auth cache ${CSS_NICKCONT_AUTH_CACHE_FILE} is up to date"
  set -x
  solid-flood --accounts USE_EXISTING --account-source FILE --account-source-file "${CSS_NICKCONT_USER_JSON_FILE}" \
            --duration 1 --parallel 1 \
            --authenticate --authenticateCache all --filename dummy.txt \
            --steps 'loadAC,fillAC,validateAC,saveAC,testRequest' \
            --ensure-auth-expiration 600 \
            --authCacheFile "${CSS_NICKCONT_AUTH_CACHE_FILE}" || touch "${CSS_NICKCONT_CLEAN_AUTH_DIR}/ERROR"
  set +x

  if [ -e "${CSS_NICKCONT_CLEAN_AUTH_DIR}/ERROR" ]
  then
    echo "Error while testing auth cache! Will re-make auth-cache for $NICK-${CONTENT_ID} in ${CSS_NICKCONT_CLEAN_AUTH_DIR}"
    rm -v "${CSS_NICKCONT_AUTH_CACHE_FILE}"

    echo "Collecting access tokens for all users"
    set -x
    solid-flood --accounts USE_EXISTING --account-source FILE --account-source-file "${CSS_NICKCONT_USER_JSON_FILE}" \
              --duration 1 --parallel 1 \
              --authenticate --authenticateCache all --filename dummy.txt \
              --steps 'fillAC,validateAC,saveAC,testRequest' \
              --ensure-auth-expiration 600 \
              --authCacheFile "${CSS_NICKCONT_AUTH_CACHE_FILE}" || touch "${CSS_NICKCONT_CLEAN_AUTH_DIR}/ERROR"
    set +x
  fi


  if [ "${STORAGE_BACKEND}" == 'file' ] || [ "${STORAGE_BACKEND}" == 'tmpfs' ]
  then
      # Make sure our clean version with auth has this new auth info.
      # This is still clean, as we just created the "unclean" version from the clean version.
      rm -r "${CSS_NICKCONT_CLEAN_AUTH_DIR}/.internal"
      cp -a "${SERVER_DATA_DIR}/.internal" "${CSS_NICKCONT_CLEAN_AUTH_DIR}/"
  fi

  set -e
fi

if [ "${GENERATE_USERS,,}" == "true" ] && [ "$SERVER_UNDER_TEST" == "css" ]
then
  # Make the auth cache available
  cp -v "${CSS_NICKCONT_AUTH_CACHE_FILE}" '/usr/local/share/active_test_config/auth-cache.json'
  #Make the account info available
  cp -v "${CSS_NICKCONT_USER_JSON_FILE}" '/usr/local/share/active_test_config/accounts.json'
else
  echo '{}' > '/usr/local/share/active_test_config/auth-cache.json'
  echo '{}' > '/usr/local/share/active_test_config/accounts.json'
fi

#########################################################

echo '**************************************************************************'
echo "* $SERVER_UNDER_TEST is configured and running for your Experiment "
echo "* at ${GLOBAL_BASE_URL} "
echo "* "
echo "* Downloads to get started with the test server: "
echo "*   - http://${SS_PUBLIC_DNS_NAME}:8888/accounts.json "
echo "*   - http://${SS_PUBLIC_DNS_NAME}:8888/auth-cache.json "
echo '**************************************************************************'

echo "${GLOBAL_BASE_URL}" > "${share_dir}ss_url"

exit 0
