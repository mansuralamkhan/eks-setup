data "aws_ami" "eks_worker" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amazon-eks-node-al2023-x86_64-standard-${var.cluster_version}-*"]
  }
}

resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
# resource "aws_security_group_rule" "cluster_ingress_from_self_managed" {
#   type                     = "ingress"
#   from_port                = 443
#   to_port                  = 443
#   protocol                 = "tcp"
#   security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
#   source_security_group_id = aws_security_group.self_managed_nodes.id
#   description               = "allow self-managed nodes to reach the control plane"
# }
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids         = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_public_access = true
    endpoint_private_access = true
    public_access_cidrs = ["0.0.0.0/0"]
  }
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
    }
  })

  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS cluster ${var.cluster_name}"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_iam_role" "managed_node_group" {
  name = "${var.cluster_name}-managed-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "managed_node_group_policy" {
  for_each = {
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  role       = aws_iam_role.managed_node_group.name
  policy_arn = each.value
}
resource "aws_launch_template" "managed_nodes" {
  name_prefix = "${var.cluster_name}-managed-lt-"
  image_id    = data.aws_ami.eks_worker.id

  user_data = base64encode(<<-EOT
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${aws_eks_cluster.this.name}
    apiServerEndpoint: ${aws_eks_cluster.this.endpoint}
    certificateAuthority: ${aws_eks_cluster.this.certificate_authority[0].data}
    cidr: ${aws_eks_cluster.this.kubernetes_network_config[0].service_ipv4_cidr}
  kubelet:
    config:
      maxPods: 300
EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, { Name = "${var.cluster_name}-managed-node" })
  }
}


resource "aws_eks_node_group" "managed" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-managed-ng"
  node_role_arn   = aws_iam_role.managed_node_group.arn
  subnet_ids      = var.private_subnet_ids

  

  scaling_config {
    desired_size = var.managed_node_desired_size
    max_size     = var.managed_node_max_size
    min_size     = var.managed_node_min_size
  }

  instance_types = var.managed_node_instance_types
  launch_template {
    id      = aws_launch_template.managed_nodes.id
    version = "$Latest"
  }

  tags = var.tags


  depends_on = [aws_eks_cluster.this, aws_iam_role_policy_attachment.managed_node_group_policy]
}


# resource "aws_eks_access_entry" "self_managed_node" {
#   cluster_name  = aws_eks_cluster.this.name
#   principal_arn = aws_iam_role.self_managed_node_group.arn
#   type          = "EC2_LINUX"
# }


# resource "aws_iam_role" "self_managed_node_group" {
#   name = "${var.cluster_name}-self-managed-node-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "self_managed_node_group_policy" {
#   for_each = {
#     AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#     AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#     AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#     AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#   }

#   role       = aws_iam_role.self_managed_node_group.name
#   policy_arn = each.value
# }

# resource "aws_iam_instance_profile" "self_managed_node" {

#   name = "${var.cluster_name}-self-managed-node-profile"
#   role = aws_iam_role.self_managed_node_group.name
  
# }

# resource "aws_launch_template" "self_managed" {
#   name = "${var.cluster_name}-self-managed-lt"

#   image_id      = data.aws_ami.eks_worker.id
#   instance_type = var.self_managed_node_instance_type

#   iam_instance_profile {
#     name = aws_iam_instance_profile.self_managed_node.name
#   }

#   network_interfaces {
#     security_groups = [
#       aws_security_group.self_managed_nodes.id
#     ]
#   }

#   user_data = base64encode(<<-EOT
# apiVersion: node.eks.aws/v1alpha1
# kind: NodeConfig
# spec:
#   cluster:
#     name: ${aws_eks_cluster.this.name}
#     apiServerEndpoint: ${aws_eks_cluster.this.endpoint}
#     certificateAuthority: ${aws_eks_cluster.this.certificate_authority[0].data}
#     cidr: ${aws_eks_cluster.this.kubernetes_network_config[0].service_ipv4_cidr}
#   kubelet:
#     config:
#       maxPods: 300
#     flags:
#       - "--node-labels=node.kubernetes.io/lifecycle=self-managed"
# EOT
#   )


#   tag_specifications {
#     resource_type = "instance"
#     tags          = merge(var.tags, { Name = "${var.cluster_name}-self-managed-node" })
#   }
# }

# resource "aws_autoscaling_group" "self_managed" {
#   name                = "${var.cluster_name}-self-managed-asg"
#   desired_capacity    = var.self_managed_node_desired_size
#   max_size            = var.self_managed_node_max_size
#   min_size            = var.self_managed_node_min_size
#   vpc_zone_identifier = var.private_subnet_ids
#   health_check_type = "EC2"

#   launch_template {
#     id      = aws_launch_template.self_managed.id
#     version = "$Latest"
#   }


#   tag {
#     key                 = "kubernetes.io/cluster/${var.cluster_name}"
#     value               = "owned"
#     propagate_at_launch = true
#   }

#   depends_on = [aws_eks_cluster.this, aws_iam_role_policy_attachment.self_managed_node_group_policy]
# }

# resource "aws_security_group" "self_managed_nodes" {
#   name        = "${var.cluster_name}-self-managed-nodes"
#   description = "Security group for self-managed nodes"
#   vpc_id      = var.vpc_id

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port       = 443
#     to_port         = 443
#     protocol        = "tcp"
#     security_groups = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
#   }
#     ingress {
#     from_port       = 10250
#     to_port         = 10250
#     protocol        = "tcp"
#     security_groups = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
#     description     = "Allow EKS control plane to reach kubelet"
#   }

#   ingress {
#     from_port       = 9443
#     to_port         = 9443
#     protocol        = "tcp"
#     security_groups = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
#     description     = "Allow EKS control plane to reach AWS Load Balancer Controller webhook"
#   }

#   # EKS cluster/node networking → CoreDNS
#   ingress {
#     from_port       = 53
#     to_port         = 53
#     protocol        = "udp"
#     security_groups = [
#       aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
#     ]
#     description = "Allow DNS UDP from EKS cluster security group"
#   }

#   ingress {
#     from_port       = 53
#     to_port         = 53
#     protocol        = "tcp"
#     security_groups = [
#       aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
#     ]
#     description = "Allow DNS TCP from EKS cluster security group"
#   }



#   ingress {
#     from_port = 0
#     to_port   = 0
#     protocol  = "-1"
#     self      = true
#   }

#   tags = var.tags
# }




# --- IRSA foundation: OIDC provider ---
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]

  tags = {
    Name = "${var.cluster_name}-eks-oidc"
  }
}

# --- ALB Controller IAM role (trust policy) ---
data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "${var.cluster_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json
}

# --- ALB Controller IAM permissions (vendored AWS policy) ---
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name   = "${var.cluster_name}-alb-controller-policy"
  policy = file("${path.module}/policies/alb-controller-iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

# --- Kubernetes ServiceAccount tied to the IAM role ---
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }
}

# --- kubernetes provider auth (lives here since it references cluster resources directly) ---
data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}