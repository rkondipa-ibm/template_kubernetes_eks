variable "cluster_name" {
  description = "The base name for the cluster."
}

variable "aws_region" {
  description = "AWS region to launch cluster"
}

variable "aws_availability_zones" {
  type = list(string)
}

variable "kube_version" {
  description = "Kubernetes version for the cluster."
}

variable "aws_ami_owner_id" {
  description = "AWS AMI Owner ID"
}

variable "aws_ami_name_prefix" {
  description = "Name prefix for AWS AMI"
}

variable "aws_image_size" {
  description = "AWS Image Instance Size"
}

variable "min_worker_count" {
  description = "Minimum number of worker nodes"
}

variable "max_worker_count" {
  description = "Maximum number of worker nodes"
}

variable "initial_worker_count" {
  description = "Initial number of worker nodes"
}

