#!/bin/bash

AWSRegion=${1}

echo "TEAR DOWN START."

export KOPS_STATE_STORE=`cat /opt/kops-state/KOPS_STATE_STORE`
export KOPS_CLUSTER_NAME=`cat /opt/kops-state/KOPS_CLUSTER_NAME`
export AWS_DEFAULT_REGION=${AWSRegion}

kops export kubecfg --name $KOPS_CLUSTER_NAME

#delete ingresses
for i in `kubectl get ingress -o yaml | grep "name:" | grep -v hostname | awk '{print $2}'`; 
do 
  echo "Delete ingress: $i..."; 
  kubectl delete ingress $i --force;
done

#delete cluster
kops delete cluster --name $KOPS_CLUSTER_NAME --yes >> /tmp/init-kops.log 2>&1

#delete local r53 dns zone
if [[ -e "/opt/kops-state/KOPS_R53_PRIVATE_HOSTED_ZONE_ID" ]];
then
  R53ZID=`cat /opt/kops-state/KOPS_R53_PRIVATE_HOSTED_ZONE_ID`
  if [[ -n ${R53ZID} ]];
  then
    aws route53 delete-hosted-zone --id ${R53ZID} --region ${AWSRegion}
  else
    echo "Missing R53 Zone ID!"
  fi
fi

#delete kops state bucket
S3BUCKET=`cat /opt/kops-state/KOPS_STATE_STORE | cut -d '/' -f 3`
python purge-s3-versioned-bucket.py ${S3BUCKET} ${AWSRegion}

#delete log group
LOG2=`cat /opt/kops-state/KOPS_AWSLOGS`
if [[ -n ${LOG2} ]];
then
  aws logs delete-log-group --log-group-name ${LOG2} --region ${AWSRegion}
fi

echo "TEAR DOWN DONE. EXIT 0"
exit 0
