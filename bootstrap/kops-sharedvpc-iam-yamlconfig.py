#!/usr/bin/env python2.7

import boto3
import yaml
import sys
import os
import time


print "START."
print time.ctime()

#### input, 4 parameters:
# 1: aws region
# 2: kops input config
# 3: additional policies
# 4: aws logs, log group file name
# 5: output yaml file

#defaults
region="eu-west-1"
kopsconf_input="demo.yaml"
kopsconf_additinalpolicies="kops-cluster-additionalpolicies.json"
kopsconf_output_file="out.yaml"
docker_awslogs_group="K8s-Docker"

#aws region
try:
    region=sys.argv[1]
except:
    print "define ARG1: region!"
    sys.exit(1)

#generated kops input config
try:
    kopsconf_input=sys.argv[2]
except:
    print "define ARG2: kops input config!"
    sys.exit(1)

#additional policies
try:
    kopsconf_additinalpolicies=sys.argv[3]
except:
    print "define ARG3: additional JSON policy files for master/nodes"
    sys.exit(1)
    
#aws cloudwatch group name
try:
    docker_awslogs_group=sys.argv[4]
except:
    print "define ARG4: aws cloudwatch group name"
    sys.exit(1)

#output kops config yaml file
try:
    kopsconf_output_file=sys.argv[5]
except:
    print "define ARG5: kops output config"
    sys.exit(1)



if not os.path.exists(kopsconf_input):
  print "Missing kiops config input file!"
  sys.exit(1)

if not os.path.exists(kopsconf_additinalpolicies):
  print "Missing additonal policy file!"
  sys.exit(1)

yl=None

#[ {az-name: subnet_id} ... ]
private_subnets={}
public_subnets={}

#subnet config to replace in kops config
replace_subnets=[]

with open(kopsconf_input,"r") as f:
  yl=yaml.safe_load_all(f.read())

kops=list(yl)
vpcid=kops[0].get("spec").get("networkID")
ec2 = boto3.resource('ec2',region_name=region)
ec2client = boto3.client('ec2',region_name=region)
vpc = ec2.Vpc(vpcid)
subnet_iterator = vpc.subnets.all()

#determine private subnets by routes (NO igw in routes associated with subnet)
for s in subnet_iterator:
  public=False
  sid=s.subnet_id
  az=s.availability_zone
  #print sid
  #print az
  response = ec2client.describe_route_tables(
      Filters=[
          {
              'Name': 'association.subnet-id',
              'Values': [
                  sid
              ]
          }
      ]
  )
  rtb = response['RouteTables'][0]['Associations'][0]['RouteTableId']
  rotb = ec2.RouteTable(rtb)
  #print "Routes:"
  for r in rotb.routes:
    #print r.nat_gateway_id
    #print r.gateway_id
    if r.gateway_id:
      if r.gateway_id.startswith("igw-"):
        #print r.gateway_id
        #print "skip"
        public=True
  if public:
    public_subnets[az]=sid
    continue
  private_subnets[az]=sid

print "Private subnets in VPC: ", vpcid
print private_subnets
print "Public subnets in VPC: ", vpcid
print public_subnets


#replace config cidr with id
subnets = kops[0].get("spec").get('subnets')
for subnet in subnets:
  if subnet.get('type') == "Utility":
    continue
  zone=subnet.get('zone')
  zname=subnet.get('name')
  ztype=subnet.get('type')
  newprivatezone={}
  if zone in private_subnets:
    newprivatezone['id']=private_subnets[zone]
    newprivatezone['zone']=zone
    newprivatezone['name']=zname
    newprivatezone['type']=ztype
  if newprivatezone:
    replace_subnets.append(newprivatezone)

for zone,sid in public_subnets.iteritems():
  newpubliczone={}
  newpubliczone['id']=sid
  newpubliczone['zone']=zone
  newpubliczone['name']="utility-"+zone
  newpubliczone['type']='Utility'
  if newpubliczone:
    replace_subnets.append(newpubliczone)


print "Set new subnet definitions ..."
print replace_subnets
kops[0]['spec']['subnets']=replace_subnets

if docker_awslogs_group != "NONE":
  print "Add docker awslogs ..."
  kops[0]['spec']['docker'] = {'logDriver': "awslogs", "logOpt": ["awslogs-region="+region, "awslogs-group="+docker_awslogs_group]}

#print "Add calico inter-AZ networking ..."
kops[0]['spec']['networking'] = {"calico": {"crossSubnet":True}}

## how to add extra policies to specs:
## AWS ECR + AWS ALB
## additionalPolicies': {'node': '[\n  {\n    "Effect": "Allow",\n    "Action": ["dynamodb:*"],\n    "Resource": ["*"]\n  },\n  {\n    "Effect": "Allow",\n    "Action": ["es:*"],\n    "Resource": ["*"]\n  }\n]\n'},

print "Apply new policies ..."
if os.path.exists(kopsconf_additinalpolicies):
  print "Add policy file: ", kopsconf_additinalpolicies
  ap=""
  with open(kopsconf_additinalpolicies,"r") as f:
    ap=f.read()
  additionalpolicies = {'node': ap, 'master': ap}
  #print additionalpolicies
  kops[0]['spec']['additionalPolicies']=additionalpolicies

out=yaml.safe_dump_all(kops, default_flow_style=False)
print out
with open(kopsconf_output_file,"w") as f:
  f.write(out)

sys.exit(0)
