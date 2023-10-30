#!/bin/bash -e

# Generate content for the solid server
# This script should be sourced by setup_kss.sh and setup_css.sh


function make_content_id() {
  if [ "${GENERATE_CONTENT,,}" == "true" ]
  then
    # Make a unique name ("CONTENT_ID") based on requested server data content
    # Variables:
    #    ${CONTENT_USER_COUNT}
    #    ${CONTENT_FIXED_SIZE_FILECOUNT}
    #    ${CONTENT_FILES_FOR_GET}
    #    ${CONTENT_FILES_RDF}
    #    ${CONTENT_FILES_RDF_SIZE} / ${CONTENT_FILES_RDF_SIZE_NICK}
    #    ${AUTHORIZATION}  # content dir differs for authentication methods
    #    ${GENERATED_FILES_NEST_DEPTH}
    CONTENT_ID="cnt-${CONTENT_USER_COUNT}u-${CONTENT_FIXED_SIZE_FILECOUNT}fs-${AUTHORIZATION}"
    if [ "${CONTENT_FILES_FOR_GET,,}" == 'true' ]
    then
      CONTENT_ID="${CONTENT_ID}-get"
    fi
    if [ "${GENERATED_FILES_NEST_DEPTH}" != '0' ]
    then
      CONTENT_ID="${CONTENT_ID}-d${GENERATED_FILES_NEST_DEPTH}"
    fi
    if [ "${GENERATED_FILES_ADD_AC_PER_RESOURCE}" == 'false' ]
    then
      CONTENT_ID="${CONTENT_ID}-noresac"
    fi
    if [ "${GENERATED_FILES_ADD_AC_PER_DIR}" == 'false' ]
    then
      CONTENT_ID="${CONTENT_ID}-nodirac"
    fi
    if [ "${CONTENT_FILES_RDF,,}" == 'true' ]
    then
      CONTENT_ID="${CONTENT_ID}-rdf${CONTENT_FILES_RDF_SIZE_NICK}"
    fi
    echo "    CONTENT_ID=${CONTENT_ID}"
  else
    if [ "${GENERATE_USERS,,}" == "true" ]
    then
      CONTENT_ID="cnt-${CONTENT_USER_COUNT}u-empty"
    else
      CONTENT_ID="cnt-empty"
    fi

    # Random content ID: new empty content dir every time
  #  CONTENT_ID="empty-$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 10)"
  fi
}

##################################################################################################################
##################################################################################################################

function generate_ss_data() {
  # Generate data into a target SS server data dir

  # Parameters:
  #   $1 = target SS data dir
  #   $2 = port the SS is listening on
  local _SS_DATA_DIR="$1"
  local _SS_PORT="$2"
  local _SS_PROTO="$3"
  local _USERS_JSON_FILE="$4"

  if [ -z "${_SS_DATA_DIR}" ]
  then
     echo 'generate_ss_data requires data dir as first argument'
     exit 1
  fi

  if [ -z "${_SS_PORT}" ]
  then
     echo 'generate_ss_data requires port as second argument'
     exit 1
  fi

  if [ -z "${_SS_PROTO}" ]
  then
     echo 'generate_ss_data requires proto (http or https) as third argument'
     exit 1
  fi

  if [ ! -d "${_SS_DATA_DIR}" ]
  then
     echo "generate_ss_data got non existing data dir as first argument: '${_SS_DATA_DIR}'"
     exit 1
  fi

  #
  # Input env vars:
  #   $SS_PUBLIC_DNS_NAME
  #   $data_dir
  #   $USERS_JSON  where to store the users.json file containing the generated users (or existing users)
  #
  #   #for content generation config:
  #   ${CONTENT_USER_COUNT}
  #   ${CONTENT_FIXED_SIZE_FILECOUNT}
  #   ${CONTENT_FILES_FOR_GET}
  #   ${CONTENT_FILES_RDF}

  echo "generating data for SS commit $NICK"

  if [ "${GENERATE_CONTENT,,}" != "true" ] && [ "${GENERATE_USERS,,}" != "true" ]
  then
    # Nothing to do
    return 0;
  fi

  if [ -z "${CONTENT_USER_COUNT}" ]
  then
     echo 'CONTENT_USER_COUNT is required'
     exit 1
  fi

  CONTENT_VAR_SIZE_ARG=''
  if [ "${GENERATE_CONTENT,,}" == "true" ] && [ "${CONTENT_FILES_FOR_GET,,}" == 'true' ]
  then
     CONTENT_VAR_SIZE_ARG='--generate-variable-size'
  fi
  CONTENT_FIXED_SIZE_ARG=''
  if [ "${GENERATE_CONTENT,,}" == "true" ] && [ "${CONTENT_FIXED_SIZE_FILECOUNT}" -gt 0 ]
  then
     CONTENT_FIXED_SIZE_ARG="--generate-fixed-size --file-size 10 --file-count $((CONTENT_FIXED_SIZE_FILECOUNT))"
  fi
  CONTENT_RDF_ARG=''
  if [ "${GENERATE_CONTENT,,}" == "true" ] && [ "${CONTENT_FILES_RDF,,}" == 'true' ]
  then
     if [ ! -e "${data_dir}/infobox-properties_lang=nl__head75000_10MB.nt" ]
     then
        echo 'Missing required RDF base file "'"${data_dir}/infobox-properties_lang=nl__head75000_10MB.nt"'"'
        exit 1
     fi
     if [ ! -e "${data_dir}/infobox-properties_lang=nl__head7500_1MB.nt" ]
     then
        echo 'Missing required RDF base file "'"${data_dir}/infobox-properties_lang=nl__head7500_1MB.nt"'"'
        exit 1
     fi
     if [ ! -e "${data_dir}/infobox-properties_lang=nl__head750_100kB.nt" ]
     then
        echo 'Missing required RDF base file "'"${data_dir}/infobox-properties_lang=nl__head750_100kB.nt"'"'
        exit 1
     fi
     if [ "${CONTENT_FILES_RDF_SIZE}" == '100000' ]
     then
        CONTENT_RDF_ARG='--generate-rdf --base-rdf-file '"${data_dir}/infobox-properties_lang=nl__head750_100kB.nt"
     elif [ "${CONTENT_FILES_RDF_SIZE}" == '1000000' ]
     then
        CONTENT_RDF_ARG='--generate-rdf --base-rdf-file '"${data_dir}/infobox-properties_lang=nl__head7500_1MB.nt"
     elif [ "${CONTENT_FILES_RDF_SIZE}" == '10000000' ]
     then
        CONTENT_RDF_ARG='--generate-rdf --base-rdf-file '"${data_dir}/infobox-properties_lang=nl__head75000_10MB.nt"
     else
        echo "RDF file size ${CONTENT_FILES_RDF_SIZE} (${CONTENT_FILES_RDF_SIZE_NICK}) not supported"
        exit 1
     fi
  fi

  AUTHORIZATION_ARG=''
#  AUTHORIZATION_ARG='--add-acl-files'
  if [ "${AUTHORIZATION}" == 'webacl' ] || [ "${AUTHORIZATION}" == 'wac' ]
  then
    AUTHORIZATION_ARG='--add-acl-files'
  fi
  if [ "${AUTHORIZATION}" == 'acp' ]
  then
    AUTHORIZATION_ARG='--add-acr-files'
  fi
  if [ "${GENERATED_FILES_ADD_AC_PER_RESOURCE}" == 'false' ]
  then
    AUTHORIZATION_ARG="${AUTHORIZATION_ARG} --no-add-ac-file-per-resource"
  fi
  if [ "${GENERATED_FILES_ADD_AC_PER_DIR}" == 'false' ]
  then
    AUTHORIZATION_ARG="${AUTHORIZATION_ARG} --no-add-ac-file-per-dir"
  fi

  ACCOUNT_ARGS=""
  if [ "${GENERATE_USERS,,}" == "true" ]
  then
    ACCOUNT_ARGS="--accounts CREATE"
  else
    ACCOUNT_ARGS="--accounts USE_EXISTING"
  fi

  if [ -z "${_USERS_JSON_FILE}" ]
  then
    ACCOUNT_ARGS="${ACCOUNT_ARGS} --account-source TEMPLATE --account-source-count ${CONTENT_USER_COUNT}"
  else
    ACCOUNT_ARGS="${ACCOUNT_ARGS} --account-source FILE --account-source-file ${_USERS_JSON_FILE}"
  fi

  set -x
  css-populate --url "${_SS_PROTO}://${SS_PUBLIC_DNS_NAME}:${_SS_PORT}" \
      ${ACCOUNT_ARGS} \
      ${AUTHORIZATION_ARG} \
      --dir-depth "${GENERATED_FILES_NEST_DEPTH}" \
      ${CONTENT_VAR_SIZE_ARG} \
      ${CONTENT_FIXED_SIZE_ARG} \
      ${CONTENT_RDF_ARG} \
      --user-json-out "${USERS_JSON}" \
       || touch "${_SS_DATA_DIR}/ERROR"
  set +x

  if [ "${STORAGE_BACKEND}" == 'file' ] || [ "${STORAGE_BACKEND}" == 'tmpfs' ]
  then
    if [ -e "${_SS_DATA_DIR}/ERROR" ]
    then
      echo "Failed to generating data for SS commit $NICK"
      exit 1
    fi

    sleep 1
  fi

  return 0;
}

##################################################################################################################
##################################################################################################################
