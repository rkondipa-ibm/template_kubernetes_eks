locals {
  kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${aws_eks_cluster.eks_cluster.certificate_authority[0].data}
    server: ${aws_eks_cluster.eks_cluster.endpoint}
  name: ${aws_eks_cluster.eks_cluster.arn}
contexts:
- context:
    cluster: ${aws_eks_cluster.eks_cluster.arn}
    user: ${aws_eks_cluster.eks_cluster.arn}
  name: ${aws_eks_cluster.eks_cluster.arn}
current-context: ${aws_eks_cluster.eks_cluster.arn}
kind: Config
preferences: {}
users:
- name: ${aws_eks_cluster.eks_cluster.arn}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      args:
        - "token"
        - "-i"
        - "${var.cluster_name}"
      command: aws-iam-authenticator
KUBECONFIG

}

output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "cluster_config" {
  value = base64encode(local.kubeconfig)
}

output "cluster_certificate_authority" {
  value = base64encode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_region" {
  value = var.aws_region
}

