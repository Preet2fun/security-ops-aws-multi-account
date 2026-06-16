#!/bin/bash

# AWS Organizations Validation Script
# This script validates the AWS Organizations setup against requirements 1.1-1.5
# Provides comprehensive validation for exam preparation and operational verification

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_REPORT="$SCRIPT_DIR/organizations-validation-report.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Initialize validation report
init_report() {
    cat > "$VALIDATION_REPORT" << EOF
{
  "validation_timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "validation_results": {
    "requirement_1_1": {"status": "pending", "description": "Organization creation"},
    "requirement_1_2": {"status": "pending", "description": "Account creation"},
    "requirement_1_3": {"status": "pending", "description": "Organizational unit structure"},
    "requirement_1_4": {"status": "pending", "description": "Account management"},
    "requirement_1_5": {"status": "pending", "description": "Consolidated billing"}
  },
  "detailed_findings": [],
  "recommendations": [],
  "overall_status": "pending"
}
EOF
}

# Update validation report
update_report() {
    local requirement="$1"
    local status="$2"
    local message="$3"
    
    # Use jq to update the report if available, otherwise use basic approach
    if command -v jq &> /dev/null; then
        local temp_file=$(mktemp)
        jq ".validation_results.${requirement}.status = \"$status\" | .validation_results.${requirement}.message = \"$message\"" "$VALIDATION_REPORT" > "$temp_file"
        mv "$temp_file" "$VALIDATION_REPORT"
    fi
}

# Add finding to report
add_finding() {
    local level="$1"
    local message="$2"
    local requirement="$3"
    
    if command -v jq &> /dev/null; then
        local temp_file=$(mktemp)
        jq ".detailed_findings += [{\"level\": \"$level\", \"message\": \"$message\", \"requirement\": \"$requirement\", \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}]" "$VALIDATION_REPORT" > "$temp_file"
        mv "$temp_file" "$VALIDATION_REPORT"
    fi
}

# Validate Requirement 1.1: Organization Creation
validate_requirement_1_1() {
    log "Validating Requirement 1.1: AWS Organizations creation..."
    
    # Check if organization exists
    if ! aws organizations describe-organization &> /dev/null; then
        error "Organization does not exist"
        update_report "requirement_1_1" "failed" "Organization not found"
        add_finding "error" "AWS Organization does not exist in management account" "1.1"
        return 1
    fi
    
    # Get organization details
    local org_info=$(aws organizations describe-organization)
    local org_id=$(echo "$org_info" | jq -r '.Organization.Id')
    local feature_set=$(echo "$org_info" | jq -r '.Organization.FeatureSet')
    local master_account=$(echo "$org_info" | jq -r '.Organization.MasterAccountId')
    
    success "Organization exists: $org_id"
    success "Master account: $master_account"
    success "Feature set: $feature_set"
    
    # Validate feature set
    if [[ "$feature_set" == "ALL" ]]; then
        success "All features enabled (Requirement 1.2 satisfied)"
        update_report "requirement_1_1" "passed" "Organization created with all features enabled"
        add_finding "info" "Organization $org_id created successfully with all features" "1.1"
    else
        warning "Organization has limited features: $feature_set"
        update_report "requirement_1_1" "warning" "Organization exists but may not have all features"
        add_finding "warning" "Organization feature set is $feature_set, should be ALL" "1.1"
    fi
    
    return 0
}

# Validate Requirement 1.2: Account Creation
validate_requirement_1_2() {
    log "Validating Requirement 1.2: Account creation..."
    
    # Get all accounts
    local accounts=$(aws organizations list-accounts)
    local account_count=$(echo "$accounts" | jq '.Accounts | length')
    
    log "Total accounts in organization: $account_count"
    
    # Expected accounts (minimum 4: Management + Audit + Logging + Workload)
    local expected_accounts=("Management" "Audit" "Logging" "Workload")
    local found_accounts=()
    
    # Check for each expected account type
    while IFS= read -r account; do
        local account_name=$(echo "$account" | jq -r '.Name')
        local account_id=$(echo "$account" | jq -r '.Id')
        local account_status=$(echo "$account" | jq -r '.Status')
        
        log "Account: $account_name ($account_id) - Status: $account_status"
        
        # Categorize accounts
        if [[ "$account_name" == *"Audit"* ]] || [[ "$account_name" == *"audit"* ]]; then
            found_accounts+=("Audit")
            success "Audit account found: $account_name ($account_id)"
        elif [[ "$account_name" == *"Logging"* ]] || [[ "$account_name" == *"logging"* ]]; then
            found_accounts+=("Logging")
            success "Logging account found: $account_name ($account_id)"
        elif [[ "$account_name" == *"Workload"* ]] || [[ "$account_name" == *"workload"* ]]; then
            found_accounts+=("Workload")
            success "Workload account found: $account_name ($account_id)"
        fi
        
        # Validate account status
        if [[ "$account_status" != "ACTIVE" ]]; then
            warning "Account $account_name is not active: $account_status"
            add_finding "warning" "Account $account_name status is $account_status" "1.2"
        fi
        
    done < <(echo "$accounts" | jq -c '.Accounts[]')
    
    # Check if we have the minimum required accounts
    if [[ ${#found_accounts[@]} -ge 3 ]]; then
        success "Required accounts found: ${found_accounts[*]}"
        update_report "requirement_1_2" "passed" "All required accounts created"
        add_finding "info" "Found ${#found_accounts[@]} specialized accounts" "1.2"
    else
        error "Missing required accounts. Found: ${found_accounts[*]}"
        update_report "requirement_1_2" "failed" "Missing required accounts"
        add_finding "error" "Only found ${#found_accounts[@]} specialized accounts, need at least 3" "1.2"
        return 1
    fi
    
    return 0
}

# Validate Requirement 1.3: Organizational Unit Structure
validate_requirement_1_3() {
    log "Validating Requirement 1.3: Organizational unit structure..."
    
    # Get root ID
    local root_id=$(aws organizations list-roots --query 'Roots[0].Id' --output text)
    log "Organization root ID: $root_id"
    
    # Get organizational units
    local ous=$(aws organizations list-organizational-units-for-parent --parent-id "$root_id")
    local ou_count=$(echo "$ous" | jq '.OrganizationalUnits | length')
    
    log "Number of organizational units: $ou_count"
    
    # Expected OUs
    local expected_ous=("Security" "Workloads")
    local found_ous=()
    
    # Check each OU
    while IFS= read -r ou; do
        local ou_name=$(echo "$ou" | jq -r '.Name')
        local ou_id=$(echo "$ou" | jq -r '.Id')
        
        log "Organizational Unit: $ou_name ($ou_id)"
        found_ous+=("$ou_name")
        
        # Validate OU structure
        if [[ "$ou_name" == "Security" ]]; then
            success "Security OU found: $ou_id"
            
            # Check accounts in Security OU
            local security_accounts=$(aws organizations list-accounts-for-parent --parent-id "$ou_id")
            local security_account_count=$(echo "$security_accounts" | jq '.Accounts | length')
            log "Accounts in Security OU: $security_account_count"
            
        elif [[ "$ou_name" == "Workloads" ]]; then
            success "Workloads OU found: $ou_id"
            
            # Check accounts in Workloads OU
            local workload_accounts=$(aws organizations list-accounts-for-parent --parent-id "$ou_id")
            local workload_account_count=$(echo "$workload_accounts" | jq '.Accounts | length')
            log "Accounts in Workloads OU: $workload_account_count"
        fi
        
    done < <(echo "$ous" | jq -c '.OrganizationalUnits[]')
    
    # Validate OU structure
    local security_found=false
    local workloads_found=false
    
    for ou in "${found_ous[@]}"; do
        if [[ "$ou" == "Security" ]]; then
            security_found=true
        elif [[ "$ou" == "Workloads" ]]; then
            workloads_found=true
        fi
    done
    
    if [[ "$security_found" == true ]] && [[ "$workloads_found" == true ]]; then
        success "Required organizational unit structure found"
        update_report "requirement_1_3" "passed" "Security and Workloads OUs created"
        add_finding "info" "Organizational unit structure matches requirements" "1.3"
    else
        error "Missing required organizational units. Found: ${found_ous[*]}"
        update_report "requirement_1_3" "failed" "Missing required OUs"
        add_finding "error" "Missing Security or Workloads OU" "1.3"
        return 1
    fi
    
    return 0
}

# Validate Requirement 1.4: Account Management
validate_requirement_1_4() {
    log "Validating Requirement 1.4: Account management capabilities..."
    
    # Test cross-account role access
    local accounts=$(aws organizations list-accounts --query 'Accounts[?Name!=`Management Account`]')
    local cross_account_success=0
    local cross_account_total=0
    
    while IFS= read -r account; do
        local account_id=$(echo "$account" | jq -r '.Id')
        local account_name=$(echo "$account" | jq -r '.Name')
        
        # Skip management account
        local current_account=$(aws sts get-caller-identity --query Account --output text)
        if [[ "$account_id" == "$current_account" ]]; then
            continue
        fi
        
        cross_account_total=$((cross_account_total + 1))
        
        # Test assume role capability
        local role_arn="arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole"
        
        log "Testing cross-account access to $account_name ($account_id)..."
        
        if aws sts assume-role --role-arn "$role_arn" --role-session-name "validation-test" &> /dev/null; then
            success "Cross-account access successful: $account_name"
            cross_account_success=$((cross_account_success + 1))
        else
            warning "Cross-account access failed: $account_name"
            add_finding "warning" "Cannot assume OrganizationAccountAccessRole in $account_name" "1.4"
        fi
        
    done < <(echo "$accounts" | jq -c '.[]')
    
    # Evaluate cross-account access results
    if [[ $cross_account_success -eq $cross_account_total ]] && [[ $cross_account_total -gt 0 ]]; then
        success "Cross-account access working for all accounts ($cross_account_success/$cross_account_total)"
        update_report "requirement_1_4" "passed" "Cross-account access configured correctly"
        add_finding "info" "Cross-account access successful for all member accounts" "1.4"
    elif [[ $cross_account_success -gt 0 ]]; then
        warning "Cross-account access partially working ($cross_account_success/$cross_account_total)"
        update_report "requirement_1_4" "warning" "Some cross-account access issues"
        add_finding "warning" "Cross-account access working for $cross_account_success of $cross_account_total accounts" "1.4"
    else
        error "Cross-account access not working"
        update_report "requirement_1_4" "failed" "Cross-account access not configured"
        add_finding "error" "Cross-account access failed for all accounts" "1.4"
        return 1
    fi
    
    return 0
}

# Validate Requirement 1.5: Consolidated Billing
validate_requirement_1_5() {
    log "Validating Requirement 1.5: Consolidated billing configuration..."
    
    # Check organization feature set (consolidated billing requires ALL features)
    local feature_set=$(aws organizations describe-organization --query 'Organization.FeatureSet' --output text)
    
    if [[ "$feature_set" == "ALL" ]]; then
        success "Consolidated billing enabled (ALL features)"
        
        # Get billing information
        local master_account=$(aws organizations describe-organization --query 'Organization.MasterAccountId' --output text)
        local account_count=$(aws organizations list-accounts --query 'length(Accounts)' --output text)
        
        success "Payer account: $master_account"
        success "Total accounts for billing: $account_count"
        
        # Check if we can access billing information
        if aws organizations list-accounts --query 'Accounts[].{Id:Id,Name:Name}' --output table &> /dev/null; then
            success "Billing account information accessible"
            update_report "requirement_1_5" "passed" "Consolidated billing configured"
            add_finding "info" "Consolidated billing active for $account_count accounts" "1.5"
        else
            warning "Cannot access detailed billing information"
            update_report "requirement_1_5" "warning" "Billing access limited"
            add_finding "warning" "Limited access to billing information" "1.5"
        fi
        
    else
        error "Consolidated billing not fully enabled (feature set: $feature_set)"
        update_report "requirement_1_5" "failed" "Consolidated billing not enabled"
        add_finding "error" "Organization feature set is $feature_set, consolidated billing requires ALL" "1.5"
        return 1
    fi
    
    return 0
}

# Generate summary report
generate_summary() {
    log "Generating validation summary..."
    
    # Count results
    local passed=0
    local failed=0
    local warnings=0
    
    # Check each requirement (basic approach without jq dependency)
    for req in "requirement_1_1" "requirement_1_2" "requirement_1_3" "requirement_1_4" "requirement_1_5"; do
        if grep -q "\"$req\".*\"passed\"" "$VALIDATION_REPORT" 2>/dev/null; then
            passed=$((passed + 1))
        elif grep -q "\"$req\".*\"failed\"" "$VALIDATION_REPORT" 2>/dev/null; then
            failed=$((failed + 1))
        elif grep -q "\"$req\".*\"warning\"" "$VALIDATION_REPORT" 2>/dev/null; then
            warnings=$((warnings + 1))
        fi
    done
    
    echo
    echo "=========================================="
    echo "AWS ORGANIZATIONS VALIDATION SUMMARY"
    echo "=========================================="
    echo "Passed: $passed"
    echo "Failed: $failed"
    echo "Warnings: $warnings"
    echo "Total Requirements: 5"
    echo
    
    if [[ $failed -eq 0 ]]; then
        if [[ $warnings -eq 0 ]]; then
            success "All requirements validated successfully!"
            echo "Status: FULLY COMPLIANT"
        else
            warning "Validation completed with warnings"
            echo "Status: COMPLIANT WITH WARNINGS"
        fi
    else
        error "Validation failed for $failed requirements"
        echo "Status: NON-COMPLIANT"
    fi
    
    echo
    echo "Detailed report saved to: $VALIDATION_REPORT"
    echo "=========================================="
}

# Main validation function
main() {
    log "Starting AWS Organizations validation..."
    
    # Check prerequisites
    if ! command -v aws &> /dev/null; then
        error "AWS CLI not found. Please install AWS CLI."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured or invalid."
        exit 1
    fi
    
    # Initialize report
    init_report
    
    # Run validations
    local overall_success=true
    
    validate_requirement_1_1 || overall_success=false
    validate_requirement_1_2 || overall_success=false
    validate_requirement_1_3 || overall_success=false
    validate_requirement_1_4 || overall_success=false
    validate_requirement_1_5 || overall_success=false
    
    # Generate summary
    generate_summary
    
    # Exit with appropriate code
    if [[ "$overall_success" == true ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"