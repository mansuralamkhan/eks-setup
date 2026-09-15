variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for node groups and Fargate"
  type        = list(string)
}
variable "public_subnet_ids" {
  description = "List of public subnet IDs for node groups and Fargate"
  type        = list(string)
}

variable "managed_node_instance_types" {
  description = "Instance types for managed node group"
  type        = list(string)
  default     = ["t2.micro"]
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
  default     = 2
}

variable "self_managed_node_instance_type" {
  description = "Instance type for self-managed node group"
  type        = string
  default     = "t2.micro"
}

variable "self_managed_node_min_size" {
  description = "Minimum size of self-managed node group"
  type        = number
  default     = 1
}

variable "self_managed_node_max_size" {
  description = "Maximum size of self-managed node group"
  type        = number
  default     = 3
}

variable "self_managed_node_desired_size" {
  description = "Desired size of self-managed node group"
  type        = number
  default     = 2
}



variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}