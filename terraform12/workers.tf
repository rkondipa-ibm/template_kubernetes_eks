resource "aws_iam_role" "worker_role" {
  name = "${var.cluster_name}-worker-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

}

resource "aws_iam_role_policy_attachment" "worker_role_policy_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.worker_role.name
}

resource "aws_iam_role_policy_attachment" "worker_role_policy_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.worker_role.name
}

resource "aws_iam_role_policy_attachment" "worker_role_policy_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.worker_role.name
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "${var.cluster_name}-worker-profile"
  role = aws_iam_role.worker_role.name
}

resource "aws_security_group" "sg_worker" {
  name        = "${var.cluster_name}-sg-worker"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.cluster_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name"                                      = "${var.cluster_name}-sg-worker"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_security_group_rule" "sgr_worker_self_ingress" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.sg_worker.id
  source_security_group_id = aws_security_group.sg_worker.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "sgr_cluster2worker_ingress" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_worker.id
  source_security_group_id = aws_security_group.sg_cluster.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "sgr_workerToCluster_https_ingress" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_worker.id
  source_security_group_id = aws_security_group.sg_cluster.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "sgr_workerFromCluster_https_ingress" {
  description              = "Allow cluster control to receive communication from the workers"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_cluster.id
  source_security_group_id = aws_security_group.sg_worker.id
  to_port                  = 443
  type                     = "ingress"
}

data "aws_ami" "eks_worker" {
  filter {
    name   = "name"
    values = ["${var.aws_ami_name_prefix}-${local.cluster_version}-v*"]
  }

  most_recent = true
  owners      = [var.aws_ami_owner_id] # Amazon EKS AMI Account ID
}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  worker_node_userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.eks_cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.eks_cluster.certificate_authority[0].data}' '${var.cluster_name}'
USERDATA

}

## Worker Node Autoscaling Group resources
resource "aws_launch_configuration" "worker_launch_configuration" {
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.worker_profile.name
  image_id                    = data.aws_ami.eks_worker.id
  instance_type               = var.aws_image_size
  name_prefix                 = var.cluster_name
  security_groups             = [aws_security_group.sg_worker.id]
  user_data_base64            = base64encode(local.worker_node_userdata)

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    delete_on_termination = true
  }
}

resource "aws_autoscaling_group" "worker_autoscaling_group" {
  desired_capacity     = var.initial_worker_count
  launch_configuration = aws_launch_configuration.worker_launch_configuration.id
  max_size             = var.max_worker_count
  min_size             = var.min_worker_count
  name                 = var.cluster_name
  vpc_zone_identifier  = aws_subnet.cluster_subnet_private.*.id

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}_autoscale"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

