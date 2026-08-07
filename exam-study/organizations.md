# AWS Organizations - Deep Dive for Security Specialty Exam

## Service Overview

AWS Organizations is a service that helps you centrally manage and govern your environment as you grow and scale your AWS resources. It provides centralized management of multiple AWS accounts, consolidated billing, and the ability to create groups of accounts and apply policies to those groups.

## Core Concepts

### Organization Structure
- **Organization**: The root container for all accounts
- **Root**: The top-level container in an organization
- **Organizational Unit (OU)**: A container for accounts within a root
- **Account**: A standard AWS account that is a member of an organization

### Account Types
- **Management Account**: The account that creates the organization (formerly master account)
- **Member Account**: All other accounts in the organization

## Key Features for Security

### 1. Centralized Account Management
- **Account Creation**: Programmatically create new AWS accounts
- **Account Invitation**: Invite existing accounts to join organization
- **Account Removal**: Remove accounts from organization
- **Cross-Account Access**: Built-in OrganizationAccountAccessRole

### 2. Policy-Based Management
- **Service Control Policies (SCPs)**: Define maximum permissions
- **Tag Policies**: Standardize tags across accounts
- **Backup Policies**: Centralize backup requirements
- **AI Services Opt-out Policies**: Control AI service usage

### 3. Consolidated Billing
- **Single Payer Account**: Management account pays for all member accounts
- **Volume Discounts**: Aggregate usage across all accounts
- **Cost Allocation**: Track costs by account, OU, or tags
- **Reserved Instance Sharing**: Share RIs across accounts

## Service Control Policies (SCPs)

### SCP Characteristics
- **Preventive Controls**: Define what actions are NOT allowed
- **Inheritance**: Policies inherit down the organization tree
- **JSON Format**: Standard IAM policy syntax
- **Maximum Permissions**: Act as permission boundaries

### SCP Evaluation Logic
1. **Explicit Deny**: If SCP explicitly denies, action is denied
2. **Implicit Allow**: If SCP doesn't mention action, it's allowed
3. **IAM Evaluation**: Standard IAM evaluation applies within SCP boundaries

### Common SCP Patterns

#### Regional Restriction SCP
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "us-east-1",
            "us-west-2"
          ]
        }
      }
    }
  ]
}
```

#### Prevent Security Service Disabling
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "cloudtrail:StopLogging",
        "cloudtrail:DeleteTrail",
        "config:DeleteConfigurationRecorder",
        "config:DeleteDeliveryChannel",
        "guardduty:DeleteDetector"
      ],
      "Resource": "*"
    }
  ]
}
```

## Cross-Account Access Patterns

### OrganizationAccountAccessRole
- **Automatic Creation**: Created when account joins organization
- **Full Administrative Access**: Provides complete account access
- **Trust Policy**: Trusts the management account
- **Best Practice**: Create more restrictive roles for day-to-day operations

### Trust Policy Example
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MANAGEMENT-ACCOUNT-ID:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
```

## Security Best Practices

### 1. Management Account Security
- **Minimal Usage**: Use only for organization management
- **Strong Authentication**: Enable MFA for root user
- **Limited Access**: Restrict who can access management account
- **Monitoring**: Enable comprehensive logging

### 2. Organizational Unit Design
- **Security Boundaries**: Use OUs to create security boundaries
- **Policy Inheritance**: Design OU hierarchy for policy inheritance
- **Account Categorization**: Group similar accounts together

### 3. Policy Management
- **Least Privilege**: Apply most restrictive policies possible
- **Testing**: Test SCPs in non-production environments
- **Documentation**: Document policy purposes and exceptions
- **Regular Review**: Periodically review and update policies

## Integration with Other Services

### AWS Control Tower
- **Landing Zone**: Automated multi-account setup
- **Guardrails**: Pre-configured SCPs and Config rules
- **Account Factory**: Standardized account provisioning
- **Dashboard**: Centralized governance view

### AWS CloudTrail
- **Organization Trail**: Single trail for all accounts
- **Centralized Logging**: Aggregate logs in management account
- **Cross-Account Access**: Access logs from member accounts

### AWS Config
- **Organization Aggregator**: Aggregate compliance data
- **Cross-Account Rules**: Deploy rules across organization
- **Compliance Reporting**: Organization-wide compliance view

## Exam Relevance

### Domain 6: Governance (14% of exam)
**Key Exam Points:**
- Understanding SCP evaluation logic and inheritance
- Designing organizational unit structures for security
- Implementing cross-account access patterns
- Consolidated billing and cost allocation strategies

### Domain 4: Identity and Access Management (20% of exam)
**Key Exam Points:**
- Cross-account role trust relationships
- OrganizationAccountAccessRole usage patterns
- SCP as permission boundaries
- Multi-account IAM strategies

## Common Exam Scenarios

### Scenario 1: Multi-Account Security Strategy
**Question Type**: Design a multi-account structure for a company with development, staging, and production environments.

**Key Considerations**:
- Separate accounts for each environment
- Security OU for audit and logging accounts
- SCPs to prevent cross-environment access
- Centralized logging and monitoring

### Scenario 2: Preventing Accidental Resource Deletion
**Question Type**: Implement controls to prevent deletion of critical security resources.

**Key Solution**:
- SCP to deny deletion of CloudTrail, Config, GuardDuty
- Apply to all accounts except management account
- Use explicit deny for maximum security

### Scenario 3: Regional Compliance Requirements
**Question Type**: Ensure resources are only created in approved regions.

**Key Solution**:
- Regional restriction SCP
- Apply to workload accounts
- Exception for global services (IAM, CloudFront, Route 53)

## Troubleshooting Common Issues

### SCP Denying Legitimate Actions
**Symptoms**: Users cannot perform actions they should be able to
**Diagnosis**: Check SCP inheritance path
**Solution**: Modify SCP or create exception

### Cross-Account Access Failures
**Symptoms**: Cannot assume roles in member accounts
**Diagnosis**: Check trust policy and SCP restrictions
**Solution**: Verify role exists and trust policy is correct

### Account Creation Failures
**Symptoms**: New accounts fail to create
**Diagnosis**: Check email uniqueness and organization limits
**Solution**: Use unique emails and request limit increases

## Cost Optimization

### Consolidated Billing Benefits
- **Volume Discounts**: Aggregate usage for better pricing
- **Reserved Instance Sharing**: Share RIs across accounts
- **Savings Plans**: Apply across organization
- **Free Tier**: Aggregate free tier usage

### Cost Allocation Strategies
- **Account-Based**: Separate accounts for cost centers
- **Tag-Based**: Use consistent tagging for cost allocation
- **OU-Based**: Organize accounts by business unit
- **Service-Based**: Track costs by AWS service usage

## Monitoring and Alerting

### CloudWatch Integration
- **Cross-Account Dashboards**: Monitor multiple accounts
- **Consolidated Alarms**: Alert on organization-wide metrics
- **Cost Alerts**: Monitor spending across accounts

### Security Monitoring
- **GuardDuty**: Enable across all accounts
- **Security Hub**: Aggregate findings organization-wide
- **Config**: Monitor compliance across accounts
- **CloudTrail**: Centralized audit logging

## Compliance Considerations

### Audit Requirements
- **Centralized Logging**: All API calls logged centrally
- **Access Tracking**: Monitor cross-account access
- **Policy Changes**: Track SCP and policy modifications
- **Account Lifecycle**: Document account creation/deletion

### Regulatory Compliance
- **Data Residency**: Use regional SCPs for compliance
- **Access Controls**: Implement least privilege across accounts
- **Audit Trails**: Maintain comprehensive audit logs
- **Separation of Duties**: Use account boundaries for separation

## Advanced Features

### Resource Sharing (AWS RAM)
- **Cross-Account Sharing**: Share resources between accounts
- **Organization Integration**: Automatic sharing within organization
- **Resource Types**: VPC subnets, Route 53 resolvers, etc.

### Trusted Access
- **Service Integration**: Allow services to access organization
- **Automatic Enablement**: Services can enable trusted access
- **Security Implications**: Understand what access is granted

## Exam Tips

### Key Points to Remember
1. **SCPs are preventive controls** - they define maximum permissions
2. **Policy inheritance** - policies flow down the organization tree
3. **Management account is special** - SCPs don't apply to management account
4. **OrganizationAccountAccessRole** - provides full administrative access
5. **Consolidated billing** - requires ALL features enabled

### Common Mistakes to Avoid
1. Confusing SCPs with IAM policies (SCPs are boundaries, not permissions)
2. Forgetting that SCPs don't apply to the management account
3. Not understanding policy inheritance in OU hierarchies
4. Assuming SCPs grant permissions (they only restrict)
5. Overlooking the need for MFA in cross-account access

### Study Focus Areas
- Practice designing OU structures for different scenarios
- Understand SCP evaluation logic thoroughly
- Know when to use different policy types (SCP, tag, backup, AI opt-out)
- Understand the relationship between Organizations and Control Tower
- Practice cross-account access scenarios with different trust policies