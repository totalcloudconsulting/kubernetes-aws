#!/bin/bash

AWSRegion=${1}
AWSCfnStackName=${2}
Ec2K8sMasterInstanceType=${3}
Ec2K8sNodeInstanceType=${4}
Ec2K8sNodeCapacityMin=${5}
Ec2K8sNodeCapacityMax=${6}
Ec2EBSK8sDiskSizeGb=${7}
Ec2K8sAMIOsType=${8}
Ec2K8sMultiAZMaster=${9}
VPC=${10}
NetworkCIDR=${11}
PrivateSubnet1=${12}
PrivateSubnet2=${13}
PrivateSubnet3=${14}
PublicSubnet1=${15}
PublicSubnet2=${16}
PublicSubnet3=${17}
K8sMasterAndNodeSecurityGroup=${18}
S3BootstrapBucketName=${18}
S3BootstrapBucketPrefix=${20}
KubernetesDashboard=${21}
KubernetesALBIngressController=${22}
KubernetesClusterAutoscaler=${23}
KubernetesAPIPublicAccess=${24}
KubernetesExternalDNSPlugin=${25}
KubernetesExternalDNSName=${26}
KubernetesExternalDNSTXTSelector=${27}
KOPSReleaseVersion=${28}
KUBECTLReleaseVersion=${29}
HELMReleaseVersion=${30}
FORCED_AMI_ID=${31}
NODES_SPOT_PRICE="0.0"

echo "#################"
echo "START INIT-KOPS."

AWSCfnStackName=`echo "${AWSCfnStackName}" | tr '[:upper:]' '[:lower:]'`
randomstuff=`cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8`


#sync kops, k8s binaries
aws s3 sync s3://${S3BootstrapBucketName}/${S3BootstrapBucketPrefix}/bin/ /usr/local/bin/ --region ${AWSRegion} --quiet

if [[ ! -e /usr/local/bin/kops ]]; 
then 
  echo "Download latest KOPS...";
  wget -O kops https://github.com/kubernetes/kops/releases/download/${KOPSReleaseVersion}/kops-linux-amd64 --no-verbose
  sudo mv ./kops /usr/local/bin/
fi

if [[ ! -e /usr/local/bin/kubectl ]]; 
then 
  echo "Download latest KUBECTL...";
  wget -O kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBECTLReleaseVersion}/bin/linux/amd64/kubectl --no-verbose
  mv ./kubectl /usr/local/bin/kubectl
fi

if [[ ! -e /usr/local/bin/helm ]]; 
then 
  echo "Download latest HELM...";
  wget -O helm.tar.gz https://storage.googleapis.com/kubernetes-helm/helm-v${HELMReleaseVersion}-linux-amd64.tar.gz --no-verbose
  tar -xf helm.tar.gz
  mv ./linux-amd64/helm /usr/local/bin/helm
fi

chmod +x /usr/local/bin/*


#get zones
subnetzone1=`aws ec2 describe-subnets --subnet-ids ${PrivateSubnet1} --output text --region ${AWSRegion} | grep 'SUBNETS' | awk '{print $3}'`
echo "Zone1: ${subnetzone1}"

subnetzone2=`aws ec2 describe-subnets --subnet-ids ${PrivateSubnet2} --output text --region ${AWSRegion} | grep 'SUBNETS' | awk '{print $3}'`
echo "Zone2: ${subnetzone2}"

#master_zones
master_zones="--master-zones=${subnetzone1},${subnetzone2}"

#node zones
node_zones="--zones=${subnetzone1},${subnetzone2}"

if [[ -n ${PrivateSubnet3} ]];
then
  subnetzone3=`aws ec2 describe-subnets --subnet-ids ${PrivateSubnet3} --output text --region ${AWSRegion} | grep 'SUBNETS' | awk '{print $3}'`
  if [[ -n ${subnetzone3} ]];
  then
    echo "Zone3: ${subnetzone3}"
    master_zones="--master-zones=${subnetzone1},${subnetzone2},${subnetzone3}"
    node_zones="--zones=${subnetzone1},${subnetzone2},${subnetzone3}"
  fi
fi

K8sRoute53ZoneName="${AWSCfnStackName}.k8s.local"
K8sClusterName=${K8sRoute53ZoneName}
if [[ -e "/opt/kops-state/KOPS_VPC_R53_ZONE_DNS" ]];
then
  K8sRoute53ZoneName=`cat /opt/kops-state/KOPS_VPC_R53_ZONE_DNS`
  K8sRoute53ZoneName=`echo "${K8sRoute53ZoneName}" | tr '[:upper:]' '[:lower:]'`
  K8sClusterName=${K8sRoute53ZoneName}
else
  echo "ERROR: no internal zone found, using local gossip based dns: ${K8sRoute53ZoneName}"
fi

echo "K8sRoute53ZoneName: ${K8sRoute53ZoneName}"
echo "K8sClusterName: ${K8sClusterName}"

#create s3 bucket
if [[ ! -e s3-kops-state.txt ]];
then
    s3bucket="kops-state-${AWSCfnStackName}-${randomstuff}"
    echo "Create bucket: ${s3bucket}"
    echo ${s3bucket} > s3-kops-state.txt
else
    s3bucket=`cat s3-kops-state.txt`
fi

echo "KOPS state S3 bucket: ${s3bucket}"

export KOPS_STATE_STORE=s3://${s3bucket}

echo ${VPC} >> /opt/kops-state/KOPS_VPC

echo ${KOPS_STATE_STORE} > /opt/kops-state/KOPS_STATE_STORE
echo ${PrivateSubnet1} > /opt/kops-state/KOPS_PRIVATE_SUBNETS
echo ${PrivateSubnet2} >> /opt/kops-state/KOPS_PRIVATE_SUBNETS

if [[ -n ${PrivateSubnet3} ]];
then
  echo ${PrivateSubnet3} >> /opt/kops-state/KOPS_PRIVATE_SUBNETS
fi
echo ${K8sMasterAndNodeSecurityGroup} > /opt/kops-state/KOPS_SECURITY_GROUP

echo ${PublicSubnet1} >> /opt/kops-state/KOPS_PUBLIC_SUBNETS
echo ${PublicSubnet2} >> /opt/kops-state/KOPS_PUBLIC_SUBNETS
echo ${PublicSubnet3} >> /opt/kops-state/KOPS_PUBLIC_SUBNETS

#create kops state bucket
if [[ "${AWSRegion}" == "us-east-1" ]];
then
    aws s3api create-bucket --bucket ${s3bucket} --region ${AWSRegion}
else
    aws s3api create-bucket --bucket ${s3bucket} --region ${AWSRegion} --create-bucket-configuration LocationConstraint=${AWSRegion}
fi

#switch on kops state bucket versioning
aws s3api put-bucket-versioning --bucket ${s3bucket} --versioning-configuration Status=Enabled --region ${AWSRegion}

#public key for kops
pkey=`head -n1 /home/ubuntu/.ssh/authorized_keys`
echo ${pkey} > id_rsa.pub
chmod 600 id_rsa.pub


#defione image for nodes
#Debian Jessie is the default if no option
k8s_ami=""
host_ssl_certpath="/etc/ssl/certs/ca-certificates.crt"
host_ssl_certdir="/etc/ssl/certs"


if [ "${Ec2K8sAMIOsType}" == "Ubuntu-1604-LTS" ]; 
then
    ami_ubuntu=`aws ec2 describe-images --owners 099720109477 --filters Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server* --query 'Images[*].[ImageId,CreationDate]' --output text --region ${AWSRegion} | sort -k2 -r | head -n1 | awk '{print $1}'`
    k8s_ami="--image=${ami_ubuntu}"
fi

if [ "${Ec2K8sAMIOsType}" == "Ubuntu-1804-LTS" ]; 
then
    ami_ubuntu=`aws ec2 describe-images --owners 099720109477 --filters Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-18.04-amd64-server* --query 'Images[*].[ImageId,CreationDate]' --output text --region ${AWSRegion} | sort -k2 -r | head -n1 | awk '{print $1}'`
    k8s_ami="--image=${ami_ubuntu}"
fi

if [ "${Ec2K8sAMIOsType}" == "AmazonLinux2" ]; 
then
    ami_ubuntu=`aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-2.0.*-x86_64-gp2" "Name=architecture,Values=x86_64" "Name=root-device-type,Values=ebs" --query 'Images[*].[ImageId,CreationDate]' --output text --region ${AWSRegion} | sort -k2 -r | head -n1 | awk '{print $1}'`
    k8s_ami="--image=${ami_ubuntu}"
    host_ssl_certpath="/etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt"
    host_ssl_certdir="/etc/pki/ca-trust/extracted/pem"
fi

if [ "${Ec2K8sAMIOsType}" == "CentOS-7" ]; 
then
    ami_centos=`aws ec2 describe-images --owners 410186602215 --filters "Name=virtualization-type,Values=hvm" "Name=name,Values=CentOS Linux 7 x86_64 HVM EBS*" --query 'Images[*].[ImageId,CreationDate]' --output text --region ${AWSRegion} | sort -k2 -r | head -n1 | awk '{print $1}'`
    k8s_ami="--image=${ami_centos}"
    host_ssl_certpath="/etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt"
    host_ssl_certdir="/etc/pki/ca-trust/extracted/pem"
fi

if [ "${Ec2K8sAMIOsType}" == "RHEL-7" ]; 
then
    ami_rhel7=`aws ec2 describe-images --owner=309956199498 --filters "Name=virtualization-type,Values=hvm" "Name=name,Values=RHEL-7.*" --query 'Images[*].[ImageId,CreationDate]' --output text --region ${AWSRegion} | sort -k2 -r | head -n1 | awk '{print $1}'`
    k8s_ami="--image=${ami_rhel7}"
    host_ssl_certpath="/etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt"
    host_ssl_certdir="/etc/pki/ca-trust/extracted/pem"
fi

if [[ -n ${FORCED_AMI_ID} ]];
then
  echo "FORCE AMI ID TO USE: ${FORCED_AMI_ID}"
  k8s_ami="--image=${FORCED_AMI_ID}"
fi

echo "Kubernetes Cluster AMI: ${k8s_ami}"

#internal / external API
api_lb_type="--api-loadbalancer-type=internal"
dns_zone="--dns-zone=${K8sRoute53ZoneName}"
dns="--dns=private"
if [[ "${KubernetesAPIPublicAccess}" == "true" ]];
then
  echo "K8s API LB is Public, using Gossip DNS configuration ..."
  api_lb_type="--api-loadbalancer-type=public"
  dns_zone=""
  dns=""
  K8sClusterName="${AWSCfnStackName}.k8s.local"
fi 

# set env variables
echo ${K8sClusterName} > /opt/kops-state/KOPS_CLUSTER_NAME
echo "INIT KOPS with: K8sClusterName: ${K8sClusterName}"

echo "export KOPS_STATE_STORE=${KOPS_STATE_STORE}" >> /etc/bashrc
echo "export NAME=${K8sClusterName}" >> /etc/bashrc

echo "export KOPS_STATE_STORE=${KOPS_STATE_STORE}" >> /home/ubuntu/.bashrc
echo "export NAME=${K8sClusterName}" >> /home/ubuntu/.bashrc

echo "export KOPS_STATE_STORE=${KOPS_STATE_STORE}" >> /root/.bashrc
echo "export NAME=${K8sClusterName}" >> /root/.bashrc


#tag instance
instance_id=`curl http://169.254.169.254/latest/meta-data/instance-id`
aws ec2 create-tags --resources ${instance_id} --tags Key=KOPS-state-store-bucket,Value=${KOPS_STATE_STORE} --region ${AWSRegion}

#create kops config
if [ "${Ec2K8sMultiAZMaster}" == "true" ]; 
then
kops create cluster \
  --name="${K8sClusterName}" \
  --cloud-labels="Name=${K8sClusterName}" \
  ${dns_zone} \
  ${dns} \
  ${node_zones} \
  ${master_zones} \
  --master-count=3 \
  --state="s3://${s3bucket}" \
  --topology="private" \
  --networking="calico"  \
  --node-count="${Ec2K8sNodeCapacityMin}" \
  --node-size="${Ec2K8sNodeInstanceType}" \
  --master-size="${Ec2K8sMasterInstanceType}" \
  --vpc="${VPC}" \
  --cloud="aws" \
  --ssh-public-key="id_rsa.pub" \
  ${k8s_ami} \
  --associate-public-ip="false" \
  ${api_lb_type} \
  --network-cidr="${NetworkCIDR}" \
  --master-security-groups="${K8sMasterAndNodeSecurityGroup}" \
  --node-security-groups="${K8sMasterAndNodeSecurityGroup}" \
  --master-volume-size="${Ec2EBSK8sDiskSizeGb}" \
  --node-volume-size="${Ec2EBSK8sDiskSizeGb}" \
  --authorization="RBAC" \
  --dry-run \
  --output="yaml" > /opt/kops-config/${K8sClusterName}.yaml || exit 1
else
kops create cluster \
  --name="${K8sClusterName}" \
  --cloud-labels="Name=${K8sClusterName}" \
  ${dns_zone} \
  ${dns} \
  ${node_zones} \
  --master-count=1 \
  --state="s3://${s3bucket}" \
  --topology="private" \
  --networking="calico"  \
  --node-count="${Ec2K8sNodeCapacityMin}" \
  --node-size="${Ec2K8sNodeInstanceType}" \
  --master-size="${Ec2K8sMasterInstanceType}" \
  --vpc="${VPC}" \
  --cloud="aws" \
  --ssh-public-key="id_rsa.pub" \
  ${k8s_ami} \
  --associate-public-ip="false" \
  ${api_lb_type} \
  --network-cidr="${NetworkCIDR}" \
  --master-security-groups="${K8sMasterAndNodeSecurityGroup}" \
  --node-security-groups="${K8sMasterAndNodeSecurityGroup}" \
  --master-volume-size="${Ec2EBSK8sDiskSizeGb}" \
  --node-volume-size="${Ec2EBSK8sDiskSizeGb}" \
  --authorization="RBAC" \
  --dry-run \
  --output="yaml" > /opt/kops-config/${K8sClusterName}.yaml || exit 1
fi

#apply subnet and policy mod
python kops-sharedvpc-iam-yamlconfig.py ${AWSRegion} /opt/kops-config/${K8sClusterName}.yaml kops-cluster-additionalpolicies.json /opt/kops-config/${K8sClusterName}.MOD.yaml ${NODES_SPOT_PRICE} ${Ec2K8sNodeCapacityMax}

#check existing modified config
if [[ ! -e "/opt/kops-config/${K8sClusterName}.MOD.yaml" ]];
then
  echo "ERROR: missing Kops config file!"
  exit 1
fi

#create k8s cluster config
kops create -f /opt/kops-config/${K8sClusterName}.MOD.yaml

#create k8s secret with Ubuntu SSH key
kops create secret --name ${K8sClusterName} sshpublickey admin -i id_rsa.pub

#apply cluster changes
kops update cluster ${K8sClusterName} --yes

#wait for cluster ready
k8s_done=""
k8s_successful=1

#init kops environment on Bastion host
export HOME=/opt
cd $HOME
kops export kubecfg ${K8sClusterName}

mkdir -p /home/ubuntu/.kube
cp $HOME/.kube/config /home/ubuntu/.kube/

for i in {1..90};
do 
    clusterstate=`kops validate cluster | egrep -i "is not healthy|is ready" | grep -v grep`; 
    if [[ -n ${clusterstate} ]]; 
    then 
      echo ${clusterstate}; 
      k8s_done="OK";
      k8s_successful=0;
      break;  
    else 
      echo $i;
      sleep 10; 
    fi 
done

sleep 10

#init kops environment on Bastion host
export HOME=/opt
cd $HOME
kops export kubecfg ${K8sClusterName}


mkdir -p /home/ubuntu/.kube
cp $HOME/.kube/config /home/ubuntu/.kube/

mkdir -p /root/.kube
cp $HOME/.kube/config /root/.kube/

chown -R ubuntu:ubuntu /home/ubuntu
chown -R ubuntu:ubuntu /opt
chmod -R og+rX /opt

if [[ ! -n ${k8s_done} ]];
then
  echo "########################"
  echo "ERROR CLUSTER DOES NOT RUNNING HEALTHY!"
  echo "########################"
else
  echo "########################"
  echo "K8S CLUSTER IS RUNNING."
  echo "########################"
fi

## workaround for RHEL/CentOS/Amazonlinux host + Calico + Multi-AZ nezworking / k8s-ec2-srcdst
if [ "${Ec2K8sAMIOsType}" == "CentOS-7" ] || [ "${Ec2K8sAMIOsType}" == "RHEL-7" ] || [ "${Ec2K8sAMIOsType}" == "AmazonLinux2" ];
then
  echo "APPLY k8s-ec2-srcdst pathch..."
  kubectl patch deployment k8s-ec2-srcdst --namespace kube-system -p '{"apiVersion":"extensions/v1beta1","kind":"Deployment","metadata":{"annotations":{},"labels":{"k8s-app":"k8s-ec2-srcdst","role.kubernetes.io/networking":"1"},"name":"k8s-ec2-srcdst","namespace":"kube-system"},"spec":{"replicas":1,"selector":{"matchLabels":{"k8s-app":"k8s-ec2-srcdst"}},"template":{"metadata":{"annotations":{"scheduler.alpha.kubernetes.io/critical-pod":""},"labels":{"k8s-app":"k8s-ec2-srcdst","role.kubernetes.io/networking":"1"}},"spec":{"containers":[{"imagePullPolicy":"Always","name":"k8s-ec2-srcdst","resources":{"requests":{"cpu":"10m","memory":"64Mi"}},"volumeMounts":[{"mountPath":"/etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt","name":"ssl-certs","readOnly":true}]}],"hostNetwork":true,"nodeSelector":{"node-role.kubernetes.io/master":""},"serviceAccountName":"k8s-ec2-srcdst","tolerations":[{"effect":"NoSchedule","key":"node-role.kubernetes.io/master"},{"key":"CriticalAddonsOnly","operator":"Exists"}],"volumes":[{"hostPath":{"path":"/etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt"},"name":"ssl-certs"}]}}}}'
fi

#Enable legacy authorization mode
kubectl create clusterrolebinding permissive-binding --clusterrole=cluster-admin --user=admin --user=kubelet --group=system:serviceaccounts

for i in {1..120};
do 
    clusterstate=`kops validate cluster | grep -i "is ready" | grep -v grep`; 
    if [[ -n ${clusterstate} ]]; 
    then 
      echo ${clusterstate}; 
      k8s_done="OK";
      k8s_successful=0;
      break;  
    else 
      echo $i;
      sleep 10; 
    fi 
done


#######################
# KOPS Addons
#######################
echo "########################"
echo "Install addons ..."
echo "########################"

cd /opt/bastion-init/

sleep 5

# Kubernetes Cluster Autoscaler
if [ "${KubernetesClusterAutoscaler}" == "true" ]; 
then
  echo "Install K8s Cluster Autoscaler ..."
  
  #RH certpath: /etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt

  CLOUD_PROVIDER=aws
  IMAGE=gcr.io/google-containers/cluster-autoscaler:v1.3.5
  MIN_NODES=${Ec2K8sNodeCapacityMin}
  MAX_NODES=${Ec2K8sNodeCapacityMax}
  AWS_REGION=${AWSRegion}
  GROUP_NAME="nodes.${K8sClusterName}"
  SSL_CERT_PATH=${host_ssl_certpath}

  addon=cluster-autoscaler.yml

  sed -i -e "s@{{CLOUD_PROVIDER}}@${CLOUD_PROVIDER}@g" "${addon}"
  sed -i -e "s@{{IMAGE}}@${IMAGE}@g" "${addon}"
  sed -i -e "s@{{MIN_NODES}}@${MIN_NODES}@g" "${addon}"
  sed -i -e "s@{{MAX_NODES}}@${MAX_NODES}@g" "${addon}"
  sed -i -e "s@{{GROUP_NAME}}@${GROUP_NAME}@g" "${addon}"
  sed -i -e "s@{{AWS_REGION}}@${AWS_REGION}@g" "${addon}"
  sed -i -e "s@{{SSL_CERT_PATH}}@${SSL_CERT_PATH}@g" "${addon}"

  kubectl apply -f ${addon}
fi

# Kubernetes ALB ingress controller
if [ "${KubernetesALBIngressController}" == "true" ]; 
then
  echo "Install K8s ALB ingress controller ..."
  
  addon=alb-ingress-controller.yaml
  sed -i 's/__REPLACE_AWS_REGION__/'${AWSRegion}'/g' ${addon}
  sed -i 's/__REPLACE_K8S_CLUSTER_NAME__/'${K8sClusterName}'/g' ${addon}
  sed -i 's/__REPLACE_VPC_ID__/'${VPC}'/g' ${addon}
  
  kubectl apply -f ${addon}
fi


# kubernetes dashboard
if [ "${KubernetesDashboard}" == "true" ]; 
then
  echo "Install monitoring plugins ( influxDB, grafana, heapster ) ..."
  addon=kubernetes-monitoring.yaml
  
  SSL_CERT_DIR=${host_ssl_certdir}
  sed -i -e "s@{{SSL_CERT_DIR}}@${SSL_CERT_DIR}@g" "${addon}"
  kubectl apply -f ${addon}
  
  echo "Install Kubernetes Dashboard ..."
  kubectl apply -f kubernetes-dashboard.yaml
  
fi

# kubernetes external DNS plugin
if [ "${KubernetesExternalDNSPlugin}" == "true" ]; 
then
  echo "Install external-dns plugin ..."
  addon=alb-dns-external.yaml
  
  if [[ ! -n ${KubernetesExternalDNSName} ]];
  then
    KubernetesExternalDNSName=${K8sClusterName}
  fi
  
  sed -i 's/__REPLACE_DNS_NAME__/'${KubernetesExternalDNSName}'/g' ${addon}
  sed -i 's/__REPLACE_ZONE_TXT_ID__/'${KubernetesExternalDNSTXTSelector}'/g' ${addon}
  kubectl apply -f ${addon}
  
fi

#final kops validation
for i in {1..120};
do 
    clusterstate=`kops validate cluster | grep "is ready" | grep -v grep`; 
    if [[ -n ${clusterstate} ]]; 
    then 
      echo ${clusterstate}; 
      k8s_done="OK";
      k8s_successful=0;
      break;  
    else 
      echo $i;
      sleep 10; 
    fi 
done

for _ in {1..180};
do
    daskstatus=`kubectl get pods --all-namespaces | grep "ContainerCreating"`
    if [[ -n ${daskstatus} ]];
    then
        echo "Waiting UP ALL CONTAINERS ...";
        sleep 10;
        continue;
    else
        echo "Kubernetes IS UP!"
        break;
    fi
done

echo "Kubernetes clutser is running."

echo "########################"
echo "DONE INIT-KOPS. EXIT ${k8s_successful}"
echo "########################"
exit ${k8s_successful}
