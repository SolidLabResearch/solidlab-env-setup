#!/bin/bash -e

base_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if ! grep -q 'Ubuntu 20.04 LTS' /etc/issue
then
   echo "Not Ubuntu 20.04 but $(cat /etc/issue): Nothing to do"
   exit 0
fi

if ip addr show | grep -q '192.168.0.1'
then
   echo "Not Ubuntu 20.04 but $(cat /etc/issue): Nothing to do"
   exit 0
fi

# The problem with UBU 20.04 image on the wall is that it doesn't set IPs on experiment interfaces

if [ "$(find /var/lib/apt/lists -cmin -60 -type f | wc -l)" -gt 0 ]
then
  DEBIAN_FRONTEND=noninteractive sudo apt-get update
fi
DEBIAN_FRONTEND=noninteractive apt-get install -y -f python2 python-is-python2

echo 'Ubuntu 20.04 wall images do not set experiment interface IPs. IPs are now:'
ip addr show

wget https://gitlab.ilabt.imec.be/wvdemeer/wall-public-scripts/-/raw/master/geni-get-info.py?inline=false -O "${base_dir}/geni-get-info.py"
chmod u+x "${base_dir}/geni-get-info.py"
echo 'Will correct experiment interface IPs by executing:'
"${base_dir}/geni-get-info.py" expip | tee "${base_dir}/config_exp_ip.sh"

echo
echo 'Executing...'
chmod u+x "${base_dir}/config_exp_ip.sh"
"${base_dir}/config_exp_ip.sh"

echo
echo 'Done. IPs are now:'
ip addr show
