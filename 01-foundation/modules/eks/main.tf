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
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids         = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_public_access = true
    endpoint_private_access = true
    public_access_cidrs = ["223.185.135.110/32"]
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
# -------------------------------------------------------------------
# Karpenter node IAM role
#
# This role is assumed by EC2 instances provisioned by Karpenter.
# Karpenter itself does not use this role to call AWS APIs.
# -------------------------------------------------------------------

data "aws_iam_policy_document" "karpenter_node_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "karpenter_node" {
  name               = "${var.cluster_name}-karpenter-node"
  assume_role_policy = data.aws_iam_policy_document.karpenter_node_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_node" {
  for_each = {
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  role       = aws_iam_role.karpenter_node.name
  policy_arn = each.value
}

# -------------------------------------------------------------------
# Karpenter controller IAM role
#
# This role is assumed by the Karpenter controller running in the
# Kubernetes cluster. It is separate from the EC2 node role.
# -------------------------------------------------------------------

resource "aws_iam_role" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
                {
        Sid    = "AllowScopedEC2InstanceAccessActions"
        Effect = "Allow"

        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet"
        ]

        Resource = [
          "arn:aws:ec2:ap-south-1::image/*",
          "arn:aws:ec2:ap-south-1::snapshot/*",
          "arn:aws:ec2:ap-south-1:*:security-group/*",
          "arn:aws:ec2:ap-south-1:*:subnet/*",
          "arn:aws:ec2:ap-south-1:*:capacity-reservation/*",
          "arn:aws:ec2:ap-south-1:*:placement-group/*"
        ]
      },
      {
        Sid    = "AllowScopedEC2LaunchTemplateAccessActions"
        Effect = "Allow"

        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet"
        ]

        Resource = "arn:aws:ec2:ap-south-1:*:launch-template/*"

        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }

          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedEC2InstanceActionsWithTags"
        Effect = "Allow"

        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate"
        ]

        Resource = [
          "arn:aws:ec2:ap-south-1:*:fleet/*",
          "arn:aws:ec2:ap-south-1:*:instance/*",
          "arn:aws:ec2:ap-south-1:*:volume/*",
          "arn:aws:ec2:ap-south-1:*:network-interface/*",
          "arn:aws:ec2:ap-south-1:*:launch-template/*",
          "arn:aws:ec2:ap-south-1:*:spot-instances-request/*"
        ]

        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:RequestTag/eks:eks-cluster-name"                       = var.cluster_name
          }

          StringLike = {
            "aws:RequestTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "AllowDescribeActions"
        Effect = "Allow"

        Action = [
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstanceStatus",
          "pricing:GetProducts",
          "ssm:GetParameter",
          "eks:DescribeCluster"
        ]

        Resource = "*"
      },
      {
        Sid    = "AllowScopedInstanceProfileCreationActions"
        Effect = "Allow"

        Action = [
          "iam:CreateInstanceProfile"
        ]

        Resource = "arn:aws:iam::*:instance-profile/*"

        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:RequestTag/eks:eks-cluster-name"                       = var.cluster_name
            "aws:RequestTag/topology.kubernetes.io/region"              = "ap-south-1"
          }

          StringLike = {
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedInstanceProfileTagActions"
        Effect = "Allow"

        Action = [
          "iam:TagInstanceProfile"
        ]

        Resource = "arn:aws:iam::*:instance-profile/*"

        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region"              = "ap-south-1"
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:RequestTag/eks:eks-cluster-name"                       = var.cluster_name
            "aws:RequestTag/topology.kubernetes.io/region"              = "ap-south-1"
          }

          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"  = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedInstanceProfileActions"
        Effect = "Allow"

        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile"
        ]

        Resource = "arn:aws:iam::*:instance-profile/*"

        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region"              = "ap-south-1"
          }

          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid    = "AllowInstanceProfileReadActions"
        Effect = "Allow"

        Action = [
          "iam:GetInstanceProfile"
        ]

        Resource = "arn:aws:iam::*:instance-profile/*"
      },
      {
        Sid    = "AllowInstanceProfileListAction"
        Effect = "Allow"

        Action = [
          "iam:ListInstanceProfiles"
        ]

        Resource = "*"
      },
      {
        Sid    = "AllowPassNodeRole"
        Effect = "Allow"

        Action = [
          "iam:PassRole"
        ]

        Resource = aws_iam_role.karpenter_node.arn

        Condition = {
          StringEquals = {
            "iam:PassedToService" = [
              "ec2.amazonaws.com",
              "ec2.amazonaws.com.cn"
            ]
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "eks-pod-identity-agent"

  depends_on = [
    aws_eks_cluster.this
  ]
}

resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "karpenter"
  service_account = "karpenter"
  role_arn        = aws_iam_role.karpenter_controller.arn

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy_attachment.karpenter_controller
  ]
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

# Node architecture: one EKS managed node group for baseline capacity, plus Karpenter for
# dynamic capacity (see docs/adr/0001-node-autoscaling.md). An earlier self-managed node
# group implementation was removed; it is available in git history.

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