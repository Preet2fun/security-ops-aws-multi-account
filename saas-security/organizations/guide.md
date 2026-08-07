# AWS Organizations Setup - Manual Configuration Guide

## Overview
This guide provides step-by-step instructions for setting up AWS Organizations in the management account, enabling all features, creating organizational units, and configuring consolidated billing. This implementation satisfies Requirements 1.1, 1.2, 1.3, 1.4, and 1.5 from the multi-account foundation specification.

## Prerequisites
- Access to the AWS Management Console with administrative privileges
- The account that will serve as the management (root) account
- Understanding of AWS Organizations concepts and billing implications

## Implementation Steps

### Step 1: Create AWS Organizations (Requirement 1.1)

1. **Sign in to AWS Management Console**
   - Log into the AWS account that will serve as the management account
   - Navigate to the AWS Organizations service console
   - URL: https://console.aws.amazon.com/organizations/

2. **Create Organization**
   - Click "Create organization" button
   - Choose "Create an organization with all features" (this enables advanced policy management)
   - Click "Create organization"
   - **Validation**: Verify that the organization is created and shows your current account as the management account

3. **Verify Organization Creation**
   - In the Organizations console, confirm you see:
     - Organization ID (starts with "o-")
     - Management account listed under "Accounts"
     - Root organizational unit created automatically

### Step 2: Enable All Features for Advanced Policy Management (Requirement 1.2)

1. **Verify All Features are Enabled**
   - In the Organizations console, go to "Settings"
   - Under "Organization feature set", confirm it shows "All features"
   - If it shows "Consolidated billing features only", click "Enable all features"
   - **Note**: This step is typically completed during organization creation if you selected "all features"

2. **Understand Feature Implications**
   - All features enable:
     - Service Control Policies (SCPs)
     - Tag policies
     - Backup policies
     - AI services opt-out policies
     - Account management capabilities

### Step 3: Create Organizational Unit Structure (Requirement 1.3)

1. **Create Security OU**
   - In the Organizations console, select the Root OU
   - Click "Actions" → "Create organizational unit"
   - Name: "Security"
   - Description: "Organizational unit for security-focused accounts (Audit and Logging)"
   - Click "Create organizational unit"

2. **Create Workloads OU**
   - Select the Root OU again
   - Click "Actions" → "Create organizational unit"
   - Name: "Workloads"
   - Description: "Organizational unit for application workload accounts"
   - Click "Create organizational unit"

3. **Verify OU Structure**
   - Confirm the following hierarchy exists:
     ```
     Root
     ├── Management Account (your current account)
     ├── Security OU
     └── Workloads OU
     ```

### Step 4: Create Additional Accounts (Requirements 1.2, 1.4)

1. **Create Audit Account**
   - In Organizations console, click "Add account" → "Create account"
   - Account name: "Audit Account"
   - Email: audit-account@yourdomain.com (must be unique)
   - IAM role name: OrganizationAccountAccessRole (default)
   - Click "Create account"
   - **Move to Security OU**: Select the new account → Actions → Move → Select "Security" OU

2. **Create Logging Account**
   - Click "Add account" → "Create account"
   - Account name: "Logging Account"
   - Email: logging-account@yourdomain.com (must be unique)
   - IAM role name: OrganizationAccountAccessRole (default)
   - Click "Create account"
   - **Move to Security OU**: Select the new account → Actions → Move → Select "Security" OU

3. **Create Workload Account**
   - Click "Add account" → "Create account"
   - Account name: "Workload Account"
   - Email: workload-account@yourdomain.com (must be unique)
   - IAM role name: OrganizationAccountAccessRole (default)
   - Click "Create account"
   - **Move to Workloads OU**: Select the new account → Actions → Move → Select "Workloads" OU

### Step 5: Configure Consolidated Billing (Requirement 1.5)

1. **Verify Consolidated Billing**
   - Navigate to AWS Billing and Cost Management console
   - URL: https://console.aws.amazon.com/billing/
   - Go to "Bills" section
   - Confirm you see charges for all accounts in the organization

2. **Set Up Cost Allocation Tags**
   - In Billing console, go to "Cost allocation tags"
   - Activate relevant tags for cost tracking:
     - Environment
     - Project
     - Owner
     - CostCenter

3. **Configure Billing Preferences**
   - Go to "Billing preferences"
   - Enable:
     - "Receive PDF Invoice By Email"
     - "Receive AWS Free Tier Usage Alerts"
     - "Receive Billing Alerts"

## Validation Procedures

### Organization Structure Validation
1. **Verify Account Placement**
   ```
   Root Organization
   ├── Management Account
   ├── Security OU
   │   ├── Audit Account
   │   └── Logging Account
   └── Workloads OU
       └── Workload Account
   ```

2. **Test Cross-Account Access**
   - From management account, assume OrganizationAccountAccessRole in each member account
   - Verify you can access each account's console
   - Command to test programmatically:
   ```bash
   aws sts assume-role \
     --role-arn arn:aws:iam::ACCOUNT-ID:role/OrganizationAccountAccessRole \
     --role-session-name test-session
   ```

### Billing Validation
1. **Check Consolidated Billing**
   - In Billing console, verify all accounts appear under "Linked accounts"
   - Confirm charges are aggregated at the management account level

2. **Verify Cost Allocation**
   - Check that cost allocation tags are properly configured
   - Ensure billing alerts are set up and functional

## Troubleshooting Guide

### Common Issues and Solutions

1. **Account Creation Fails**
   - **Issue**: Email address already in use
   - **Solution**: Use unique email addresses for each account (consider using email aliases)

2. **Cannot Move Account to OU**
   - **Issue**: Account stuck in Root OU
   - **Solution**: Ensure account creation is complete (can take 5-10 minutes)

3. **Cross-Account Access Denied**
   - **Issue**: Cannot assume OrganizationAccountAccessRole
   - **Solution**: 
     - Verify the role exists in the target account
     - Check trust policy allows management account access
     - Ensure your user has sts:AssumeRole permissions

4. **Billing Consolidation Not Working**
   - **Issue**: Accounts not showing in consolidated billing
   - **Solution**: 
     - Verify accounts are part of the organization
     - Check that consolidated billing is enabled (automatic with all features)
     - Wait up to 24 hours for billing data to appear

### Verification Commands

```bash
# List organization accounts
aws organizations list-accounts

# Describe organization
aws organizations describe-organization

# List organizational units
aws organizations list-organizational-units-for-parent --parent-id r-xxxx

# Check account status
aws organizations describe-account --account-id ACCOUNT-ID
```

## Security Considerations

1. **Management Account Protection**
   - Enable MFA for root user
   - Create strong password policy
   - Limit access to management account
   - Enable CloudTrail logging

2. **Cross-Account Role Security**
   - OrganizationAccountAccessRole provides full administrative access
   - Consider creating more restrictive roles for day-to-day operations
   - Implement MFA requirements for sensitive operations

3. **Email Security**
   - Use secure email addresses for account creation
   - Implement email security controls (SPF, DKIM, DMARC)
   - Monitor for unauthorized account creation attempts

## Next Steps

After completing this setup:
1. Deploy AWS Control Tower (Task 2)
2. Implement Service Control Policies (Task 3)
3. Configure cross-account IAM roles (Task 4)
4. Establish account-level security baselines (Task 5)

## AWS Security Specialty Exam Relevance

**Exam Domain Coverage:**
- **Domain 6 (Governance)**: AWS Organizations setup and management
- **Domain 4 (IAM)**: Cross-account access patterns and role management

**Key Exam Points:**
- Understanding organizational unit hierarchy and inheritance
- Cross-account access using OrganizationAccountAccessRole
- Consolidated billing and cost management
- Service Control Policy attachment points
- Account lifecycle management

**Scenario-Based Questions:**
- Multi-account governance strategies
- Cost allocation and billing consolidation
- Cross-account access patterns
- Organizational unit design for security boundaries