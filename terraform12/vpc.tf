locals {
  stack_name = "${var.cluster_name}-vpc"
}

resource "aws_vpc" "cluster_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    "Name"                                      = local.stack_name
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "aws:cloudformation:stack-name"             = local.stack_name
  }
}

