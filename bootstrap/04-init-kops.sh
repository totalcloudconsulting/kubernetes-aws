#!/bin/bash

AWSRegion=${1}
K8sClusterName=${2}
Route53ZoneName_NOT_USED=${3}
Ec2K8sMasterInstanceType=${4}
Ec2K8sNodeInstanceType=${5}
Ec2K8sNodeCapacityMin=${6}
Ec2K8sNodeCapacityMax=${7}
Ec2EBSK8sDiskSizeGb=${8}
Ec2K8sAMIOsType=${9}
Ec2K8sMultiAZMaster=${10}
PrivateSubnet1=${11}
PrivateSubnet2=${12}
VPC=${13}
NetworkCIDR=${14}
K8sMasterAndNodeSecurityGroup=${15}
AWSCfnStackName=${16}
S3BootstrapBucketName=${17}
S3BootstrapBucketPrefix=${18}
KubernetesDashboard=${19}
KubernetesHeapsterMonitoring_NOT_USED=${20}
KubernetesALBIngressController=${21}
KubernetesClusterAutoscaler=${22}
PrivateSubnet3=${23}
PublicSubnet1=${24}
PublicSubnet2=${25}
PublicSubnet3=${26}
KubernetesAPIPublicAccess=${27}
CWLOGS=${28}

echo "#################"
echo "START INIT-KOPS."

K8sClusterName=`echo "${K8sClusterName}" | tr '[:upper:]' '[:lower:]'`

#sync kops, k8s binaries
aws s3 sync s3://${S3BootstrapBucketName}/${S3BootstrapBucketPrefix}/bin/ /usr/local/bin/ --region ${AWSRegion} --quiet

if [[ ! -e /usr/local/bin/kops ]]; 
then 
  echo "Download latest KOPS...";
  #wget -O kops https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64 --no-verbose
  wget -O kops https://github.com/kubernetes/kops/releases/download/1.9.0/kops-linux-amd64 --no-verbose
  sudo mv ./kops /usr/local/bin/
fi

if [[ ! -e /usr/local/bin/kubectl ]]; 
then 
  echo "Download latest KUBECTL...";
  #wget -O kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl --no-verbose
  wget -O kubectl https://storage.googleapis.com/kubernetes-release/release/v1.9.3/bin/linux/amd64/kubectl --no-verbose
  mv ./kubectl /usr/local/bin/kubectl
fi

if [[ ! -e /usr/local/bin/helm ]]; 
then 
  echo "Download latest HELM...";
  wget -O helm.tar.gz https://storage.googleapis.com/kubernetes-helm/helm-$(curl -s https://github.com/kubernetes/helm/releases/latest | grep tag | cut -d '/' -f 8 | cut -d '"' -f 1)-linux-amd64.tar.gz --no-verbose
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

#create kops-s3-state
randomsuff=`cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8`
stacklower=`echo "${AWSCfnStackName}" | tr '[:upper:]' '[:lower:]'`
echo $stacklower

K8sRoute53ZoneName="${K8sClusterName}.k8s.local"
if [[ -e "/opt/kops-state/KOPS_VPC_R53_ZONE_DNS" ]];
then
  K8sRoute53ZoneName=`cat /opt/kops-state/KOPS_VPC_R53_ZONE_DNS`
  echo "K8sRoute53ZoneName: ${K8sRoute53ZoneName}"
else
  echo "ERROR: no internal zone created, using local gossip based dns: ${K8sRoute53ZoneName}"
fi


#create s3 bucket
if [[ ! -e s3-kops-state.txt ]];
then
    s3bucket="k8s-kops-state-${K8sClusterName}-${randomsuff}"
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

if [[ "${AWSRegion}" == "us-east-1" ]];
then
    aws s3api create-bucket --bucket ${s3bucket} --region ${AWSRegion}
else
    aws s3api create-bucket --bucket ${s3bucket} --region ${AWSRegion} --create-bucket-configuration LocationConstraint=${AWSRegion}
fi


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
if [ "${Ec2K8sAMIOsType}" == "CoreOS-Latest" ]; 
then
    ami_coreos=`aws ec2 describe-images --owner=595879546273 --filters "Name=virtualization-type,Values=hvm" "Name=name,Values=CoreOS-stable*" --query 'Images[*].[ImageId,CreationDate]' --output text --region ${AWSRegion} | sort -k2 -r | head -n1 | awk '{print $1}'`
    k8s_ami="--image=${ami_coreos}"
fi

if [ "${Ec2K8sAMIOsType}" == "Ubuntu-1604" ]; 
then
    ami_ubuntu=`aws ec2 describe-images --owners 099720109477 --filters Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server* --query 'Images[*].[ImageId,CreationDate]' --output text --region ${AWSRegion} | sort -k2 -r | head -n1 | awk '{print $1}'`
    k8s_ami="--image=${ami_ubuntu}"
fi

if [ "${Ec2K8sAMIOsType}" == "CentOS-7-Latest" ]; 
then
    ami_centos=`aws ec2 describe-images --owners 410186602215 --filters "Name=virtualization-type,Values=hvm" "Name=name,Values=CentOS Linux 7 x86_64 HVM EBS*" --query 'Images[*].[ImageId,CreationDate]' --output text --region ${AWSRegion} | sort -k2 -r | head -n1 | awk '{print $1}'`
    k8s_ami="--image=${ami_centos}"
    host_ssl_certpath="/etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt"
    host_ssl_certdir="/etc/pki/ca-trust/extracted/pem"
fi

if [ "${Ec2K8sAMIOsType}" == "RHEL-7-Latest" ]; 
then
    ami_rhel7=`aws ec2 describe-images --owner=309956199498 --filters "Name=virtualization-type,Values=hvm" "Name=name,Values=RHEL-7.*" --query 'Images[*].[ImageId,CreationDate]' --output text --region ${AWSRegion} | sort -k2 -r | head -n1 | awk '{print $1}'`
    k8s_ami="--image=${ami_rhel7}"
    host_ssl_certpath="/etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt"
    host_ssl_certdir="/etc/pki/ca-trust/extracted/pem"
fi

echo "K8s AMI: ${k8s_ami}"


#k8s cluster name
k8sclustername="${K8sClusterName}.${K8sRoute53ZoneName}"

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
  k8sclustername="${K8sClusterName}.k8s.local"
fi 

# set env variables
echo ${k8sclustername} > /opt/kops-state/KOPS_CLUSTER_NAME
echo "INIT KOPS with: K8sClusterName: ${k8sclustername}"

echo "export KOPS_STATE_STORE=${KOPS_STATE_STORE}" >> /etc/bashrc
echo "export NAME=${k8sclustername}" >> /etc/bashrc
echo "export KOPS_STATE_STORE=${KOPS_STATE_STORE}" >> /home/ubuntu/.bashrc
echo "export NAME=${k8sclustername}" >> /home/ubuntu/.bashrc

#tag instance
instance_id=`curl http://169.254.169.254/latest/meta-data/instance-id`
aws ec2 create-tags --resources ${instance_id} --tags Key=KOPS-state-store-bucket,Value=${KOPS_STATE_STORE} --region ${AWSRegion}

#create kops config
if [ "${Ec2K8sMultiAZMaster}" == "true" ]; 
then
kops create cluster \
  --name="${k8sclustername}" \
  --cloud-labels="Name=${k8sclustername}" \
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
  --output="yaml" > /opt/kops-config/${k8sclustername}.yaml || exit 1
else
kops create cluster \
  --name="${k8sclustername}" \
  --cloud-labels="Name=${k8sclustername}" \
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
  --output="yaml" > /opt/kops-config/${k8sclustername}.yaml || exit 1
fi

#create aws logs group
echo "Crete Log Group for alld Docker container (master/Nodes) ..."

loggroupname="NONE"
if [[ -n ${CWLOGS} ]];
then
  loggroupname="k8s-all-cluster-logs-${K8sClusterName}"
  aws logs create-log-group --log-group-name ${loggroupname} --region ${AWSRegion}
  echo ${loggroupname} > /opt/kops-state/KOPS_AWSLOGS
  aws ec2 create-tags --resources ${instance_id} --tags Key=KOPS-awslogs,Value=${loggroupname} --region ${AWSRegion}
  echo "AWS logs group name: ${loggroupname}"
fi

#apply subnet and policy mod
python kops-sharedvpc-iam-yamlconfig.py ${AWSRegion} /opt/kops-config/${k8sclustername}.yaml kops-cluster-additionalpolicies.json ${loggroupname} /opt/kops-config/${k8sclustername}.MOD.yaml

#check existing modified config
if [[ ! -e "/opt/kops-config/${k8sclustername}.MOD.yaml" ]];
then
  echo "ERROR: missing Kops config file!"
  exit 1
fi

#create k8s cluster config
kops create -f /opt/kops-config/${k8sclustername}.MOD.yaml

#create k8s secret with Ubuntu SSH key
kops create secret --name ${k8sclustername} sshpublickey admin -i id_rsa.pub

#apply cluster changes
kops update cluster ${k8sclustername} --yes

#wait for cluster ready
k8s_done=""
k8s_successful=1
for i in {1..90};
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

#init kops environment on Bastion host
export HOME=/opt
cd $HOME
kops export kubecfg ${k8sclustername}
mkdir -p /home/ubuntu/.kube
cp $HOME/.kube/config /home/ubuntu/.kube/

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

## workaround for RHEL/CentOS host + Calico + Multi-AZ nezworking / k8s-ec2-srcdst
if [ "${Ec2K8sAMIOsType}" == "CentOS-7-Latest" ] || [ "${Ec2K8sAMIOsType}" == "RHEL-7-Latest" ];
then
  echo "APPLY k8s-ec2-srcdst pathch..."
  kubectl patch deployment k8s-ec2-srcdst --namespace kube-system -p '{"apiVersion":"extensions/v1beta1","kind":"Deployment","metadata":{"annotations":{},"labels":{"k8s-app":"k8s-ec2-srcdst","role.kubernetes.io/networking":"1"},"name":"k8s-ec2-srcdst","namespace":"kube-system"},"spec":{"replicas":1,"selector":{"matchLabels":{"k8s-app":"k8s-ec2-srcdst"}},"template":{"metadata":{"annotations":{"scheduler.alpha.kubernetes.io/critical-pod":""},"labels":{"k8s-app":"k8s-ec2-srcdst","role.kubernetes.io/networking":"1"}},"spec":{"containers":[{"imagePullPolicy":"Always","name":"k8s-ec2-srcdst","resources":{"requests":{"cpu":"10m","memory":"64Mi"}},"volumeMounts":[{"mountPath":"/etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt","name":"ssl-certs","readOnly":true}]}],"hostNetwork":true,"nodeSelector":{"node-role.kubernetes.io/master":""},"serviceAccountName":"k8s-ec2-srcdst","tolerations":[{"effect":"NoSchedule","key":"node-role.kubernetes.io/master"},{"key":"CriticalAddonsOnly","operator":"Exists"}],"volumes":[{"hostPath":{"path":"/etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt"},"name":"ssl-certs"}]}}}}'
fi

#Enable legacy authorization mode
kubectl create clusterrolebinding permissive-binding --clusterrole=cluster-admin --user=admin --user=kubelet --group=system:serviceaccounts

for i in {1..30};
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
  IMAGE=gcr.io/google_containers/cluster-autoscaler:v1.1.1
  MIN_NODES=${Ec2K8sNodeCapacityMin}
  MAX_NODES=${Ec2K8sNodeCapacityMax}
  AWS_REGION=${AWSRegion}
  GROUP_NAME="nodes.${k8sclustername}"
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
  
  kubectl apply -f alb-default-backend.yaml
  sleep 5
  
  addon=alb-ingress-controller.yaml
  sed -i 's/__REPLACE_AWS_REGION__/'${AWSRegion}'/g' ${addon}
  sed -i 's/__REPLACE_K8S_CLUSTER_NAME__/'${k8sclustername}'/g' ${addon}
  
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

#sync cluster state to local folder
aws s3 sync /opt/kops-state/ s3://${s3bucket}/ --region ${AWSRegion} --quiet
aws s3 sync s3://${s3bucket}/ /opt/kops-state/ --region ${AWSRegion} --quiet

for i in {1..60};
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

for _ in {1..60};
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

echo "Init HELM ..."
export HOME="/opt"

kubectl --namespace kube-system create sa tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller

sleep 15

tilrun=""
for _ in {1..30};
do
    tilrun=`kubectl get pods --all-namespaces | grep "tiller" | grep "Running"`
    if [[ -n "${tilrun}" ]];
    then
        echo "HELM Tiller POD running ... ${tilrun}"
        break
    else
        sleep 5
    fi
done

sleep 5

tilsvc=""
for _ in {1..30};
do
    tilsvc=`kubectl get svc --all-namespaces | grep "tiller-deploy"`
    if [[ -n "${tilsvc}" ]];
    then
        echo "Tiller SVC running ... ${tilsvc}"
        break
    else
        sleep 5
    fi
done


helm version
echo "########################"
echo "DONE INIT-KOPS. EXIT ${k8s_successful}"
echo "########################"
exit ${k8s_successful}
