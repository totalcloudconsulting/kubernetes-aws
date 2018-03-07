#!/bin/bash

echo "#################"
echo "INIT-BASTION-HOST START..."

S3BootstrapBucketName=${1}
S3BootstrapBucketPrefix=${2}
AWSRegion=${3}
VPCIPv4CIDRBlock=${4}

#install modified AWS Bastion bootstrap
export BASTION_BOOTSTRAP_FILE=bastion-bootstrap.sh

cp banner_message.txt /etc/ssh_banner

iptables -t nat -A POSTROUTING -s ${VPCIPv4CIDRBlock}/16 -o eth0 -j MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward

sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward = 1' | tee --append /etc/sysctl.conf

echo '#!/bin/sh -e' | tee /etc/rc.local
echo '' | tee --append /etc/rc.local
echo "iptables -t nat -A POSTROUTING -s ${VPCIPv4CIDRBlock}/16 -o eth0 -j MASQUERADE" | tee --append /etc/rc.local
echo 'exit 0' | tee --append /etc/rc.local

chmod +x $BASTION_BOOTSTRAP_FILE
./$BASTION_BOOTSTRAP_FILE --banner banner_message.txt --enable true > ./bastion-bootstrap.log 2>&1 || exit 0

sleep 5


echo "INIT-BASTION-HOST DONE."
echo "#################"
exit 0
