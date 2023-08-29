#!/bin/bash -xe
DEBIAN_FRONTEND=noninteractive sudo apt-get update

# Too old
#DEBIAN_FRONTEND=noninteractive sudo apt-get install --no-install-recommends -y -f ansible

# Use python to install ansible. So first setup required python stuff.
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y -f python3 python3-pip python3-venv

# Create a venv for ansible
if [ ! -e ~/ansible/venv ]
then
  python3 -m venv ~/ansible/venv
  ~/ansible/venv/bin/pip install ansible
  echo 'installed ansible executables:'
  ls ~/ansible/venv/bin
fi

if [ ! -e /usr/local/bin/ansible-playbook ]
then
  cd ~/ansible/venv/bin
  for ansible_exe in ansible*
  do
    sudo ln -s ~/ansible/venv/bin/"${ansible_exe}" /usr/local/bin/
  done
fi
