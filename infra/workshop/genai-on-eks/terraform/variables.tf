################################################################################
# Variables for GenAI Workshop Infrastructure
################################################################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "genai-workshop"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.34"
}

variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = null # Will use current region from data source
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for cost optimization"
  type        = bool
  default     = true
}

variable "s3_bucket_prefix" {
  description = "Prefix for S3 bucket name (will be suffixed with account ID)"
  type        = string
  default     = "genai-models"
}

variable "model_storage_size" {
  description = "Size of the model storage PV"
  type        = string
  default     = "20Gi"
}

variable "model_prefix" {
  description = "S3 prefix for model files"
  type        = string
  default     = "mistral-7b-v0-3/"
}

variable "default_node_instance_types" {
  description = "Instance types for default node group"
  type        = list(string)
  default     = ["m5.xlarge"]
}

variable "default_node_min_size" {
  description = "Minimum size for default node group"
  type        = number
  default     = 2
}

variable "default_node_max_size" {
  description = "Maximum size for default node group"
  type        = number
  default     = 3
}

variable "default_node_desired_size" {
  description = "Desired size for default node group"
  type        = number
  default     = 2
}

variable "gpu_instance_types" {
  description = "Instance types for GPU nodes"
  type        = list(string)
  default     = ["g6e.2xlarge"]
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Enable admin permissions for cluster creator"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to cluster endpoint"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  default     = "notforproductionuse"
  sensitive   = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "workshop"
    Project     = "genai-workshop"
    ManagedBy   = "terraform"
  }
}