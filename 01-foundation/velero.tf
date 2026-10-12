# ADR-009: S3 bucket and Pod Identity role for Velero resource backups.

data "aws_caller_identity" "current" {}

locals {
  velero_bucket = "${var.cluster_name}-velero-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "velero" {
  bucket = local.velero_bucket
  # Lab setting so `terraform destroy` works while backups exist. Remove for anything real.
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "velero" {
  bucket = aws_s3_bucket.velero.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "velero" {
  bucket                  = aws_s3_bucket.velero.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    filter {}

    # Velero's own TTL deletes backups after 72h; this is a safety net.
    expiration {
      days = 35
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

resource "aws_iam_role" "velero" {
  name = "${var.cluster_name}-velero"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "pods.eks.amazonaws.com" }
        Action    = ["sts:AssumeRole", "sts:TagSession"]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "velero" {
  name = "${var.cluster_name}-velero"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = "${aws_s3_bucket.velero.arn}/*"
      },
      {
        Sid      = "ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.velero.arn
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "velero" {
  role       = aws_iam_role.velero.name
  policy_arn = aws_iam_policy.velero.arn
}

resource "aws_eks_pod_identity_association" "velero" {
  cluster_name    = module.eks.cluster_name
  namespace       = "velero"
  service_account = "velero"
  role_arn        = aws_iam_role.velero.arn

  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.velero
  ]
}

output "velero_bucket" {
  description = "S3 bucket that holds Velero backups"
  value       = aws_s3_bucket.velero.bucket
}
