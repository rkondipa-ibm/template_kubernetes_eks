# Managed Kubernetes Service within Amazon EC2 Cloud
Copyright IBM Corp. 2019, 2020 \
This code is released under the Apache 2.0 License.

## Overview
This terraform template deploys a kubernetes cluster within Amazon Elastic Cloud's Kubernetes Service (EKS).

Via this template, a configurable number of worker agents can be deployed.

## Prerequisites
* To be able to deploy this template into Amazon EC2, the user must be assigned an IAM role with the 'AmazonEKSServicePolicy' and 'AmazonEKSClusterPolicy' IAM policies.

## Template input parameters

| Parameter name         | Parameter description |
| :---                   | :---        |
| cluster_name           | Name of the EKS cluster. Cluster name can have lower case alphabets, numbers and dash. Must start with lower case alphabet and end with alpha-numeric character. Maximum length is 32 characters. |
| aws_region             | AWS region within the cloud in which to create the cluster |
| kube_version           | Kubernetes version for the cluster. Specify 'latest' for the most recent kubernetes version supported by the Kubernetes Service, or a version number in the X.Y[.Z] format (e.g. 1.13 or 1.13.5).  The most recent maintenance release for the specified version will be selected. |
| aws\_ami\_owner\_id    | Owner ID of the AMI ID configured for use as a worker node |
| aws\_ami\_name\_prefix | Prefix of the AMI name, used to find the most recent version of the appropriate AMI for the specified kubernetes version |
| aws\_image\_size       | Size of the worker node image(s) |
| min\_worker\_count     | Miniumum number of worker nodes permitted within the cluster |
| max\_worker\_count     | Maximum number of worker nodes permitted within the cluster |
| initial\_worker\_count | Initial number of worker nodes to be created within the cluster |

