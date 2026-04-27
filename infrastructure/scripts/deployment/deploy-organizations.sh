#!/bin/bash

# AWS Organizations Deployment Script
# This script deploys the AWS Organizations foundation using either CloudFormation or Terraform
# Requirements covered: 1.1, 1.2, 1.3, 1.4, 1.5

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DEPLOYMENT_METHOD="${1:-terraform}"  # Default to terraform, can be 'cloudformation' or 'terraform'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials are not configured or invalid."
        exit 1
    fi
    
    # Check if we're in the management account (should not have existing organization)
    CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    log "Current AWS Account: $CURRENT_ACCOUNT"
    
    # Check if organization already exists
    if aws organizations describe-organization &> /dev/null; then
        warning "AWS Organization already exists in this account."
        read -p "Do you want to continue? This may update existing resources. (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Deployment cancelled by user."
            exit 0
        fi
    fi
    
    success "Prerequisites check completed."
}

# Validate email addresses
validate_emails() {
    log "Validating email addresses..."
    
    if [[ -z "$AUDIT_ACCOUNT_EMAIL" ]]; then
        error "AUDIT_ACCOUNT_EMAIL environment variable is required."
        exit 1
    fi
    
    if [[ -z "$LOGGING_ACCOUNT_EMAIL" ]]; then
        error "LOGGING_ACCOUNT_EMAIL environment variable is required."
        exit 1
    fi
    
    if [[ -z "$WORKLOAD_ACCOUNT_EMAIL" ]]; then
        error "WORKLOAD_ACCOUNT_EMAIL environment variable is required."
        exit 1
    fi
    
    # Basic email validation
    email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if [[ ! $AUDIT_ACCOUNT_EMAIL =~ $email_regex ]]; then
        error "Invalid audit account email format: $AUDIT_ACCOUNT_EMAIL"
        exit 1
    fi
    
    if [[ ! $LOGGING_ACCOUNT_EMAIL =~ $email_regex ]]; then
        error "Invalid logging account email format: $LOGGING_ACCOUNT_EMAIL"
        exit 1
    fi
    
    if [[ ! $WORKLOAD_ACCOUNT_EMAIL =~ $email_regex ]]; then
        error "Invalid workload account email format: $WORKLOAD_ACCOUNT_EMAIL"
        exit 1
    fi
    
    success "Email validation completed."
}

# Deploy using CloudFormation
deploy_cloudformation() {
    log "Deploying AWS Organizations using CloudFormation..."
    
    local template_path="$PROJECT_ROOT/infrastructure/cloudformation/templates/foundation/organizations.yaml"
    local stack_name="multi-account-foundation-organizations"
    
    if [[ ! -f "$template_path" ]]; then
        error "CloudFormation template not found: $template_path"
        exit 1
    fi
    
    # Deploy the stack
    aws cloudformation deploy \
        --template-file "$template_path" \
        --stack-name "$stack_name" \
        --parameter-overrides \
            AuditAccountEmail="$AUDIT_ACCOUNT_EMAIL" \
            LoggingAccountEmail="$LOGGING_ACCOUNT_EMAIL" \
            WorkloadAccountEmail="$WORKLOAD_ACCOUNT_EMAIL" \
            OrganizationFeatureSet="ALL" \
            EnableCloudTrail="true" \
        --capabilities CAPABILITY_IAM \
        --tags \
            Project="Multi-Account-Foundation" \
            Owner="Security-Team" \
            Environment="Foundation" \
            DeploymentMethod="CloudFormation"
    
    if [[ $? -eq 0 ]]; then
        success "CloudFormation deployment completed successfully."
        
        # Get stack outputs
        log "Retrieving stack outputs..."
        aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --query 'Stacks[0].Outputs' \
            --output table
    else
        error "CloudFormation deployment failed."
        exit 1
    fi
}

# Deploy using Terraform
deploy_terraform() {
    log "Deploying AWS Organizations using Terraform..."
    
    local terraform_dir="$PROJECT_ROOT/infrastructure/terraform/environments/foundation"
    
    # Create terraform environment directory if it doesn't exist
    mkdir -p "$terraform_dir"
    
    # Create main.tf for the environment
    cat > "$terraform_dir/main.tf" << EOF
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project             = "Multi-Account-Foundation"
      Owner               = "Security-Team"
      Environment         = "Foundation"
      DeploymentMethod    = "Terraform"
      SecurityClassification = "Internal"
    }
  }
}

module "organizations" {
  source = "../../modules/foundation/organizations"
  
  audit_account_email    = var.audit_account_email
  logging_account_email  = var.logging_account_email
  workload_account_email = var.workload_account_email
  enable_cloudtrail      = var.enable_cloudtrail
  organization_name      = var.organization_name
  
  common_tags = var.common_tags
}
EOF

    # Create variables.tf
    cat > "$terraform_dir/variables.tf" << EOF
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "audit_account_email" {
  description = "Email for audit account"
  type        = string
}

variable "logging_account_email" {
  description = "Email for logging account"
  type        = string
}

variable "workload_account_email" {
  description = "Email for workload account"
  type        = string
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail"
  type        = bool
  default     = true
}

variable "organization_name" {
  description = "Organization name"
  type        = string
  default     = "SaaS-Security-Platform"
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default = {
    Project             = "Multi-Account-Foundation"
    Owner               = "Security-Team"
    Environment         = "Foundation"
    CostCenter          = "Security"
    SecurityClassification = "Internal"
  }
}
EOF

    # Create outputs.tf
    cat > "$terraform_dir/outputs.tf" << EOF
output "organization_structure" {
  description = "Complete organization structure"
  value       = module.organizations.account_structure
}

output "cross_account_roles" {
  description = "Cross-account role ARNs"
  value       = module.organizations.cross_account_roles
}

output "billing_configuration" {
  description = "Billing configuration"
  value       = module.organizations.billing_configuration
}
EOF

    # Create terraform.tfvars
    cat > "$terraform_dir/terraform.tfvars" << EOF
audit_account_email    = "$AUDIT_ACCOUNT_EMAIL"
logging_account_email  = "$LOGGING_ACCOUNT_EMAIL"
workload_account_email = "$WORKLOAD_ACCOUNT_EMAIL"
enable_cloudtrail      = true
organization_name      = "SaaS-Security-Platform"
EOF

    # Change to terraform directory
    cd "$terraform_dir"
    
    # Initialize Terraform
    log "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    log "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    # Apply deployment
    log "Applying Terraform deployment..."
    terraform apply tfplan
    
    if [[ $? -eq 0 ]]; then
        success "Terraform deployment completed successfully."
        
        # Show outputs
        log "Terraform outputs:"
        terraform output
    else
        error "Terraform deployment failed."
        exit 1
    fi
}

# Validate deployment
validate_deployment() {
    log "Validating deployment..."
    
    # Check organization exists
    if ! aws organizations describe-organization &> /dev/null; then
        error "Organization validation failed - organization does not exist."
        return 1
    fi
    
    local org_id=$(aws organizations describe-organization --query 'Organization.Id' --output text)
    success "Organization exists: $org_id"
    
    # Check organizational units
    local root_id=$(aws organizations list-roots --query 'Roots[0].Id' --output text)
    local ous=$(aws organizations list-organizational-units-for-parent --parent-id "$root_id" --query 'OrganizationalUnits[].Name' --output text)
    
    if [[ "$ous" == *"Security"* ]] && [[ "$ous" == *"Workloads"* ]]; then
        success "Organizational units created successfully: $ous"
    else
        error "Organizational units validation failed. Expected: Security, Workloads. Found: $ous"
        return 1
    fi
    
    # Check accounts
    local accounts=$(aws organizations list-accounts --query 'Accounts[].Name' --output text)
    log "Accounts in organization: $accounts"
    
    # Check consolidated billing
    if aws organizations describe-organization --query 'Organization.FeatureSet' --output text | grep -q "ALL"; then
        success "All features enabled (including consolidated billing)"
    else
        warning "Organization may not have all features enabled"
    fi
    
    success "Deployment validation completed successfully."
}

# Main execution
main() {
    log "Starting AWS Organizations deployment..."
    log "Deployment method: $DEPLOYMENT_METHOD"
    
    # Check if required environment variables are set
    if [[ -z "$AUDIT_ACCOUNT_EMAIL" ]] || [[ -z "$LOGGING_ACCOUNT_EMAIL" ]] || [[ -z "$WORKLOAD_ACCOUNT_EMAIL" ]]; then
        error "Required environment variables not set. Please set:"
        error "  AUDIT_ACCOUNT_EMAIL"
        error "  LOGGING_ACCOUNT_EMAIL"
        error "  WORKLOAD_ACCOUNT_EMAIL"
        echo
        echo "Example:"
        echo "  export AUDIT_ACCOUNT_EMAIL='audit@example.com'"
        echo "  export LOGGING_ACCOUNT_EMAIL='logging@example.com'"
        echo "  export WORKLOAD_ACCOUNT_EMAIL='workload@example.com'"
        exit 1
    fi
    
    check_prerequisites
    validate_emails
    
    case "$DEPLOYMENT_METHOD" in
        "cloudformation"|"cf")
            deploy_cloudformation
            ;;
        "terraform"|"tf")
            deploy_terraform
            ;;
        *)
            error "Invalid deployment method: $DEPLOYMENT_METHOD"
            error "Supported methods: cloudformation, terraform"
            exit 1
            ;;
    esac
    
    validate_deployment
    
    success "AWS Organizations deployment completed successfully!"
    log "Next steps:"
    log "1. Deploy AWS Control Tower (Task 2)"
    log "2. Implement Service Control Policies (Task 3)"
    log "3. Configure cross-account IAM roles (Task 4)"
}

# Show usage if no arguments provided
if [[ $# -eq 0 ]] && [[ -z "$AUDIT_ACCOUNT_EMAIL" ]]; then
    echo "Usage: $0 [cloudformation|terraform]"
    echo
    echo "Environment variables required:"
    echo "  AUDIT_ACCOUNT_EMAIL    - Email for audit account"
    echo "  LOGGING_ACCOUNT_EMAIL  - Email for logging account"
    echo "  WORKLOAD_ACCOUNT_EMAIL - Email for workload account"
    echo
    echo "Example:"
    echo "  export AUDIT_ACCOUNT_EMAIL='audit@example.com'"
    echo "  export LOGGING_ACCOUNT_EMAIL='logging@example.com'"
    echo "  export WORKLOAD_ACCOUNT_EMAIL='workload@example.com'"
    echo "  $0 terraform"
    exit 1
fi

# Run main function
main "$@"