# AWS Organizations Module for Multi-Account Foundation
# Requirements covered: 1.1, 1.2, 1.3, 1.4, 1.5

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Organization (Requirement 1.1)
resource "aws_organizations_organization" "main" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "controltower.amazonaws.com"
  ]

  feature_set = var.organization_feature_set

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
    "BACKUP_POLICY",
    "AISERVICES_OPT_OUT_POLICY"
  ]

  tags = merge(var.common_tags, {
    Name        = "Multi-Account Foundation Organization"
    Purpose     = "SaaS Security Platform"
    Environment = "foundation"
  })
}

# Security Organizational Unit (Requirement 1.3)
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = merge(var.common_tags, {
    Name        = "Security OU"
    Purpose     = "Security-focused accounts (Audit and Logging)"
    Environment = "foundation"
  })
}

# Workloads Organizational Unit (Requirement 1.3)
resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = merge(var.common_tags, {
    Name        = "Workloads OU"
    Purpose     = "Application workload accounts"
    Environment = "foundation"
  })
}

# Audit Account (Requirement 1.2)
resource "aws_organizations_account" "audit" {
  name                       = "Audit Account"
  email                      = var.audit_account_email
  role_name                  = "OrganizationAccountAccessRole"
  parent_id                  = aws_organizations_organizational_unit.security.id
  iam_user_access_to_billing = "ALLOW"

  tags = merge(var.common_tags, {
    Name        = "Audit Account"
    Purpose     = "Security auditing and compliance monitoring"
    Environment = "foundation"
    AccountType = "security"
  })

  # Lifecycle management
  lifecycle {
    prevent_destroy = true
  }
}

# Logging Account (Requirement 1.2)
resource "aws_organizations_account" "logging" {
  name                       = "Logging Account"
  email                      = var.logging_account_email
  role_name                  = "OrganizationAccountAccessRole"
  parent_id                  = aws_organizations_organizational_unit.security.id
  iam_user_access_to_billing = "ALLOW"

  tags = merge(var.common_tags, {
    Name        = "Logging Account"
    Purpose     = "Centralized logging and monitoring"
    Environment = "foundation"
    AccountType = "security"
  })

  # Lifecycle management
  lifecycle {
    prevent_destroy = true
  }
}

# Workload Account (Requirement 1.2)
resource "aws_organizations_account" "workload" {
  name                       = "Workload Account"
  email                      = var.workload_account_email
  role_name                  = "OrganizationAccountAccessRole"
  parent_id                  = aws_organizations_organizational_unit.workloads.id
  iam_user_access_to_billing = "ALLOW"

  tags = merge(var.common_tags, {
    Name        = "Workload Account"
    Purpose     = "Multi-tenant SaaS application infrastructure"
    Environment = "foundation"
    AccountType = "workload"
  })

  # Lifecycle management
  lifecycle {
    prevent_destroy = true
  }
}

# IAM Role for Organization Management
resource "aws_iam_role" "organization_management" {
  name = "OrganizationManagementRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
          NumericLessThan = {
            "aws:MultiFactorAuthAge" = "3600"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "Organization Management Role"
    Purpose     = "Cross-account organization management"
    Environment = "foundation"
  })
}

# IAM Policy for Organization Management Role
resource "aws_iam_role_policy" "organization_management" {
  name = "OrganizationManagementPolicy"
  role = aws_iam_role.organization_management.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "organizations:*",
          "account:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::${aws_organizations_account.audit.id}:role/OrganizationAccountAccessRole",
          "arn:aws:iam::${aws_organizations_account.logging.id}:role/OrganizationAccountAccessRole",
          "arn:aws:iam::${aws_organizations_account.workload.id}:role/OrganizationAccountAccessRole"
        ]
      }
    ]
  })
}

# Attach AWS managed policy for Organizations service trust
resource "aws_iam_role_policy_attachment" "organization_service_trust" {
  role       = aws_iam_role.organization_management.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/OrganizationsServiceTrustPolicy"
}

# CloudTrail S3 Bucket (Optional - for organization-wide logging)
resource "aws_s3_bucket" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = "organization-cloudtrail-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  tags = merge(var.common_tags, {
    Name        = "Organization CloudTrail Bucket"
    Purpose     = "Organization-wide audit logging"
    Environment = "foundation"
  })

  # Lifecycle management
  lifecycle {
    prevent_destroy = true
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    id     = "delete_old_logs"
    status = "Enabled"

    expiration {
      days = 2555  # 7 years retention
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# S3 Bucket Policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailOrganizationWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# Organization CloudTrail
resource "aws_cloudtrail" "organization" {
  count                         = var.enable_cloudtrail ? 1 : 0
  name                          = "OrganizationCloudTrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail[0].bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  is_organization_trail         = true

  event_selector {
    read_write_type                 = "All"
    include_management_events       = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/*"]
    }
  }

  tags = merge(var.common_tags, {
    Name        = "Organization CloudTrail"
    Purpose     = "Organization-wide audit logging"
    Environment = "foundation"
  })

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}