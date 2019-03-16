# AWS Quick Start: Production grade Kubernetes cluster deployment on AWS cloud

This AWS Quick-Start ("one-click solution") based on AWS CloudFormation templates and scripts set up a flexible, secure, fault-tolerant Kubernetes cluster in AWS private VPC environment, into a configuration of your choice. The project main purposes are: quick, simple, painless, easy Kubernetes environment deployment in 10 minutes.

Our solution based on Kubernetes Operations ("kops") combined with AWS CloudFormation (CFN) templates together with bootstrap scripts, help to automate the whole process. The final result is a 100% compatible Kubernetes cluster, what you can manage from either the Bastion host, via OpenVPN or using it's HTTPS API through AWS ELB endpoint.

We always keep focus on security, transparency and simplicity. This guide is mainly created for developers, IT architects, administrators, and DevOps professionals who are planning to easily deploy their Kubernetes workloads on AWS.


# Architecture

[![N|Solid](https://raw.githubusercontent.com/totalcloudconsulting/kubernetes-aws/master/docs/k8s-small-footprint.png)](https://totalcloudconsulting.hu/en/solutions/containerization)


[AWS Quick-Start Launch](https://console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/new?stackName=Total-Cloud-Kubernetes&templateURL=https://s3-eu-west-1.amazonaws.com/tc2-kubernetes/latest/cfn-templates/latest-single-natinstance.yaml )

## Resources deployed

* one new VPC: 3 private and 3 public subnets in 3 different Availability Zones, Gateway type Private Link routes to S3 and DynamoDB (free),
* one self-healing Kubernetes Master instance in one Availability Zone's private subnet,
* auto-scalable Node instances in AutoScaling groups, expended over all Availability Zones,
* one self-healing bastion host in 1 Availability Zone's public subnet, bastion host is the NAT instance router for private subnets,
* one Elastic IP Address (EIP) for bastion host,
* one internal (or public: optional) ELB load balancer for HTTPS access to the Kubernetes API server,
* two CloudWatch Logs group for bastion host and Kubernetes Docker pods (optional),
* one Lambda function for graceful teardown with AWS SSM,
* two security groups: 1 for bastion host, 1 for Kubernetes Hosts (Master and Nodes)
* IAM roles for bastion hosts, K8s Nodes and Master hosts
* one S3 bucket for kops state store,
* one Route53 private zone for VPC (optional),
* OpenVPN service with auto-generated keys on bastion host (optional)
* AWS EFS mounted on bastion in all AZs
* optional ALB ingress controller with external (Route53) domain management

# How To build your cluster

* Sign up for an AWS account at https://aws.amazon.com. then sign in with proper rights (IAM full rights are required)

Create the Kubernetes cluster:

[AWS Quick-Start Launch](https://console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/new?stackName=Total-Cloud-Kubernetes&templateURL=https://s3-eu-west-1.amazonaws.com/tc2-kubernetes/latest/cfn-templates/latest-single-natinstance.yaml )


**The cluster (via bastion host) creation lasts around 10-15 minutes, please be patient.**

* Connect to your Kubernetes cluster by following the step-by-step instructions in the deployment guide.

To customize your deployment, you can choose different instance types for the Kubernetes cluster and the bastion host, choose the number of worker nodes, API endpoint type, logging option, OpenVPN install,  plug-ins.  

For detailed instructions, see the deployment guide.


The cluster (via bastion host) creation lasts around 10 minutes, please be patient.

**After the clutser has been created, just connect to the bastion host via SSH, the "kops", "kubectl" and "helm" commands working out-of-the box, no extras steps needed!**

# Abstract paper

Have a look at [this abstract paper](docs/TC2_Abstratct_production_grade_Kubernetes_deployment_on_AWS.pdf) for the high level details of this solution.

# Visit us

https://totalcloudconsulting.hu/en/solutions

# References

* Kubernetes Open-Source Documentation: https://kubernetes.io/docs/
* Calico Networking: http://docs.projectcalico.org/
* KOPS documentation: https://github.com/kubernetes/kops/blob/master/docs/aws.md ,  https://github.com/kubernetes/kops/tree/master/docs
* Kubernetes Host OS versions: https://github.com/kubernetes/kops/blob/master/docs/images.md
* OpenVPN: https://github.com/tatobi/easy-openvpn
* ALB ingress controller: https://github.com/kubernetes-sigs/aws-alb-ingress-controller

# Costs and licenses

You are responsible for the cost of the AWS services used while running this deployment. Our project hosted under Apache 2.0 open source license.
