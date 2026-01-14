################################################################################
# Terraform Outputs for GenAI Workshop Infrastructure
################################################################################

################################################################################
# S3 Model Storage Outputs
################################################################################

output "s3_bucket_name" {
  description = "Name of the S3 bucket for model storage"
  value       = aws_s3_bucket.model_storage.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for model storage"
  value       = aws_s3_bucket.model_storage.arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.model_storage.bucket_domain_name
}

output "s3_bucket_region" {
  description = "Region of the S3 bucket for model storage"
  value       = aws_s3_bucket.model_storage.region
}

################################################################################
# IAM Role and Policy Outputs
################################################################################

output "model_storage_role_arn" {
  description = "ARN of the IAM role for model storage"
  value       = aws_iam_role.model_storage_role.arn
}

output "model_storage_role_name" {
  description = "Name of the IAM role for model storage"
  value       = aws_iam_role.model_storage_role.name
}

output "model_storage_policy_arn" {
  description = "ARN of the IAM policy for model storage"
  value       = aws_iam_policy.model_storage_policy.arn
}

################################################################################
# S3 CSI Driver IAM Outputs
################################################################################

output "s3_csi_driver_role_arn" {
  description = "ARN of the IAM role for S3 CSI driver"
  value       = aws_iam_role.s3_csi_driver_role.arn
}

output "s3_csi_driver_role_name" {
  description = "Name of the IAM role for S3 CSI driver"
  value       = aws_iam_role.s3_csi_driver_role.name
}

output "s3_csi_driver_policy_arn" {
  description = "ARN of the IAM policy for S3 CSI driver"
  value       = aws_iam_policy.s3_csi_driver_policy.arn
}

################################################################################
# Kubernetes Service Account Outputs
################################################################################

output "service_account_name" {
  description = "Name of the Kubernetes service account for model storage"
  value       = "model-storage-sa"
}

output "service_account_namespace" {
  description = "Namespace of the Kubernetes service account for model storage"
  value       = "default"
}

################################################################################
# EKS Pod Identity Association Outputs
################################################################################

output "pod_identity_association_arn" {
  description = "ARN of the Pod Identity association for model storage"
  value       = aws_eks_pod_identity_association.model_storage.association_arn
}

output "pod_identity_association_id" {
  description = "ID of the Pod Identity association for model storage"
  value       = aws_eks_pod_identity_association.model_storage.association_id
}

output "s3_csi_pod_identity_association_arn" {
  description = "ARN of the Pod Identity association for S3 CSI driver"
  value       = aws_eks_pod_identity_association.s3_csi_driver.association_arn
}

output "s3_csi_pod_identity_association_id" {
  description = "ID of the Pod Identity association for S3 CSI driver"
  value       = aws_eks_pod_identity_association.s3_csi_driver.association_id
}

################################################################################
# EKS Cluster Outputs (for reference)
################################################################################

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.eks.cluster_version
}

################################################################################
# VPC Outputs (for reference)
################################################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}



################################################################################
# Monitoring and Access Outputs
################################################################################

output "grafana_url" {
  description = "URL to access Grafana (requires port-forward)"
  value       = "http://localhost:3000 (kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80)"
}

output "grafana_admin_user" {
  description = "Grafana admin username"
  value       = "admin"
}

################################################################################
# IAM Configuration Summary
################################################################################

output "iam_configuration_summary" {
  description = "Summary of IAM roles and policies for troubleshooting"
  value = {
    model_storage = {
      role_name        = aws_iam_role.model_storage_role.name
      role_arn         = aws_iam_role.model_storage_role.arn
      policy_arn       = aws_iam_policy.model_storage_policy.arn
      service_account  = "model-storage-sa"
      namespace        = "default"
      pod_identity_arn = aws_eks_pod_identity_association.model_storage.association_arn
    }
    s3_csi_driver = {
      role_name        = aws_iam_role.s3_csi_driver_role.name
      role_arn         = aws_iam_role.s3_csi_driver_role.arn
      policy_arn       = aws_iam_policy.s3_csi_driver_policy.arn
      service_account  = "s3-csi-driver-sa"
      namespace        = "kube-system"
      pod_identity_arn = aws_eks_pod_identity_association.s3_csi_driver.association_arn
    }
  }
}

################################################################################
# Useful Commands
################################################################################

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${local.region} --name ${module.eks.cluster_name}"
}

output "s3_model_upload_command" {
  description = "Example command to upload models to S3"
  value       = "aws s3 cp /path/to/model/ s3://${aws_s3_bucket.model_storage.bucket}/${var.model_prefix} --recursive"
}

output "port_forward_vllm_command" {
  description = "Command to port-forward to vLLM service"
  value       = "kubectl port-forward svc/vllm-serve-svc 8000:8000"
}

################################################################################
# Region and Account Info
################################################################################

output "region" {
  description = "AWS region where resources are deployed"
  value       = local.region
}

output "account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

################################################################################
# Quick Start Summary
################################################################################

output "deployment_summary" {
  description = "Summary of deployed workshop infrastructure"
  value = {
    cluster_name = module.eks.cluster_name
    s3_bucket    = aws_s3_bucket.model_storage.bucket
    region = local.region
  }
}
