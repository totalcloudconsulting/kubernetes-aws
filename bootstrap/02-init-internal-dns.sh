#!/bin/bash

AWSRegion=${1}
VPC=${2}
KubernetesAPIPublicAccess=${3}
AWSCfnStackName=${4}


echo "#################"
echo "START INIT-INTERNAL-DNS..."

randomsuff=`cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8`
stacklower=`echo "${AWSCfnStackName}" | tr '[:upper:]' '[:lower:]'`

if [[ "${KubernetesAPIPublicAccess}" == "false" ]];
then
  K8sRoute53ZoneName="k8s-${randomsuff}.internal"
  echo "K8s Internal DNS Zone name is: ${K8sRoute53ZoneName}"
  echo ${K8sRoute53ZoneName} > /opt/kops-state/KOPS_VPC_R53_ZONE_DNS

  aws route53 create-hosted-zone --name ${K8sRoute53ZoneName} --vpc VPCRegion=${AWSRegion},VPCId=${VPC} --hosted-zone-config Comment="K8sPrivateZone",PrivateZone=true --region ${AWSRegion} --caller-reference "`date`" --output text | grep "hostedzone/" | grep "https://route53.amazonaws.com" | cut -d '/' -f 6 > /opt/kops-state/KOPS_R53_PRIVATE_HOSTED_ZONE_ID
fi

echo "DONE START INIT-INTERNAL-DNS."
echo "#################"
exit 0
