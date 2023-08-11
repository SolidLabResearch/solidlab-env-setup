#!/bin/bash -e

# Some bootstrapping that is too good not to do. Even if ansible will do it later anyway.

if [ ! -e /etc/apt/preferences.d/no-network-manager ]
then
  # first of all, prevent network-manager install. It can be a dep of some packages. And it messes up IPv6 addresses. Avoid it on servers if possible.
  echo -e -n '\n\nPackage: network-manager\nPin: release *\nPin-Priority: -1\n\n' > /etc/apt/preferences.d/no-network-manager
fi

# prevent systemd from filling /var/log/syslog
if ! grep -q 'ForwardToSyslog=no' /etc/systemd/journald.conf
then
  echo 'ForwardToSyslog=no' >> /etc/systemd/journald.conf
  systemctl restart systemd-journald
fi

# support kitty terminal
if [ ! -e /usr/share/terminfo/x/xterm-kitty ]
then
  curl -L https://github.com/kovidgoyal/kitty/raw/master/terminfo/x/xterm-kitty > /usr/share/terminfo/x/xterm-kitty
  chmod uog+r /usr/share/terminfo/x/xterm-kitty
fi

# leave this to ansible
#DEBIAN_FRONTEND=noninteractive apt-get update
#DEBIAN_FRONTEND=noninteractive apt-get install -y -f --no-install-recommends apt-transport-https ca-certificates curl software-properties-common openssl wget gnupg tmux vim build-essential ncdu lsb-release jq
