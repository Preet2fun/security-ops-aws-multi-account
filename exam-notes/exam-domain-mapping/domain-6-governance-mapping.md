# Domain 6: Governance - AWS Organizations Implementation Mapping

## Domain Overview
**Domain 6: Security Foundations and Governance (14% of exam)**

This domain focuses on implementing governance controls, compliance automation, and security standards across AWS environments. AWS Organizations is a foundational service for multi-account governance strategies.

## AWS Organizations Mapping to Exam Objectives

### 6.1 Implement Governance Controls
**Exam Objective**: Design and implement governance controls for multi-account environments

**AWS Organizations Implementation**:
- **Service Control Policies (SCPs)**: Preventive controls that define maximum permissions
- **Organizational Unit Structure**: Hierarchical organization for policy application
- **Policy Inheritance**: Automatic policy application down the organization tree
- **Cross-Account Management**: Centralized account lifecycle management

**Key Exam Points**:
- Understanding SCP evaluation logic and precedence
- Designing OU hierarchies for effective governance
- Implementing preventive vs. detective controls
- Managing policy inheritance and exceptions

**Practical Implementation**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "cloudtrail:StopLogging",
        "config:DeleteConfigurationRecorder",
        "guardduty:DeleteDetector"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalOrgID": "o-example123456"
        }
      }
    }
  ]
}
```

### 6.2 Compliance Automation and Monitoring
**Exam Objective**: Implement automated compliance monitoring and reporting

**AWS Organizations Integration**:
- **AWS Config Organization Aggregator**: Centralized compliance monitoring
- **Organization-wide CloudTrail**: Comprehensive audit logging
- **Consolidated Security Hub**: Centralized security findings
- **Cross-Account Access**: Audit and compliance role access

**Key Exam Points**:
- Setting up organization-wide compliance monitoring
- Implementing centralized audit logging strategies
- Understanding compliance framework requirements (SOC 2, ISO 27001, PCI DSS)
- Automated remediation across multiple accounts

**Practical Implementation**:
- Organization CloudTrail for audit compliance
- Config aggregator for configuration compliance
- Security Hub for security compliance
- Cross-account roles for compliance auditing

### 6.3 Multi-Account Security Strategy
**Exam Objective**: Design secure multi-account architectures

**AWS Organizations Core Concepts**:
- **Account Isolation**: Security boundaries through separate accounts
- **Workload Segregation**: Separate accounts for different environments
- **Centralized Security**: Dedicated security accounts (audit, logging)
- **Consolidated Billing**: Cost management and allocation

**Key Exam Points**:
- When to use separate accounts vs. separate VPCs
- Designing account structures for different business requirements
- Implementing cross-account access patterns securely
- Understanding the security benefits of account isolation

**Account Structure Patterns**:
```
Organization Root
├── Management Account (Billing, Organization Management)
├── Security OU
│   ├── Audit Account (Security Hub, GuardDuty Master)
│   └── Logging Account (CloudTrail, Config, VPC Flow Logs)
├── Production OU
│   ├── Prod Account 1 (Application Workloads)
│   └── Prod Account 2 (Data Workloads)
└── Non-Production OU
    ├── Dev Account (Development Environment)
    └── Test Account (Testing Environment)
```

## Exam Scenario Patterns

### Scenario 1: Preventing Accidental Security Service Disabling
**Question Pattern**: "A company wants to ensure that security services like CloudTrail and GuardDuty cannot be disabled across their organization."

**Solution Approach**:
1. Create SCP with explicit deny for security service disabling actions
2. Apply SCP to all OUs except management account
3. Use condition keys to allow exceptions for specific roles if needed
4. Implement monitoring to detect any attempts to disable services

**Key Learning Points**:
- SCPs provide preventive controls (deny actions before they happen)
- Management account is not subject to SCPs
- Use explicit deny for maximum security
- Combine with detective controls (CloudTrail, Config) for comprehensive coverage

### Scenario 2: Regional Compliance Requirements
**Question Pattern**: "A financial services company must ensure all resources are created only in US regions due to regulatory requirements."

**Solution Approach**:
1. Create regional restriction SCP
2. Allow only approved regions (us-east-1, us-west-2, etc.)
3. Include exceptions for global services (IAM, CloudFront, Route 53)
4. Apply to workload accounts, not management account

**Key Learning Points**:
- Use aws:RequestedRegion condition key for regional restrictions
- Understand which services are global vs. regional
- Consider exceptions for legitimate global service usage
- Test SCPs thoroughly before production deployment

### Scenario 3: Cross-Account Access for Security Operations
**Question Pattern**: "A security team needs read-only access to all accounts in the organization for incident response."

**Solution Approach**:
1. Create security audit role in each member account
2. Configure trust relationship with management account
3. Use cross-account role assumption from security account
4. Implement MFA requirements for sensitive operations

**Key Learning Points**:
- OrganizationAccountAccessRole provides full admin access
- Create custom roles with least privilege for specific use cases
- Use MFA conditions in trust policies for sensitive roles
- Implement session duration limits for security

## Integration with Other Governance Services

### AWS Control Tower Integration
**Exam Relevance**: Understanding how Organizations works with Control Tower

**Key Points**:
- Control Tower uses Organizations as the foundation
- Guardrails are implemented as SCPs and Config rules
- Account Factory automates account creation with governance
- Landing Zone provides pre-configured multi-account environment

### AWS Config Integration
**Exam Relevance**: Organization-wide configuration compliance

**Key Points**:
- Config aggregator collects data from all organization accounts
- Organization Config rules apply to all accounts automatically
- Compliance reporting across the entire organization
- Automated remediation can be triggered organization-wide

### AWS CloudTrail Integration
**Exam Relevance**: Centralized audit logging strategy

**Key Points**:
- Organization trail logs API calls from all accounts
- Centralized log storage in management or logging account
- Cross-account access to CloudTrail logs for security analysis
- Integration with CloudWatch Logs for real-time monitoring

## Cost Management and Optimization

### Consolidated Billing Benefits
**Exam Relevance**: Understanding financial governance aspects

**Key Points**:
- Volume discounts apply across all organization accounts
- Reserved Instance and Savings Plan sharing
- Centralized cost allocation and reporting
- Cost anomaly detection across the organization

### Cost Allocation Strategies
**Exam Relevance**: Implementing cost governance

**Key Points**:
- Account-based cost allocation for clear ownership
- Tag-based cost allocation for granular tracking
- OU-based cost allocation for business unit tracking
- Integration with AWS Budgets for cost controls

## Security Monitoring and Alerting

### Organization-Wide Security Monitoring
**Exam Relevance**: Implementing comprehensive security monitoring

**Key Points**:
- GuardDuty master account for threat detection
- Security Hub for centralized security findings
- Config for configuration compliance monitoring
- CloudWatch for operational monitoring across accounts

### Incident Response Coordination
**Exam Relevance**: Multi-account incident response

**Key Points**:
- Cross-account access for incident response teams
- Centralized logging for forensic analysis
- Automated response across multiple accounts
- Communication and coordination procedures

## Common Exam Question Types

### Multiple Choice Questions
1. **SCP Evaluation Logic**: Questions about how SCPs interact with IAM policies
2. **Account Structure Design**: Choosing appropriate account structures for scenarios
3. **Cross-Account Access**: Implementing secure cross-account access patterns
4. **Compliance Requirements**: Meeting specific compliance framework requirements

### Multiple Response Questions
1. **Governance Controls**: Selecting multiple appropriate governance controls
2. **Monitoring Services**: Choosing services for comprehensive monitoring
3. **Cost Optimization**: Identifying cost optimization opportunities
4. **Security Best Practices**: Selecting multiple security best practices

### Scenario-Based Questions
1. **Multi-Account Strategy**: Designing complete multi-account architectures
2. **Compliance Implementation**: Implementing specific compliance requirements
3. **Incident Response**: Coordinating incident response across accounts
4. **Cost Management**: Implementing cost governance and optimization

## Study Tips for Domain 6

### Focus Areas
1. **Understand SCP evaluation logic thoroughly** - This is frequently tested
2. **Practice designing OU structures** - Different scenarios require different approaches
3. **Know integration patterns** - How Organizations works with other services
4. **Understand compliance requirements** - Common frameworks and their requirements

### Hands-On Practice
1. Set up a multi-account organization with different OU structures
2. Create and test various SCPs in a safe environment
3. Implement cross-account access patterns with different trust policies
4. Set up organization-wide monitoring and compliance reporting

### Key Concepts to Master
1. **Policy Inheritance**: How policies flow down the organization hierarchy
2. **Cross-Account Access**: Different patterns and their security implications
3. **Compliance Automation**: Implementing automated compliance monitoring
4. **Cost Governance**: Using Organizations for cost management and optimization

### Common Pitfalls to Avoid
1. Confusing SCPs with IAM policies (SCPs are boundaries, not permissions)
2. Forgetting that SCPs don't apply to the management account
3. Not understanding the security implications of OrganizationAccountAccessRole
4. Overlooking the importance of MFA in cross-account access scenarios