#!/bin/bash

echo "#################"
echo "INIT-OPENVPN START..."

VPCIPv4CIDRBlock=${1}
VPNCACountryISOCode=${2}
VPNCAProvince=${3}
VPNCACity=${4}
VPNCAOrganization=${5}
VPNCAOrgEmail=${6}
VPNCAOrgUnit=${7}
VPNNumberOfPreGeneratedCerts=${8}
K8sClusterName=${9}

mv /opt/easy-openvpn/keygen /etc/openvpn/
cd /etc/openvpn/keygen
chmod +x /etc/openvpn/keygen/*

R53PrivateDNSZoneName=""
if [[ -e "/opt/kops-state/KOPS_VPC_R53_ZONE_DNS" ]];
then
    R53PrivateDNSZoneName=`cat /opt/kops-state/KOPS_VPC_R53_ZONE_DNS`
fi

export openvpnvars="/etc/openvpn/keygen/vars"

ip=`curl http://169.254.169.254/latest/meta-data/public-ipv4`
awsdns=$(echo $VPCIPv4CIDRBlock | tr "." " " | awk '{ print $1"."$2"."$3".2" }')

echo ${ip}
echo ${awsdns}

sed -i 's/CHANGE_SERVER_IP/'${ip}'/g' ${openvpnvars}
sed -i 's/CC/'${VPNCACountryISOCode}'/g' ${openvpnvars}
sed -i 's/CHANGE_PROVINCE/'${VPNCAProvince}'/g' ${openvpnvars}
sed -i 's/CHANGE_CITY/'${VPNCACity}'/g' ${openvpnvars}
sed -i 's/CHANGE_ORG/'${VPNCAOrganization}'/g' ${openvpnvars}
sed -i 's/CHANGE_ORG_EMAIL/'${VPNCAOrgEmail}'/g' ${openvpnvars}
sed -i 's/CHANGE_OU/'${VPNCAOrgUnit}'/g' ${openvpnvars}

echo "push \"route $VPCIPv4CIDRBlock 255.255.0.0\"" | tee --append server-template.conf
echo "push \"register-dns\"" | tee --append server-template.conf

if [[ -n ${R53PrivateDNSZoneName} ]];
then
    echo "push \"dhcp-option DNS __REPLACE_AWS_DNS__\"" | tee --append server-template.conf
    echo "push \"dhcp-option DOMAIN $R53PrivateDNSZoneName\"" | tee --append server-template.conf
    sed -i 's/__REPLACE_AWS_DNS__/'${awsdns}'/g' server-template.conf
fi

./create-server
service openvpn@server start
systemctl enable openvpn@server

#set options in client file for tunnelblick
echo "dhcp-option DNS ${awsdns}" | tee --append client-template-embed.ovpn
echo "dhcp-option DOMAIN $R53PrivateDNSZoneName" | tee --append client-template-embed.ovpn

i=1
while [[ "$i" -le "${VPNNumberOfPreGeneratedCerts}" ]];
do 
    ./build-key-embed "K8s.OVPNkey.${K8sClusterName}.${i}.org"; 
    cp /etc/openvpn/keys/K8s.OVPNkey.${K8sClusterName}.${i}.org/K8s.OVPNkey.${K8sClusterName}.${i}.org.ovpn /opt/openvpn-keys/; 
    i=$((i + 1))
done

chown ubuntu:ubuntu /opt/openvpn-keys/*

echo "INIT-OPENVPN DONE."
echo "#################"

exit 0

