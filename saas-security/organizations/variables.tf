# Variables for AWS Organizations Module

variable "organization_feature_set" {
  description = "Feature set for the AWS Organization"
  type        = string
  default     = "ALL"
  validation {
    condition     = contains(["ALL", "CONSOLIDATED_BILLING"], var.organization_feature_set)
    error_message = "Organization feature set must be either 'ALL' or 'CONSOLIDATED_BILLING'."
  }
}

variable "audit_account_email" {
  description = "Email address for the Audit Account (must be unique across all AWS accounts)"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.audit_account_email))
    error_message = "Audit account email must be a valid email address."
  }
}

variable "logging_account_email" {
  description = "Email address for the Logging Account (must be unique across all AWS accounts)"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.logging_account_email))
    error_message = "Logging account email must be a valid email address."
  }
}

variable "workload_account_email" {
  description = "Email address for the Workload Account (must be unique across all AWS accounts)"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.workload_account_email))
    error_message = "Workload account email must be a valid email address."
  }
}

variable "enable_cloudtrail" {
  description = "Enable organization-wide CloudTrail logging"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project             = "Multi-Account-Foundation"
    Owner               = "Security-Team"
    Environment         = "Foundation"
    CostCenter          = "Security"
    SecurityClassification = "Internal"
    ComplianceFramework = "SOC2,ISO27001"
    BackupRequired      = "true"
    IncidentResponse    = "critical"
  }
}

variable "cloudtrail_retention_days" {
  description = "Number of days to retain CloudTrail logs"
  type        = number
  default     = 2555  # 7 years
  validation {
    condition     = var.cloudtrail_retention_days >= 90
    error_message = "CloudTrail retention must be at least 90 days for compliance requirements."
  }
}

variable "organization_name" {
  description = "Name for the organization (used in resource naming)"
  type        = string
  default     = "SaaS-Security-Platform"
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.organization_name))
    error_message = "Organization name must contain only alphanumeric characters and hyphens."
  }
}