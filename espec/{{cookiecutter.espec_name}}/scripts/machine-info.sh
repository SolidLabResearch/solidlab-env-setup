#!/bin/bash -e

PREFIX='\n\n========================== '
SUFFIX=' =========================='
INFO_FILE="/tmp/machineinfo-$(hostname | sed -e 's/[^a-zA-Z0-9].*$//').txt"

set +e  # not critical if any of the following fails

# log some info about this machine
set -v

echo "Info about this machine" > "${INFO_FILE}"

echo -e "${PREFIX}hostname${SUFFIX}" | tee -a "${INFO_FILE}"
hostname | tee -a "${INFO_FILE}"

echo -e "${PREFIX}lscpu${SUFFIX}" | tee -a "${INFO_FILE}"
lscpu | tee -a "${INFO_FILE}"

echo -e "${PREFIX}lsmem${SUFFIX}" | tee -a "${INFO_FILE}"
lsmem | tee -a "${INFO_FILE}"

echo -e "${PREFIX}lsblk${SUFFIX}" | tee -a "${INFO_FILE}"
lsblk | tee -a "${INFO_FILE}"

echo -e "${PREFIX}uname -a${SUFFIX}" | tee -a "${INFO_FILE}"
uname -a | tee -a "${INFO_FILE}"

echo -e "${PREFIX}lsb_release -a${SUFFIX}" | tee -a "${INFO_FILE}"
lsb_release -a | tee -a "${INFO_FILE}"

echo -e "${PREFIX}uptime${SUFFIX}" | tee -a "${INFO_FILE}"
uptime | tee -a "${INFO_FILE}"

echo -e "${PREFIX}python2 '$(which geni-get)' -a${SUFFIX}" | tee -a "${INFO_FILE}"
python2 "$(which geni-get)" -a | tee -a "${INFO_FILE}"

set +v

{% if 'perftest_artifact_endpoint' in cookiecutter %}
solidlab-perftest-upload "{{cookiecutter.perftest_artifact_endpoint}}" "${INFO_FILE}" \
          --type OTHER --sub-type 'Machine Info' --description 'Machine Info' \
          --auth-token "{{cookiecutter.agent_auth_token}}"
{% endif %}
