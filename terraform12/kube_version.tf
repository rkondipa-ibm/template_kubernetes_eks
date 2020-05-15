## Determine kubernetes version for the cluster and worker nodes
## Query the 'aws_ami' data source to identify the appropriate
## worker node image, identified via the given 'kube_version'
## variable.  Parse the actual version number from the image
## name for use when creating/updating the aws_eks_cluster resource.
resource "null_resource" "validate-kube-version" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
regex="^latest|(([0-9]+\\.?){0,2}([0-9]+))$"
if [[ ! ${lower(var.kube_version)} =~ $regex ]]; then
    echo "Invalid kubernetes version"
    exit 1
fi
EOT

  }
}

locals {
  ami_name_without_version = var.aws_ami_name_prefix
  ami_name_with_version    = "${local.ami_name_without_version}-${var.kube_version}-v"
  version_prefix           = lower(var.kube_version) != "latest" ? local.ami_name_with_version : local.ami_name_without_version
}

data "aws_ami" "kube_version_lookup" {
  filter {
    name   = "name"
    values = ["${local.version_prefix}*"]
  }

  most_recent = true
  owners      = [var.aws_ami_owner_id] # Amazon EKS AMI Account ID
}

data "external" "get_cluster_version" {
  program = ["bash", "${path.module}/scripts/getVersion.sh"]

  query = {
    ami_image_name = data.aws_ami.kube_version_lookup.name
    version_regex  = "^${local.ami_name_without_version}.*-(([0-9]+\\.?){0,2}([0-9]+))-v.*"
  }
}

