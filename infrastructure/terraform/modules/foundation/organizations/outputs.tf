# Outputs for AWS Organizations Module

output "organization_id" {
  description = "AWS Organization ID"
  value       = aws_organizations_organization.main.id
}

output "organization_arn" {
  description = "AWS Organization ARN"
  value       = aws_organizations_organization.main.arn
}

output "organization_root_id" {
  description = "AWS Organization Root ID"
  value       = aws_organizations_organization.main.roots[0].id
}

output "organization_master_account_id" {
  description = "AWS Organization Master Account ID"
  value       = aws_organizations_organization.main.master_account_id
}

output "security_ou_id" {
  description = "Security Organizational Unit ID"
  value       = aws_organizations_organizational_unit.security.id
}

output "security_ou_arn" {
  description = "Security Organizational Unit ARN"
  value       = aws_organizations_organizational_unit.security.arn
}

output "workloads_ou_id" {
  description = "Workloads Organizational Unit ID"
  value       = aws_organizations_organizational_unit.workloads.id
}

output "workloads_ou_arn" {
  description = "Workloads Organizational Unit ARN"
  value       = aws_organizations_organizational_unit.workloads.arn
}

output "audit_account_id" {
  description = "Audit Account ID"
  value       = aws_organizations_account.audit.id
}

output "audit_account_arn" {
  description = "Audit Account ARN"
  value       = aws_organizations_account.audit.arn
}

output "logging_account_id" {
  description = "Logging Account ID"
  value       = aws_organizations_account.logging.id
}

output "logging_account_arn" {
  description = "Logging Account ARN"
  value       = aws_organizations_account.logging.arn
}

output "workload_account_id" {
  description = "Workload Account ID"
  value       = aws_organizations_account.workload.id
}

output "workload_account_arn" {
  description = "Workload Account ARN"
  value       = aws_organizations_account.workload.arn
}

output "management_account_id" {
  description = "Management Account ID (current account)"
  value       = data.aws_caller_identity.current.account_id
}

output "organization_management_role_arn" {
  description = "Organization Management Role ARN"
  value       = aws_iam_role.organization_management.arn
}

output "organization_management_role_name" {
  description = "Organization Management Role Name"
  value       = aws_iam_role.organization_management.name
}

output "cloudtrail_arn" {
  description = "Organization CloudTrail ARN"
  value       = var.enable_cloudtrail ? aws_cloudtrail.organization[0].arn : null
}

output "cloudtrail_bucket_name" {
  description = "CloudTrail S3 Bucket Name"
  value       = var.enable_cloudtrail ? aws_s3_bucket.cloudtrail[0].bucket : null
}

output "cloudtrail_bucket_arn" {
  description = "CloudTrail S3 Bucket ARN"
  value       = var.enable_cloudtrail ? aws_s3_bucket.cloudtrail[0].arn : null
}

# Account structure summary for easy reference
output "account_structure" {
  description = "Complete account structure summary"
  value = {
    organization_id = aws_organizations_organization.main.id
    management_account = {
      id   = data.aws_caller_identity.current.account_id
      name = "Management Account"
    }
    security_ou = {
      id   = aws_organizations_organizational_unit.security.id
      name = "Security"
      accounts = {
        audit = {
          id    = aws_organizations_account.audit.id
          name  = "Audit Account"
          email = aws_organizations_account.audit.email
        }
        logging = {
          id    = aws_organizations_account.logging.id
          name  = "Logging Account"
          email = aws_organizations_account.logging.email
        }
      }
    }
    workloads_ou = {
      id   = aws_organizations_organizational_unit.workloads.id
      name = "Workloads"
      accounts = {
        workload = {
          id    = aws_organizations_account.workload.id
          name  = "Workload Account"
          email = aws_organizations_account.workload.email
        }
      }
    }
  }
}

# Cross-account role information
output "cross_account_roles" {
  description = "Cross-account role information for all member accounts"
  value = {
    audit_account_role    = "arn:aws:iam::${aws_organizations_account.audit.id}:role/OrganizationAccountAccessRole"
    logging_account_role  = "arn:aws:iam::${aws_organizations_account.logging.id}:role/OrganizationAccountAccessRole"
    workload_account_role = "arn:aws:iam::${aws_organizations_account.workload.id}:role/OrganizationAccountAccessRole"
  }
}

# Consolidated billing information
output "billing_configuration" {
  description = "Consolidated billing configuration details"
  value = {
    payer_account_id = data.aws_caller_identity.current.account_id
    linked_accounts = [
      aws_organizations_account.audit.id,
      aws_organizations_account.logging.id,
      aws_organizations_account.workload.id
    ]
    feature_set = aws_organizations_organization.main.feature_set
  }
}