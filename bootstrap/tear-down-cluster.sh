#!/bin/bash

AWSRegion=${1}

echo "TEAR DOWN START."

export KOPS_STATE_STORE=`cat /opt/kops-state/KOPS_STATE_STORE`
export KOPS_CLUSTER_NAME=`cat /opt/kops-state/KOPS_CLUSTER_NAME`
export AWS_DEFAULT_REGION=${AWSRegion}

kops export kubecfg --name $KOPS_CLUSTER_NAME
kops delete cluster --name $KOPS_CLUSTER_NAME --yes >> /tmp/init-kops.log 2>&1

if [[ -e "/opt/kops-state/KOPS_R53_PRIVATE_HOSTED_ZONE" ]];
then
  R53ZID=`cat /opt/kops-state/KOPS_R53_PRIVATE_HOSTED_ZONE`
  if [[ -n ${R53ZID} ]];
  then
    aws route53 delete-hosted-zone --id ${R53ZID} --region ${AWSRegion}
  else
    echo "Missing R53 Zone ID!"
  fi
fi

S3BUCKET=`cat /opt/kops-state/KOPS_STATE_STORE | cut -d '/' -f 3`
python purge-s3-versioned-bucket.py ${S3BUCKET} ${AWSRegion}

LOG2=`cat /opt/kops-state/KOPS_AWSLOGS`
aws logs delete-log-group --log-group-name ${LOG2} --region ${AWSRegion}

echo "TEAR DOWN DONE. EXIT 0"
exit 0
