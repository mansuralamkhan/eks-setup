# Root Module Files

## main.tf

provider "aws" {
  region = var.region
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}
module "vpc" {
  source    = "./modules/vpc"
  vpc_cidr  = var.vpc_cidr
  az_count  = var.az_count
  tags      = var.tags
  cluster_name = var.cluster_name
}

module "eks" {
  source                     = "./modules/eks"
  cluster_name               = var.cluster_name
  cluster_version            = var.cluster_version
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  public_subnet_ids       = module.vpc.public_subnet_ids
  managed_node_instance_types = var.managed_node_instance_types
  managed_node_min_size      = var.managed_node_min_size
  managed_node_max_size      = var.managed_node_max_size
  managed_node_desired_size  = var.managed_node_desired_size
  # self_managed_node_instance_type = var.self_managed_node_instance_type
  # self_managed_node_min_size      = var.self_managed_node_min_size
  # self_managed_node_max_size      = var.self_managed_node_max_size
  tags                       = var.tags
}
