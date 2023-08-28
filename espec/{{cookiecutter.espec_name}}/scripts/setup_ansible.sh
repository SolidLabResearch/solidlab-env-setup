#!/bin/bash -e
DEBIAN_FRONTEND=noninteractive sudo apt-get update
DEBIAN_FRONTEND=noninteractive sudo apt-get install --no-install-recommends -y -f ansible
