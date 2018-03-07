# Production grade Kubernetes cluster deployment on AWS cloud

These AWS CloudFormation templates and scripts set up a flexible, secure, fault-tolerant Kubernetes cluster in AWS private VPC environment automatically, into a configuration of your choice. The project main purposes are: simple, painless, script-less, easy Kubernetes environment deployment in 1 step.

We provide two deployment versions with the same underlying AWS VPC toplogy:

* full scale: fault tolerant, production grade architecture (multi master, multi node, NAT gateways),
* small footprint: single master, single NAT instance, single node deployment (for testing, demo, first steps)

Originally we created this project to make easy to deploy a working Kubernetes cluster on Amazon Web Services (AWS) Cloud, now it supports full-scale, prouction grade setup as well. The Kubernetes Operations ("kops") project and AWS CloudFormation (CFN) templates togedther with bootstrap scripts, the whole process has automated. The final result is a Kubernetes cluster, with Kops compatibility, what you can manage from either the Bastion host, via OpenVPN or using HTTPS API through AWS ELB endpoint.

The project keeps focus on security, transparency and simplicity. This guide is mainly created for developers, IT architects, administrators, and DevOps professionals who are planning to implement their Kubernetes workloads on AWS.



# Full-scale architecture

[![N|Solid](https://raw.githubusercontent.com/totalcloudconsulting/kubernetes-aws/master/docs/k8s-fullscale.png)](https://totalcloudconsulting.hu/en/solutions/containerization)

[One-Click launch CloudFormation stack: Full scale](https://console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/new?stackName=Total-Cloud-K8s-Full&templateURL=https://s3-eu-west-1.amazonaws.com/tc2-kubernetes/latest/cfn-templates/latest.yaml )

## Resources deployed

* one VPC: 3 private and 3 public subnets in 3 different Availability Zones, Gateway type Private Link routes to S3 and DynamoDB (free),
* three NAT gateways in each public subnet in each 3 Availability Zones,
* three  self-healing Kubernetes Master instances in each Availability Zone's private subnet, in AutoScaling groups (separate ASGs),
* three Node instances in one AutoScaling group, expended over all Availability Zones,
* one self-healing bastion host in 1 Availability Zone's public subnet,
* four Elastic IP Addresses: 3 for NAT Gateways, 1 for Bastion host,
* one internal (or public: optional) ELB load balancer for HTTPS access to the Kubernetes API,
* two CloudWatch Logs group for bastion host and Kubernetes Docker pods (optional),
* one Lambda function for graceful teardown with AWS SSM,
* two security groups: 1 for bastion host, 1 for Kubernetes Hosts (Master and Nodes),
* IAM roles for bastion hosts, K8s Nodes and Master hosts,
* one S3 bucket for kops state store,
* one Route53 private zone for VPC (optional)


# Small footprint architecture

[![N|Solid](https://raw.githubusercontent.com/totalcloudconsulting/kubernetes-aws/master/docs/k8s-small-footprint.png)](https://totalcloudconsulting.hu/en/solutions/containerization)


[One-Click launch CloudFormation stack: Small footptint](https://console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/new?stackName=Total-Cloud-K8s-Small&templateURL=https://s3-eu-west-1.amazonaws.com/tc2-kubernetes/latest/cfn-templates/latest-single-natinstance.yaml )

## Resources deployed

* one VPC: 3 private and 3 public subnets in 3 different Availability Zones, Gateway type Private Link routes to S3 and DynamoDB (free),
* one self-healing Kubernetes Master instance in one Availability Zone's private subnet,
* one Node instance in AutoScaling groups, expended over all Availability Zones,
* one self-healing bastion host in 1 Availability Zone's public subnet,
* bastion host is the NAT instance router for private subnets,
* four Elastic IP Addresses: 3 for NAT Gateways, 1 for Bastion host,
* one internal (or public: optional) ELB load balancer for HTTPS access to the Kubernetes API,
* two CloudWatch Logs group for bastion host and Kubernetes Docker pods (optional),
* one Lambda function for graceful teardown with AWS SSM,
* two security groups: 1 for bastion host, 1 for Kubernetes Hosts (Master and Nodes)
* IAM roles for bastion hosts, K8s Nodes and Master hosts
* one S3 bucket for kops state store,
* one Route53 private zone for VPC (optional)


# How To build your cluster

* Sign up for an AWS account at https://aws.amazon.com.

Choose which deployment type you prefer:

* Full scale deployment: Launch the [AWS One-Click CloudFormation Stack: Full scale](https://console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/new?stackName=Total-Cloud-K8s-Full&templateURL=https://s3-eu-west-1.amazonaws.com/tc2-kubernetes/latest/cfn-templates/latest.yaml ) Template: [View template](https://s3-eu-west-1.amazonaws.com/tc2-kubernetes/latest/cfn-templates/latest.yaml )

* Small fottprint deployment: Launch the [AWS One-Click CloudFormation Stack: Small footptint](https://console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/new?stackName=Total-Cloud-K8s-Small&templateURL=https://s3-eu-west-1.amazonaws.com/tc2-kubernetes/latest/cfn-templates/latest-single-natinstance.yaml ) Template: [View template](https://s3-eu-west-1.amazonaws.com/tc2-kubernetes/latest/cfn-templates/latest-single-natinstance.yaml )


**The cluster (via bastion host) creation lasts around 10-15 minutes, please be patient.**

* Connect to your Kubernetes cluster by following the step-by-step instructions in the deployment guide.

To customize your deployment, you can choose different instance types for the Kubernetes cluster and the bastion host, choose the number of worker nodes, API endpoint type, logging option, OpenVPN install,  plug-ins.  

For detailed instructions, see the deployment guide.


The cluster (via bastion host) creation lasts around 10 minutes, please be patient.

**After the clutser has been created, just connect to the bastion host via SSH, the "kops", "kubectl" and "helm" commands working out-of-the box, no extras steps needed!**

# Logs

Optional: If you choose in template options, all container logs are sent to AWS CloudWatch Logs. In that case, local "kubectl" logs aren't  available internally via API call (e.g. kubectl logs ... command: "Error response from daemon: configured logging driver does not support reading") Please check the AWS CloudWatch / Logs / K8s* for container logs.

# Abstract paper

Have a look at [this abstract paper](docs/TC2_Abstratct_production_grade_Kubernetes_deployment_on_AWS.pdf) for the high level details of this solution.

# Visit us

https://totalcloudconsulting.hu/en/solutions

# Costs and licenses

You are responsible for the cost of the AWS services used while running this deployment.
