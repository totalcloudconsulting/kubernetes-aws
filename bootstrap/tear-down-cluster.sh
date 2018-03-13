#!/bin/bash

AWSRegion=${1}

echo "TEAR DOWN START..."

export KOPS_STATE_STORE=`cat /opt/kops-state/KOPS_STATE_STORE`
export KOPS_CLUSTER_NAME=`cat /opt/kops-state/KOPS_CLUSTER_NAME`
export AWS_DEFAULT_REGION=${AWSRegion}

VPC=`cat /opt/kops-state/KOPS_VPC`

kops export kubecfg --name $KOPS_CLUSTER_NAME

echo "Delete k8s ingresses ... "
ingress=""
#delete ingresses
for i in `kubectl get ingress -o yaml | grep "name:" | grep -v hostname | awk '{print $2}'`; 
do 
  echo "Delete ingress: $i..."; 
  kubectl delete ingress $i --force;
  ingress="YES"
  sleep 10
  
  for j in `aws elbv2 describe-target-groups --region ${AWSRegion} --output text | grep arn | grep TARGETGROUPS | awk '{print $10}'`; 
  do
    echo "Target group: $j ..."; 
    for h in {0..20};
    do
      N=`aws elbv2 describe-tags --resource-arns $j --region ${AWSRegion} --output text | grep $i`; 
      if [[ -n "${N}" ]];
      then
        echo "DELETE TARGET GROUP: ${j} ...";
        H=`aws elbv2 delete-target-group --target-group-arn $j --region ${AWSRegion}`
        if [[ ! -n $H ]]; 
        then 
          echo "Target group deleted.";
          break
        else
          echo "Waiting to delete target group ${H} ..."
          sleep 5
          continue
        fi
      else
        break;
      fi
    done
  done
done

#wait for target group deletion, it is async wait to remove ALB target groups
echo "Wait a bit ... "
if [[ "${ingress}" == "YES" ]];
then
  sleep 20
fi

#delete cluster
echo "Delete cluster ... "
kops delete cluster --name $KOPS_CLUSTER_NAME --yes

#purge remaining alb SGs
if [[ -n "${VPC}" ]];
then
  echo "Remove ALB SGs from VPC: ${VPC} ..."
  for sg in `aws ec2 describe-security-groups --filters Name=vpc-id,Values=${VPC} Name=tag-key,Values=ManagedBy Name=tag-value,Values=alb-ingress --output text --region ${AWSRegion} | grep SECURITYGROUPS | awk '{print $3}'`; 
  do 
    echo "Delete SG: $sg "; 
    aws ec2 delete-security-group --group-id $sg --region ${AWSRegion}; 
  done
else
  echo "NO VPC!"
fi

#delete local r53 dns zone
echo "Delete R53 ZONE ... "
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
echo "Delete kops S3 state bucket ... "
S3BUCKET=`cat /opt/kops-state/KOPS_STATE_STORE | cut -d '/' -f 3`
python purge-s3-versioned-bucket.py ${S3BUCKET} ${AWSRegion}

#delete log group
echo "Delete AWS logs group ... "
LOG2=`cat /opt/kops-state/KOPS_AWSLOGS`
if [[ -n ${LOG2} ]];
then
  aws logs delete-log-group --log-group-name ${LOG2} --region ${AWSRegion}
fi

echo "TEAR DOWN DONE. EXIT 0"
exit 0
