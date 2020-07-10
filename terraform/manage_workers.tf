
## Prepare and execute script that will repeatedly, as needed, check the
## status of the cluster API server endpoint.  If the API server is not
## accessible/fully started, a TLS handshake timeout occurs when attempting
## to enable the nodes in the cluster.  Continue checking until endpoint
## is active or timeout occurs.
resource "random_id" "tmpdir" {
  byte_length = "4"
}

locals {
    workDir    = "/tmp/eks${random_id.tmpdir.hex}"
    scriptPath = "/tmp/eks${random_id.tmpdir.hex}/checkStatus.sh"
}

data "local_file" "check_script_txt"{
  filename   = "${path.module}/scripts/checkStatus.sh"
}

resource "local_file" "generate_check_script" {
  depends_on = [ "aws_eks_cluster.eks_cluster", "aws_autoscaling_group.worker_autoscaling_group" ]
  content    = "${data.local_file.check_script_txt.content}"
  filename   = "${local.scriptPath}"
}

resource "null_resource" "wait_for_api_server" {
  depends_on = ["local_file.generate_check_script"]

  provisioner "local-exec" {
    command = "bash -c '${local.scriptPath} checkApi ${data.aws_eks_cluster.cluster.endpoint} ${base64encode(data.aws_eks_cluster_auth.cluster_auth.token)}'"
  }
}


## With the API server endpoint now active, enable the worker nodes within the cluster
data "aws_eks_cluster" "cluster" { 
  name = "${aws_eks_cluster.eks_cluster.name}"
}

data "aws_eks_cluster_auth" "cluster_auth" {
  name = "${aws_eks_cluster.eks_cluster.name}"
}

provider "kubernetes" {
  host                   = "${data.aws_eks_cluster.cluster.endpoint}"
  cluster_ca_certificate = "${base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)}"
  token                  = "${data.aws_eks_cluster_auth.cluster_auth.token}"
  load_config_file       = false
}

resource "kubernetes_config_map" "aws_auth" {
  depends_on = [ "null_resource.wait_for_api_server" ]

  metadata {
    name = "aws-auth"
    namespace = "kube-system"
  }

  data {
    mapRoles = <<YAML
- rolearn: ${aws_iam_role.worker_role.arn}
  username: system:node:{{EC2PrivateDNSName}}
  groups:
    - system:bootstrappers
    - system:nodes
YAML
  }
}

## Monitor the ready status of the worker nodes
resource "null_resource" "wait_for_ready_nodes" {
  depends_on = ["kubernetes_config_map.aws_auth"]

  provisioner "local-exec" {
    command = "bash -c '${local.scriptPath} checkNodes ${data.aws_eks_cluster.cluster.endpoint} ${base64encode(data.aws_eks_cluster_auth.cluster_auth.token)}'"
  }
}
resource "null_resource" "cleanup" {
  depends_on = ["null_resource.wait_for_ready_nodes"]

  provisioner "local-exec" {
    command = "rm ${local.scriptPath}; rmdir ${local.workDir}"
  }
}
