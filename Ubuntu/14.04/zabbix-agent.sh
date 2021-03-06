#!/bin/bash

# check required commands
DEPENDS=( lsb_release )
for cmd in ${DEPENDS[@]}; do
    which $cmd >/dev/null 2>&1
    if [ $? -ne 0 ]; then
	echo "ERROR: '$cmd' command not found."
	exit 1
    fi
done

DIST_ID=`lsb_release -is`

if [ "$DIST_ID" != "Ubuntu" ]; then
    echo "ERROR: This script is written for Ubuntu."
    exit 1
fi

DIST_VERSION=`lsb_release -rs`
DIST_ARCH=`arch`

# install zabbix agent
if [ -z "`dpkg -l | grep zabbix-agent`" ]; then
    echo "* Installing Zabbix Agent ..."
    apt-get install zabbix-agent
fi

# update config files
echo "* Updating config files ..."
DEFAULT_GATEWAY_IP=`ip r | grep default | awk '{print $3}'`

sed -i s/Server=127.0.0.1/Server=$DEFAULT_GATEWAY_IP/g /etc/zabbix/zabbix_agentd.conf

# update iptables
echo "* Updating firewall ..."
ufw allow 10050

# start zabbix agent
echo "* Starting zabbix-agent ..."
service zabbix-agent restart
echo "done."

# ask user to register myself to zabbix server
DEFAULT_NETWORK_PORT_NAME=`ip r | grep default | grep -Eo 'dev .[^ ]*' | awk '{print $2}'`
MY_IP_ADDRESS=`ip -4 -o a show dev $DEFAULT_NETWORK_PORT_NAME | awk '{print $4}' | awk -F '/' '{print $1}'`
echo
echo "Please add $MY_IP_ADDRESS to the Zabbix Server."

