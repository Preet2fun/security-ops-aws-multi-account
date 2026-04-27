# AWS Certified Security Specialty (SCS-C03) - Comprehensive Exam Guide

## Overview
The AWS Certified Security Specialty (SCS-C03) is an advanced-level certification that validates expertise in securing AWS workloads and architectures. This certification demonstrates your ability to design secure architectures, implement security controls, respond to incidents, and maintain compliance across AWS environments.

**Exam Details:**
- **Exam Code:** SCS-C03 (Updated December 2025)
- **Duration:** 170 minutes
- **Questions:** 65 questions (50 scored + 15 unscored)
- **Passing Score:** 750/1000 (scaled scoring)
- **Format:** Multiple choice, multiple response, ordering, matching
- **Cost:** $300 USD
- **Validity:** 3 years

## Target Candidate Profile
- **Experience:** 3-5 years securing cloud solutions
- **Background:** Security professionals, security architects, security engineers
- **Prerequisites:** Strong AWS fundamentals (Solutions Architect Associate recommended)

## Exam Domain Structure (7 Domains)

### Domain 1: Threat Detection and Incident Response (~18%)
**Focus:** Detecting threats and responding to security incidents using AWS services

**Key Services:**
- **Amazon GuardDuty**
  - Configuration and findings analysis
  - Extended Threat Detection for multi-stage attacks
  - Runtime Monitoring for EKS and EC2
  - Malware Protection for S3
  - Integration with other security services

- **AWS Security Hub**
  - Centralized findings aggregation
  - Security standards (FSBP, CIS, PCI DSS)
  - CSPM (Cloud Security Posture Management) capabilities
  - Exposure findings and attack path analysis
  - Custom insights and automated remediation

- **Amazon Detective**
  - Root cause analysis and visual investigation
  - Correlation with GuardDuty findings
  - Behavioral analysis and timeline reconstruction

- **Automated Response**
  - EventBridge rules triggering Lambda functions
  - Step Functions for complex workflows
  - Systems Manager for automated remediation

**Study Focus:**
- Understand how GuardDuty findings flow to Security Hub
- Learn Detective investigation workflows
- Master automated response patterns using EventBridge
- Practice incident response playbooks

### Domain 2: Security Logging and Monitoring (~16%)
**Focus:** Comprehensive logging infrastructure and security event analysis

**Key Services:**
- **AWS CloudTrail**
  - Multi-region and organization trails
  - Log file validation and integrity
  - CloudTrail Lake for SQL querying
  - Data events vs management events
  - Integration with CloudWatch and S3

- **VPC Flow Logs**
  - Network traffic monitoring at VPC, subnet, and ENI levels
  - Log formats and field descriptions
  - Analysis with Athena and CloudWatch Insights
  - Custom log formats and filtering

- **AWS Config**
  - Resource configuration tracking
  - Compliance monitoring and rules
  - Advanced queries and aggregators
  - Remediation configurations

- **CloudWatch Logs**
  - Log aggregation and retention
  - Metric filters and alarms
  - Log insights for querying
  - Cross-account log sharing

**Study Focus:**
- Design centralized logging architectures
- Understand when to use CloudTrail Lake vs S3 + Athena
- Master VPC Flow Logs analysis techniques
- Practice Config rule creation and remediation

### Domain 3: Infrastructure Security (~18%)
**Focus:** Network security, DDoS protection, and application-layer security

**Key Services:**
- **VPC Security**
  - Security Groups (stateful firewall)
  - Network ACLs (stateless firewall)
  - VPC Endpoints and PrivateLink
  - NAT Gateways and Internet Gateways
  - VPC Peering and Transit Gateway security

- **AWS WAF (Web Application Firewall)**
  - Managed rule groups and custom rules
  - Bot Control and rate limiting
  - Geographic restrictions
  - Integration with CloudFront, ALB, API Gateway

- **AWS Shield**
  - Shield Standard (automatic, free DDoS protection)
  - Shield Advanced (enhanced protection, DRT access)
  - Cost protection and attack notifications

- **AWS Network Firewall**
  - Stateful and stateless inspection
  - Suricata-compatible IPS rules
  - Domain filtering and TLS inspection
  - VPC-level deployment

**Study Focus:**
- Master the layered approach to network security
- Understand Security Groups vs NACLs differences
- Learn WAF rule creation and testing
- Practice Network Firewall policy configuration

### Domain 4: Identity and Access Management (~20%)
**Focus:** IAM policies, multi-account governance, and access control

**Key Services:**
- **AWS IAM (Identity and Access Management)**
  - Users, groups, roles, and policies
  - Policy evaluation logic and precedence
  - Permissions boundaries and session policies
  - Cross-account access patterns
  - IAM Access Analyzer

- **AWS Organizations**
  - Service Control Policies (SCPs)
  - Resource Control Policies (RCPs) - NEW in SCS-C03
  - Organizational Units (OUs) structure
  - Account management and billing

- **AWS IAM Identity Center (SSO)**
  - Centralized access management
  - Permission sets and assignments
  - Multi-account access patterns
  - Integration with external identity providers

- **Amazon Cognito**
  - User pools and identity pools
  - Authentication and authorization flows
  - Integration with web and mobile applications

**Study Focus:**
- Master IAM policy evaluation logic
- Understand SCP vs RCP differences and use cases
- Practice cross-account access scenarios
- Learn Cognito authentication patterns

### Domain 5: Data Protection (~18%)
**Focus:** Encryption, key management, and data classification

**Key Services:**
- **AWS KMS (Key Management Service)**
  - Customer managed keys vs AWS managed keys
  - Key policies and grants
  - Cross-account key access
  - Automatic key rotation
  - CloudHSM integration

- **AWS Secrets Manager**
  - Automatic rotation with managed templates
  - Alternating users strategy
  - Cross-region replication
  - Integration with RDS, Aurora, and other services

- **Amazon Macie**
  - Sensitive data discovery in S3
  - Managed and custom data identifiers
  - Data classification and findings
  - Integration with Security Hub

- **AWS Certificate Manager (ACM)**
  - SSL/TLS certificate management
  - Automatic renewal and deployment
  - Integration with CloudFront, ALB, API Gateway

**Study Focus:**
- Deep dive into KMS key types and policies
- Understand envelope encryption concepts
- Practice Secrets Manager rotation configurations
- Learn Macie data classification patterns

### Domain 6: Security Foundations and Governance (~14%)
**Focus:** Compliance automation, security standards, and governance

**Key Services:**
- **AWS Config**
  - Compliance rules and evaluations
  - Automated remediation actions
  - Conformance packs for standards
  - Multi-account aggregation

- **AWS Systems Manager**
  - Patch Manager for vulnerability management
  - Session Manager for secure access
  - Parameter Store for configuration management
  - Compliance reporting

- **AWS Audit Manager**
  - Compliance framework automation
  - Evidence collection and assessment
  - Audit readiness and reporting

- **AWS Control Tower**
  - Landing zone setup and governance
  - Guardrails (preventive and detective)
  - Account factory and provisioning

**Study Focus:**
- Understand compliance framework requirements
- Learn automated remediation patterns
- Practice multi-account governance setup
- Master Control Tower guardrails

### Domain 7: Generative AI and Machine Learning Security (~10%) - NEW
**Focus:** Securing AI/ML workloads and generative AI applications

**Key Services:**
- **Amazon Bedrock**
  - Model access and permissions
  - Guardrails for content filtering
  - Logging and monitoring model invocations
  - Data protection and privacy controls

- **Amazon SageMaker Security**
  - Training job security configurations
  - Model endpoint protection
  - Data encryption in transit and at rest
  - VPC configurations for ML workloads

- **GuardDuty for AI/ML**
  - Detection of suspicious AI/ML activities
  - Model inference anomaly detection
  - Integration with Bedrock monitoring

**Study Focus:**
- Learn Bedrock security controls and guardrails
- Understand SageMaker security best practices
- Practice AI/ML workload monitoring setup
- Study data protection for ML training data

## Comprehensive AWS Services List

### Core Security Services (Must Master)
1. **AWS IAM** - Identity and Access Management
2. **AWS KMS** - Key Management Service
3. **Amazon GuardDuty** - Threat Detection
4. **AWS Security Hub** - Security Findings Aggregation
5. **AWS WAF** - Web Application Firewall
6. **AWS Shield** - DDoS Protection
7. **AWS CloudTrail** - API Logging and Auditing
8. **AWS Config** - Configuration Management and Compliance

### Detection and Monitoring Services
9. **Amazon Detective** - Security Investigation
10. **Amazon Macie** - Data Classification and Protection
11. **AWS Inspector** - Vulnerability Assessment
12. **Amazon CloudWatch** - Monitoring and Alerting
13. **VPC Flow Logs** - Network Traffic Analysis
14. **AWS X-Ray** - Application Tracing

### Infrastructure Security Services
15. **Amazon VPC** - Virtual Private Cloud
16. **AWS Network Firewall** - Network Protection
17. **AWS Certificate Manager (ACM)** - SSL/TLS Management
18. **AWS Secrets Manager** - Credential Management
19. **AWS Systems Manager** - Operational Management
20. **AWS CloudHSM** - Hardware Security Module

### Governance and Compliance Services
21. **AWS Organizations** - Multi-Account Management
22. **AWS Control Tower** - Landing Zone and Governance
23. **AWS Audit Manager** - Compliance Automation
24. **AWS Trusted Advisor** - Best Practice Recommendations
25. **AWS Resource Access Manager (RAM)** - Resource Sharing

### Identity Services
26. **AWS IAM Identity Center (SSO)** - Centralized Access
27. **Amazon Cognito** - User Authentication
28. **AWS Directory Service** - Managed Active Directory
29. **AWS Single Sign-On** - Federated Access

### Data Protection Services
30. **Amazon S3** - Object Storage (with security features)
31. **AWS Backup** - Centralized Backup
32. **AWS Storage Gateway** - Hybrid Storage
33. **Amazon EBS** - Block Storage Encryption

### AI/ML Security Services (New Domain)
34. **Amazon Bedrock** - Generative AI Platform
35. **Amazon SageMaker** - Machine Learning Platform
36. **AWS Comprehend** - Natural Language Processing
37. **Amazon Textract** - Document Analysis

### Network and Content Delivery
38. **Amazon CloudFront** - Content Delivery Network
39. **AWS Global Accelerator** - Network Performance
40. **Amazon Route 53** - DNS Service
41. **AWS Direct Connect** - Dedicated Network Connection

### Additional Important Services
42. **Amazon SNS** - Simple Notification Service
43. **Amazon SQS** - Simple Queue Service
44. **AWS EventBridge** - Event-Driven Architecture
45. **AWS Lambda** - Serverless Computing
46. **Amazon API Gateway** - API Management
47. **AWS Step Functions** - Workflow Orchestration


### Hands-On Practice Requirements
- Set up multi-account organization with SCPs
- Configure GuardDuty and investigate sample findings
- Implement automated incident response with EventBridge
- Create KMS keys with cross-account access
- Set up VPC with layered security controls
- Configure WAF rules and test protection

## Exam Tips and Best Practices

### Question Analysis Strategy
1. **Read carefully** - Pay attention to qualifiers (MOST, LEAST, NOT)
2. **Identify the scenario** - Understand the business requirement
3. **Eliminate wrong answers** - Use AWS best practices to narrow choices
4. **Consider cost and complexity** - Choose the most appropriate solution

### Common Exam Patterns
- **Security Groups vs NACLs** - Stateful vs stateless filtering
- **KMS key types** - When to use customer managed vs AWS managed
- **Cross-account access** - IAM roles vs resource-based policies
- **Incident response** - Automated vs manual remediation
- **Compliance** - Preventive vs detective controls

### Time Management
- **2.5 minutes per question** average
- **Flag difficult questions** and return later
- **Don't overthink** - trust your knowledge
- **Review flagged questions** in remaining time

## Success Metrics
- **Practice exam scores:** Consistently 80%+ across multiple attempts
- **Hands-on completion:** All recommended labs and exercises
- **Service knowledge:** Ability to explain use cases for each core service
- **Scenario analysis:** Can design security solutions for given requirements

---

*This steering document is designed to guide your AWS Security Specialty (SCS-C03) exam preparation. Focus on hands-on practice, understand service integration patterns, and master the security philosophy behind AWS recommendations.*