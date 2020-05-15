provider "aws" {
  version = "~> 2.44.0"
}

resource "aws_iam_role" "cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

}

resource "aws_iam_role_policy_attachment" "cluster_role_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}

resource "aws_iam_role_policy_attachment" "cluster_role_AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster_role.name
}

resource "aws_security_group" "sg_cluster" {
  name        = "${var.cluster_name}-sg-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.cluster_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "aws:cloudformation:stack-name" = local.stack_name
    "aws:cloudformation:logical-id" = "ControlPlaneSecurityGroup"
  }
}

resource "aws_security_group_rule" "sgr_cluster_https_ingress" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow external sources to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.sg_cluster.id
  to_port           = 443
  type              = "ingress"
}

locals {
  cluster_version = lookup(
    data.external.get_cluster_version.result,
    "cluster_version",
    "",
  )
}

resource "aws_eks_cluster" "eks_cluster" {
  depends_on = [null_resource.validate-kube-version,
                aws_iam_role_policy_attachment.cluster_role_AmazonEKSClusterPolicy,
                aws_iam_role_policy_attachment.cluster_role_AmazonEKSServicePolicy]

  name       = var.cluster_name
  role_arn   = aws_iam_role.cluster_role.arn
  version    = local.cluster_version

  vpc_config {
    security_group_ids = [aws_security_group.sg_cluster.id]
    subnet_ids = concat(
      aws_subnet.cluster_subnet_public.*.id,
      aws_subnet.cluster_subnet_private.*.id,
    )
  }
}

