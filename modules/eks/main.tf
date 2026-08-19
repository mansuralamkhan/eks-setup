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
    public_access_cidrs = ["223.237.162.20/32"]
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
