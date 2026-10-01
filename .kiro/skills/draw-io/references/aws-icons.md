# AWS Icons and Service Names

## 1. Service Name Rules

| Prefix | Examples |
|--------|---------|
| Amazon | Amazon ECS, Amazon ECR, Amazon S3, Amazon RDS, Amazon CloudWatch |
| AWS | AWS Lambda, AWS IAM, AWS CloudFormation, AWS Step Functions |
| Elastic | Elastic Load Balancing |

- Avoid using abbreviations alone (ECS → Amazon ECS)
- Use official service names

## 2. Icon Styles

### 2.1. Resource Icon (basic format)

```xml
shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.{service_name};
```

### 2.2. Product Icon

```xml
shape=mxgraph.aws4.productIcon;prIcon=mxgraph.aws4.{service_name};
```

### 2.3. Notes

- Use `mxgraph.aws4.*` (aws3 is deprecated)
- Service names in snake_case

## 3. Icons by Category

### 3.1. Compute

| Service | resIcon |
|---------|---------|
| Amazon EC2 | mxgraph.aws4.ec2 |
| EC2 Instance | mxgraph.aws4.instance2 |
| AWS Lambda | mxgraph.aws4.lambda |
| Lambda Function | mxgraph.aws4.lambda_function |
| Auto Scaling | mxgraph.aws4.auto_scaling2 |
| AWS Batch | mxgraph.aws4.batch |
| AWS Elastic Beanstalk | mxgraph.aws4.elastic_beanstalk |
| Amazon Lightsail | mxgraph.aws4.lightsail |
| AWS Fargate | mxgraph.aws4.fargate |

### 3.2. Containers

| Service | resIcon |
|---------|---------|
| Amazon ECS | mxgraph.aws4.ecs |
| ECS Task | mxgraph.aws4.ecs_task |
| Amazon EKS | mxgraph.aws4.eks |
| Amazon ECR | mxgraph.aws4.ecr |
| AWS Fargate | mxgraph.aws4.fargate |
| Container | mxgraph.aws4.container_1 |

### 3.3. Storage

| Service | resIcon |
|---------|---------|
| Amazon S3 | mxgraph.aws4.s3 |
| S3 Bucket | mxgraph.aws4.bucket |
| Amazon EBS | mxgraph.aws4.ebs |
| Amazon EFS | mxgraph.aws4.efs |
| AWS Storage Gateway | mxgraph.aws4.storage_gateway |

### 3.4. Database

| Service | resIcon |
|---------|---------|
| Amazon RDS | mxgraph.aws4.rds |
| Amazon Aurora | mxgraph.aws4.aurora |
| Amazon DynamoDB | mxgraph.aws4.dynamodb |
| DynamoDB Table | mxgraph.aws4.table |
| Amazon ElastiCache | mxgraph.aws4.elasticache |
| Amazon Redshift | mxgraph.aws4.redshift |
| Amazon Neptune | mxgraph.aws4.neptune |
| Amazon DocumentDB | mxgraph.aws4.documentdb |

### 3.5. Networking

| Service | resIcon |
|---------|---------|
| Amazon VPC | mxgraph.aws4.vpc |
| Internet Gateway | mxgraph.aws4.internet_gateway |
| NAT Gateway | mxgraph.aws4.nat_gateway |
| VPN Gateway | mxgraph.aws4.vpn_gateway |
| VPC Endpoints | mxgraph.aws4.endpoints |
| Amazon CloudFront | mxgraph.aws4.cloudfront |
| Amazon Route 53 | mxgraph.aws4.route_53 |
| Elastic Load Balancing | mxgraph.aws4.elastic_load_balancing |
| Application Load Balancer | mxgraph.aws4.application_load_balancer |
| Network Load Balancer | mxgraph.aws4.network_load_balancer |
| Amazon API Gateway | mxgraph.aws4.api_gateway |
| AWS Direct Connect | mxgraph.aws4.direct_connect |
| AWS Transit Gateway | mxgraph.aws4.transit_gateway |
| AWS PrivateLink | mxgraph.aws4.privatelink |
| AWS Global Accelerator | mxgraph.aws4.global_accelerator |

### 3.6. Security

| Service | resIcon |
|---------|---------|
| AWS IAM | mxgraph.aws4.iam |
| IAM Role | mxgraph.aws4.role |
| Amazon Cognito | mxgraph.aws4.cognito |
| AWS WAF | mxgraph.aws4.waf |
| AWS Shield | mxgraph.aws4.shield |
| AWS KMS | mxgraph.aws4.key_management_service |
| AWS Secrets Manager | mxgraph.aws4.secrets_manager |
| AWS Certificate Manager | mxgraph.aws4.certificate_manager |
| Amazon GuardDuty | mxgraph.aws4.guardduty |
| AWS Security Hub | mxgraph.aws4.security_hub |

### 3.7. Application Integration

| Service | resIcon |
|---------|---------|
| Amazon SNS | mxgraph.aws4.sns |
| SNS Topic | mxgraph.aws4.topic |
| Amazon SQS | mxgraph.aws4.sqs |
| SQS Queue | mxgraph.aws4.queue |
| Amazon EventBridge | mxgraph.aws4.eventbridge |
| EventBridge Event Bus | mxgraph.aws4.event_bus |
| AWS Step Functions | mxgraph.aws4.step_functions |
| Amazon MQ | mxgraph.aws4.mq |
| AWS AppSync | mxgraph.aws4.appsync |

### 3.8. Management & Governance

| Service | resIcon |
|---------|---------|
| Amazon CloudWatch | mxgraph.aws4.cloudwatch |
| CloudWatch Alarm | mxgraph.aws4.alarm |
| CloudWatch Logs | mxgraph.aws4.logs |
| AWS CloudFormation | mxgraph.aws4.cloudformation |
| AWS CloudTrail | mxgraph.aws4.cloudtrail |
| AWS Systems Manager | mxgraph.aws4.systems_manager |
| Parameter Store | mxgraph.aws4.parameter_store |
| AWS Config | mxgraph.aws4.config |

### 3.9. Developer Tools

| Service | resIcon |
|---------|---------|
| AWS CodeBuild | mxgraph.aws4.codebuild |
| AWS CodePipeline | mxgraph.aws4.codepipeline |
| AWS CodeDeploy | mxgraph.aws4.codedeploy |
| AWS X-Ray | mxgraph.aws4.xray |
| AWS SAM | mxgraph.aws4.serverless_application_model |

### 3.10. Customer Engagement

| Service | resIcon |
|---------|---------|
| Amazon SES | mxgraph.aws4.simple_email_service |
| Amazon Pinpoint | mxgraph.aws4.pinpoint |
| Amazon Connect | mxgraph.aws4.connect |

### 3.11. General/Generic Icons

| Description | resIcon |
|-------------|---------|
| Users | mxgraph.aws4.users |
| User | mxgraph.aws4.user |
| Client | mxgraph.aws4.client |
| Internet | mxgraph.aws4.internet |
| Mobile Client | mxgraph.aws4.mobile_client |
| Traditional Server | mxgraph.aws4.traditional_server |
| Generic Database | mxgraph.aws4.generic_database |
| AWS Cloud | mxgraph.aws4.aws_cloud |

## 4. Group Icons

### 4.1. Basic Syntax

```xml
shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.{group_name};
```

### 4.2. Group Icons

| Description | grIcon |
|-------------|--------|
| AWS Cloud | mxgraph.aws4.group_aws_cloud |
| Region | mxgraph.aws4.group_region |
| VPC | mxgraph.aws4.group_vpc |
| Availability Zone | mxgraph.aws4.group_availability_zone |
| Security Group | mxgraph.aws4.group_security_group |
| Public Subnet | mxgraph.aws4.group_public_subnet |
| Private Subnet | mxgraph.aws4.group_private_subnet |
| Auto Scaling | mxgraph.aws4.group_auto_scaling |
| Generic Group | mxgraph.aws4.group_generic |

### 4.3. Usage Examples

```xml
<!-- AWS Cloud -->
<mxCell style="shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_aws_cloud;..." />

<!-- VPC -->
<mxCell style="shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_vpc;..." />

<!-- Public Subnet -->
<mxCell style="shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_public_subnet;fillColor=#E9F3E6;..." />

<!-- Private Subnet -->
<mxCell style="shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_private_subnet;fillColor=#E6F2F8;..." />
```
