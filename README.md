# Production grade Kubernetes deployment on AWS Cloud

We created a project to show how easy to deploy a highly available, fault tolerant, full-scale Kubernetes environment on Amazon Web Services (AWS) Cloud, using Kubernetes Operations (kops) and AWS CloudFormation (CFN) templates together that automate the process. The final result is 100% Kubernetes (and "kops") compatible deployment, what you can manage from either the Bastion host or HTTPS API endpoint remotely.

We use the popular tool "kops" because it is the easiest and most elegant way to get a production grade Kubernetes cluster up and running. We keep focus on security and transparency for the whole deployment process. The guide is for IT architects, administrators, and DevOps professionals who are planning to implement  their Kubernetes workloads on AWS.

Combination of AWS Systems Manager (SSM) and AWS Lambda help with graceful cluster tear-down. 


# Architecture

[![N|Solid](https://cldup.com/dTxpPi9lDf.thumb.png)](https://nodesource.com/products/nsolid)


# Resources

* 1 VPC: 3 private and 3 public subnets (6) in 3 different Availability Zones, Private Link routes to S3 and DynamoDB (free)
* 3 NAT gateways in each public subnet in each 3 Availability Zones
* 3  self-healing Kubernetes Master instances in each Availability Zone's private subnet AutoScaling group (separate ASGs)
* 3 Node instances in AutoScalinn groups,  in each Availability Zone (one ASG)
* 1 sel-healing Bastion host in 1 Availability Zone's public subnet, fixed Ubuntu 16.04 LTS, 
* 5 Elastic IP Addresses: 3 for NAT Gateways, 1 -1 for Bastion hosts
* One internal or public ELB load balancer for HTTPS access to the Kubernetes API
* 2 CloudWatch Logs group for Bastion hosts and Kubernetes Docker images
* a Lambda function for graceful teardown through SSM
* 2 security groups 1 for Bastion host, 1 for Kubernetes Hosts (Master and Nodes)
* IAM roles for Bastion hosts, Nodes and Master instances
* An S3 bucket for kops state store
* 1 Route53 private zone for VPC


# One-Click Launch:

https://console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/new?stackName=Total-Cloud-Kubernetes&templateURL=https://s3-eu-west-1.amazonaws.com/tc2-kubernetes/latest/cfn-templates/latest.yaml


#Detailed documentation

TBD: link here

