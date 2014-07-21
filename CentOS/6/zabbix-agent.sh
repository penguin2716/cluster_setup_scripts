#!/bin/bash

# check required commands
DEPENDS=( lsb_release wget arch )
for cmd in ${DEPENDS[@]}; do
    which $cmd >/dev/null 2>&1
    if [ $? -ne 0 ]; then
	echo "ERROR: '$cmd' command not found."
	exit 1
    fi
done

DIST_ID=`lsb_release -is`

if [ "$DIST_ID" != "CentOS" ]; then
    echo "ERROR: This script is written for CentOS."
    exit 1
fi

DIST_VERSION=`lsb_release -rs`
DIST_MAJOR_VERSION=`echo $DIST_VERSION | awk -F '.' '{print $1}'`
DIST_MINOR_VERSION=`echo $DIST_VERSION | awk -F '.' '{print $2}'`
DIST_ARCH=`arch`

# disable SELinux
if [ "`getenforce`" = "Enforcing" ]; then
    echo "* Disabling SELinux ..."
    setenforce 0
    sed -i s/SELINUX=enforcing/SELINUX=disabled/g /etc/selinux/config
fi

# setup epel repository
if [ ! -e /etc/yum.repos.d/epel.repo ]; then
    echo "* Registering EPEL reposigory ..."
    PACKAGE_BASE_URL=http://ftp-srv2.kddilabs.jp/Linux/distributions/fedora/epel/$DIST_MAJOR_VERSION/$DIST_ARCH
    PACKAGE_NAME=`curl $PACKAGE_BASE_URL/ 2>/dev/null | grep epel-release | grep -Eo 'href=".*"' | awk -F '"' '{print $2}'`
    
    wget $PACKAGE_BASE_URL/$PACKAGE_NAME
    rpm -ivh $PACKAGE_NAME
    sed -i s/enabled=1/enabled=0/g /etc/yum.repos.d/epel*
fi

# install zabbix agent
if [ -z "`rpm -qa | grep zabbix-agent`" ]; then
    echo "* Installing Zabbix Agent ..."
    yum install -y zabbix-agent --enablerepo=epel
fi

# update config files
echo "* Updating config files ..."
DEFAULT_GATEWAY_IP=`ip r | grep default | awk '{print $3}'`

sed -i s/Server=127.0.0.1/Server=$DEFAULT_GATEWAY_IP/g /etc/zabbix/zabbix_agent.conf
sed -i s/Server=127.0.0.1/Server=$DEFAULT_GATEWAY_IP/g /etc/zabbix/zabbix_agentd.conf

# update iptables
if [ -z "`iptables-save | grep 10050`" ]; then
    echo "* Updating iptables ..."
    iptables -I INPUT -p tcp --dport 10050 -s $DEFAULT_GATEWAY_IP -j ACCEPT
    iptables-save > /etc/sysconfig/iptables
fi

# start zabbix agent
echo "* Starting zabbix-agent ..."
/etc/init.d/zabbix-agent start
chkconfig zabbix-agent on
echo "done."

# ask user to register myself to zabbix server
DEFAULT_NETWORK_PORT_NAME=`ip r | grep default | grep -Eo 'dev .[^ ]*' | awk '{print $2}'`
MY_IP_ADDRESS=`ip -4 -o a show dev $DEFAULT_NETWORK_PORT_NAME | awk '{print $4}' | awk -F '/' '{print $1}'`
echo
echo "Please add $MY_IP_ADDRESS to the Zabbix Server."

