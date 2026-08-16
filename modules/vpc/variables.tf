variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)


}

variable "cluster_name" {
  description = "cluster_name"
  type = string
  
}