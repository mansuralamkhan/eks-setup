variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 3
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "managed_node_instance_types" {
  description = "Instance types for managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "managed_node_min_size" {
  description = "Minimum size of managed node group"
  type        = number
  default     = 1
}

variable "managed_node_max_size" {
  description = "Maximum size of managed node group"
  type        = number
  default     = 3
}

variable "managed_node_desired_size" {
  description = "Desired size of managed node group"
  type        = number
  default     = 1
}



variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {
    Environment = "production"
    Terraform   = "true"
  }
}
