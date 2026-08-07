> Last Updated: 2025-01-27

# Amazon Cognito — Complete Security Deep Dive

## Table of Contents
1. [Service Introduction & Significance](#1-service-introduction--significance)
2. [Behind-the-Scenes Technical Flow](#2-behind-the-scenes-technical-flow)
3. [Step-by-Step Configuration Guide](#3-step-by-step-configuration-guide)
4. [Threat Mitigation Coverage](#4-threat-mitigation-coverage)
5. [Real-World Use Cases](#5-real-world-use-cases)
6. [Defense-in-Depth Positioning](#6-defense-in-depth-positioning)
7. [Exam-Critical Points](#7-exam-critical-points)
8. [Pricing & Limits](#8-pricing--limits)
9. [Troubleshooting](#9-troubleshooting)
10. [Documentation References](#10-documentation-references)

---

## 1. Service Introduction & Significance

### What Amazon Cognito Does

Amazon Cognito provides **authentication, authorization, and user management** for web and mobile applications. It eliminates the need to build custom identity infrastructure by providing two core components:

| Component | Purpose | Key Function |
|-----------|---------|--------------|
| **User Pools** | Authentication (AuthN) | User directory — sign-up, sign-in, token issuance, MFA, federation |
| **Identity Pools** | Authorization (AuthZ) | Federated identity — exchange tokens for temporary AWS credentials (STS) |

### Role in the AWS Security Ecosystem

Cognito is the **front door** to application security — it sits at the identity layer and integrates with:
- **API Gateway** — JWT authorizer for REST/HTTP APIs
- **ALB/NLB** — OIDC authentication action
- **CloudFront** — Lambda@Edge token validation
- **AppSync** — Native Cognito authorizer for GraphQL
- **AWS IAM** — Identity Pool maps tokens to IAM roles via STS

### Key Use Cases for SaaS/Enterprise

1. **Multi-tenant SaaS authentication** — Tenant-aware user pools with custom attributes
2. **B2B federation** — SAML 2.0 / OIDC integration with enterprise IdPs (Okta, Azure AD, Ping)
3. **Machine-to-machine (M2M)** — OAuth 2.0 client credentials flow for service-to-service auth
4. **Customer identity (CIAM)** — Social login (Google, Facebook, Apple) + progressive profiling
5. **Fine-grained authorization** — Identity Pool role mapping with claims-based access

### Cognito in the SaaS Platform Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     WORKLOAD ACCOUNT                              │
│                                                                   │
│  ┌─────────┐    ┌──────────────┐    ┌─────────────┐            │
│  │ Tenant  │───▶│ Cognito User │───▶│ API Gateway │            │
│  │ Users   │    │    Pool      │    │ (JWT Auth)  │            │
│  └─────────┘    └──────┬───────┘    └──────┬──────┘            │
│                         │                    │                    │
│                         ▼                    ▼                    │
│               ┌──────────────┐      ┌──────────────┐           │
│               │ Identity Pool│      │  EKS Cluster │           │
│               │ (AWS Creds)  │      │ (Namespaced) │           │
│               └──────────────┘      └──────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Behind-the-Scenes Technical Flow

### 2.1 User Pool Authentication Flows

Cognito User Pools support multiple authentication flows, each designed for different security contexts:

| Flow | Use Case | Security Level |
|------|----------|---------------|
| `USER_SRP_AUTH` | Browser/mobile apps | Highest — password never sent over wire |
| `USER_PASSWORD_AUTH` | Server-side apps (backend) | Medium — password sent TLS-encrypted |
| `CUSTOM_AUTH` | Custom challenge (OTP, CAPTCHA) | Variable — depends on Lambda logic |
| `ADMIN_USER_PASSWORD_AUTH` | Admin-initiated (server-side) | Medium — requires IAM credentials |
| `USER_AUTH` | Choice-based auth (new) | Variable — adaptive authentication |

### 2.2 SRP Authentication Flow (Primary — Most Secure)

The Secure Remote Password (SRP) protocol ensures the password **never leaves the client device**:

```
┌──────────┐                          ┌─────────────────┐
│  Client  │                          │ Cognito Service │
│  (App)   │                          │  (User Pool)    │
└────┬─────┘                          └───────┬─────────┘
     │                                         │
     │  1. InitiateAuth(USER_SRP_AUTH)         │
     │    - USERNAME                           │
     │    - SRP_A (public value)               │
     │────────────────────────────────────────▶│
     │                                         │
     │  2. Challenge: PASSWORD_VERIFIER        │
     │    - SRP_B (server public value)        │
     │    - SALT                               │
     │    - SECRET_BLOCK                       │
     │◀────────────────────────────────────────│
     │                                         │
     │  3. RespondToAuthChallenge              │
     │    - PASSWORD_CLAIM_SECRET_BLOCK        │
     │    - PASSWORD_CLAIM_SIGNATURE           │
     │    - TIMESTAMP                          │
     │────────────────────────────────────────▶│
     │                                         │
     │  4. AuthenticationResult                │
     │    - IdToken (JWT)                      │
     │    - AccessToken (JWT)                  │
     │    - RefreshToken (opaque)              │
     │◀────────────────────────────────────────│
     │                                         │
```

**Key Security Properties of SRP:**
- Password never transmitted (even encrypted)
- Resistant to man-in-the-middle attacks
- Server compromise doesn't reveal passwords (only verifiers stored)
- Mutual authentication — both client and server prove identity

### 2.3 OAuth 2.0 / OIDC Flow (Federation & Hosted UI)

```
┌──────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────┐
│  Browser │     │ Cognito      │     │  External   │     │   App    │
│  (User)  │     │ Hosted UI    │     │  IdP (SAML/ │     │  Backend │
│          │     │              │     │  OIDC)      │     │          │
└────┬─────┘     └──────┬───────┘     └──────┬──────┘     └────┬─────┘
     │                   │                     │                  │
     │ 1. GET /authorize │                     │                  │
     │──────────────────▶│                     │                  │
     │                   │                     │                  │
     │ 2. Redirect to IdP│                     │                  │
     │◀──────────────────│                     │                  │
     │                   │                     │                  │
     │ 3. Authenticate at IdP                  │                  │
     │────────────────────────────────────────▶│                  │
     │                   │                     │                  │
     │ 4. SAML Assertion / OIDC token          │                  │
     │◀────────────────────────────────────────│                  │
     │                   │                     │                  │
     │ 5. POST /saml2/idpresponse              │                  │
     │──────────────────▶│                     │                  │
     │                   │                     │                  │
     │ 6. Redirect with authorization code     │                  │
     │◀──────────────────│                     │                  │
     │                   │                     │                  │
     │ 7. Authorization code to backend        │                  │
     │─────────────────────────────────────────────────────────▶ │
     │                   │                     │                  │
     │                   │ 8. POST /oauth2/token (code exchange) │
     │                   │◀────────────────────────────────────── │
     │                   │                     │                  │
     │                   │ 9. ID + Access + Refresh tokens       │
     │                   │──────────────────────────────────────▶ │
     │                   │                     │                  │
```

### 2.4 Token Lifecycle

Cognito issues three token types upon successful authentication:

| Token | Type | Default TTL | Contains | Purpose |
|-------|------|-------------|----------|---------|
| **ID Token** | JWT | 1 hour (5min–1day) | User attributes, email, custom claims, `cognito:groups` | Identify the user to your app |
| **Access Token** | JWT | 1 hour (5min–1day) | Scopes, `cognito:groups`, client_id, username | Authorize API calls |
| **Refresh Token** | Opaque | 30 days (1hr–3650 days) | Not a JWT — server-side only | Get new ID/Access tokens silently |

**Token Refresh Flow:**
```
┌──────────┐                          ┌─────────────────┐
│  Client  │                          │ Cognito Service │
└────┬─────┘                          └───────┬─────────┘
     │                                         │
     │  InitiateAuth(REFRESH_TOKEN_AUTH)       │
     │    - REFRESH_TOKEN                      │
     │────────────────────────────────────────▶│
     │                                         │
     │  New ID Token + Access Token            │
     │  (Refresh token NOT rotated by default) │
     │◀────────────────────────────────────────│
```

**Critical Token Security Facts:**
- ID and Access tokens are **signed JWTs** (RS256) — verify with JWKS endpoint
- JWKS URL: `https://cognito-idp.{region}.amazonaws.com/{userPoolId}/.well-known/jwks.json`
- Tokens cannot be revoked individually (except via Global Sign-Out which revokes refresh tokens)
- Access token can include **custom scopes** from resource servers
- Refresh token rotation can be enabled (each use issues a new refresh token)

### 2.5 Identity Pool Credential Flow (AuthZ)

Identity Pools exchange tokens for **temporary AWS credentials** via STS:

```
┌──────────┐     ┌──────────────┐     ┌─────────┐     ┌───────────┐
│  Client  │     │ Identity Pool│     │   STS   │     │ AWS Service│
│          │     │              │     │         │     │ (S3, DDB) │
└────┬─────┘     └──────┬───────┘     └────┬────┘     └─────┬─────┘
     │                   │                   │                │
     │ 1. GetId          │                   │                │
     │  (ID Token)       │                   │                │
     │──────────────────▶│                   │                │
     │                   │                   │                │
     │ 2. IdentityId     │                   │                │
     │◀──────────────────│                   │                │
     │                   │                   │                │
     │ 3. GetCredentials │                   │                │
     │   ForIdentity     │                   │                │
     │──────────────────▶│                   │                │
     │                   │ 4. AssumeRole     │                │
     │                   │   WithWebIdentity │                │
     │                   │──────────────────▶│                │
     │                   │                   │                │
     │                   │ 5. Temp Creds     │                │
     │                   │◀──────────────────│                │
     │                   │                   │                │
     │ 6. AccessKeyId +  │                   │                │
     │    SecretKey +     │                   │                │
     │    SessionToken    │                   │                │
     │◀──────────────────│                   │                │
     │                   │                   │                │
     │ 7. Direct AWS API call with temp credentials          │
     │───────────────────────────────────────────────────────▶│
```

### 2.6 Multi-Account Scenario

For the SaaS platform with 4 accounts (Management, Audit, Logging, Workload):

```
┌─────────────────────────────────────────────────────────────────────┐
│                        WORKLOAD ACCOUNT                               │
│                                                                       │
│  ┌───────────────┐     ┌──────────────┐     ┌─────────────────┐    │
│  │ Cognito User  │     │ API Gateway  │     │   EKS Cluster   │    │
│  │ Pool (Tenants)│────▶│ JWT Authorizer│────▶│  (App Services) │    │
│  └───────────────┘     └──────────────┘     └─────────────────┘    │
│         │                                                            │
│         │  Identity Pool                                             │
│         ▼                                                            │
│  ┌───────────────┐                                                   │
│  │  IAM Roles    │──── Cross-Account AssumeRole ────┐               │
│  │  (per tenant) │                                   │               │
│  └───────────────┘                                   │               │
│                                                       │               │
└───────────────────────────────────────────────────────┼───────────────┘
                                                        │
┌───────────────────────────────────────────────────────┼───────────────┐
│                        AUDIT ACCOUNT                   │               │
│                                                       ▼               │
│  ┌───────────────────────────────────────────────────────┐           │
│  │  Cross-Account Role: AuditReadOnly                     │           │
│  │  Trust: Workload Account Identity Pool Role            │           │
│  └───────────────────────────────────────────────────────┘           │
└───────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────┐
│                        LOGGING ACCOUNT                                 │
│                                                                       │
│  ┌───────────────────────────────────────────────────────┐           │
│  │  Cognito User Pool Logs → CloudWatch (cross-account)   │           │
│  │  Advanced Security logs → centralized SIEM             │           │
│  └───────────────────────────────────────────────────────┘           │
└───────────────────────────────────────────────────────────────────────┘
```

**Multi-Account Patterns:**
- **Cognito lives in Workload Account** — closest to the application
- **Cross-account role assumption** — Identity Pool roles can assume roles in other accounts
- **Centralized logging** — User Pool events streamed to Logging Account via CloudWatch cross-account
- **Audit trail** — All Cognito API calls logged in CloudTrail (Audit Account aggregation)

---

## 3. Step-by-Step Configuration Guide

### 3.1 User Pool Creation

#### AWS Console Steps

1. **Navigate:** AWS Console → Amazon Cognito → **Create user pool**
2. **Sign-in experience:**
   - Cognito user pool sign-in options: `Email` (recommended for SaaS)
   - Also allow: `Phone number` (if SMS MFA needed)
   - User name requirements: Case-insensitive (default — recommended)
3. **Security requirements:**
   - Password policy: Custom
     - Minimum length: `12` (default is 8 — increase for production)
     - Require: uppercase, lowercase, numbers, symbols
   - MFA enforcement: `Required` (not Optional)
   - MFA methods: Authenticator apps (TOTP) — more secure than SMS
   - User account recovery: Email only
4. **Sign-up experience:**
   - Self-registration: Enable/Disable based on use case
   - Attribute verification: Email (required)
   - Required attributes: `email`, `name`
   - Custom attributes: `custom:tenant_id`, `custom:tenant_role`
5. **Message delivery:**
   - Email provider: Amazon SES (production) vs Cognito default (dev only — 50 emails/day limit)
   - FROM address: `noreply@yourdomain.com`
   - SES verified identity required for production
6. **App integration:**
   - User pool name: `saas-platform-users-{env}`
   - Domain: Custom domain (e.g., `auth.yourdomain.com`) — requires ACM cert in us-east-1
   - App client: Create with settings below
7. **Review and create**

#### AWS CLI — Create User Pool

```bash
# Create User Pool with security best practices
aws cognito-idp create-user-pool \
  --pool-name "saas-platform-users-prod" \
  --policies '{
    "PasswordPolicy": {
      "MinimumLength": 12,
      "RequireUppercase": true,
      "RequireLowercase": true,
      "RequireNumbers": true,
      "RequireSymbols": true,
      "TemporaryPasswordValidityDays": 1
    }
  }' \
  --auto-verified-attributes email \
  --mfa-configuration "ON" \
  --software-token-mfa-configuration '{"Enabled": true}' \
  --user-attribute-update-settings '{
    "AttributesRequireVerificationBeforeUpdate": ["email"]
  }' \
  --account-recovery-setting '{
    "RecoveryMechanisms": [
      {"Priority": 1, "Name": "verified_email"}
    ]
  }' \
  --schema '[
    {"Name": "email", "Required": true, "Mutable": true},
    {"Name": "tenant_id", "AttributeDataType": "String", "Mutable": false, "Required": false,
     "StringAttributeConstraints": {"MinLength": "1", "MaxLength": "64"}},
    {"Name": "tenant_role", "AttributeDataType": "String", "Mutable": true, "Required": false,
     "StringAttributeConstraints": {"MinLength": "1", "MaxLength": "32"}}
  ]' \
  --user-pool-add-ons '{"AdvancedSecurityMode": "ENFORCED"}' \
  --deletion-protection "ACTIVE" \
  --tags Environment=prod,Service=auth,CostCenter=platform \
  --region us-east-1
```

### 3.2 App Client Configuration

#### Security-Critical Settings

| Setting | Recommended Value | Why |
|---------|-------------------|-----|
| Generate client secret | Yes (server apps) / No (SPAs) | SPAs can't securely store secrets |
| Auth flows | `ALLOW_USER_SRP_AUTH`, `ALLOW_REFRESH_TOKEN_AUTH` | SRP is most secure; never enable `ALLOW_USER_PASSWORD_AUTH` for public clients |
| OAuth 2.0 grant types | Authorization code (primary) | Implicit grant is deprecated |
| Token expiration | Access: 1hr, ID: 1hr, Refresh: 7 days | Balance security vs UX |
| Prevent user existence errors | Enabled | Prevents username enumeration |
| Enable token revocation | Yes | Allows revoking refresh tokens |

#### AWS CLI — Create App Client

```bash
# Confidential client (server-side app with secret)
aws cognito-idp create-user-pool-client \
  --user-pool-id us-east-1_XXXXXXXXX \
  --client-name "saas-api-backend" \
  --generate-secret \
  --explicit-auth-flows \
    "ALLOW_USER_SRP_AUTH" \
    "ALLOW_REFRESH_TOKEN_AUTH" \
  --supported-identity-providers "COGNITO" \
  --allowed-o-auth-flows "code" \
  --allowed-o-auth-scopes "openid" "email" "profile" "api/read" "api/write" \
  --allowed-o-auth-flows-user-pool-client \
  --callback-urls '["https://app.yourdomain.com/callback"]' \
  --logout-urls '["https://app.yourdomain.com/logout"]' \
  --access-token-validity 1 \
  --id-token-validity 1 \
  --refresh-token-validity 7 \
  --token-validity-units '{
    "AccessToken": "hours",
    "IdToken": "hours",
    "RefreshToken": "days"
  }' \
  --prevent-user-existence-errors "ENABLED" \
  --enable-token-revocation

# Public client (SPA — no secret)
aws cognito-idp create-user-pool-client \
  --user-pool-id us-east-1_XXXXXXXXX \
  --client-name "saas-web-spa" \
  --no-generate-secret \
  --explicit-auth-flows \
    "ALLOW_USER_SRP_AUTH" \
    "ALLOW_REFRESH_TOKEN_AUTH" \
    "ALLOW_CUSTOM_AUTH" \
  --supported-identity-providers "COGNITO" "OktaSAML" \
  --allowed-o-auth-flows "code" \
  --allowed-o-auth-scopes "openid" "email" "profile" \
  --allowed-o-auth-flows-user-pool-client \
  --callback-urls '["https://app.yourdomain.com/callback", "http://localhost:3000/callback"]' \
  --logout-urls '["https://app.yourdomain.com/logout"]' \
  --access-token-validity 1 \
  --id-token-validity 1 \
  --refresh-token-validity 1 \
  --token-validity-units '{
    "AccessToken": "hours",
    "IdToken": "hours",
    "RefreshToken": "days"
  }' \
  --prevent-user-existence-errors "ENABLED" \
  --enable-token-revocation
```

### 3.3 Custom Domain Setup

A custom domain (`auth.yourdomain.com`) provides branded login experience and is required for production:

```bash
# Prerequisites:
# 1. ACM certificate in us-east-1 (regardless of User Pool region)
# 2. Domain ownership verified

# Create custom domain
aws cognito-idp create-user-pool-domain \
  --user-pool-id us-east-1_XXXXXXXXX \
  --domain "auth.yourdomain.com" \
  --custom-domain-config '{
    "CertificateArn": "arn:aws:acm:us-east-1:111122223333:certificate/abc123"
  }'

# After creation, get the CloudFront distribution alias target:
aws cognito-idp describe-user-pool-domain \
  --domain "auth.yourdomain.com"
# Returns: CloudFrontDistribution: d111111abcdef8.cloudfront.net

# Create Route 53 ALIAS record pointing to the CloudFront distribution
aws route53 change-resource-record-sets \
  --hosted-zone-id Z0123456789 \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "auth.yourdomain.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z2FDTNDATAQYW2",
          "DNSName": "d111111abcdef8.cloudfront.net",
          "EvaluateTargetHealth": false
        }
      }
    }]
  }'
```

**Important:** Cognito custom domains use a CloudFront distribution managed by AWS. The hosted zone ID `Z2FDTNDATAQYW2` is always the same (CloudFront's hosted zone).

### 3.4 MFA Configuration

```bash
# Enable TOTP MFA (software token)
aws cognito-idp set-user-pool-mfa-config \
  --user-pool-id us-east-1_XXXXXXXXX \
  --mfa-configuration "ON" \
  --software-token-mfa-configuration '{"Enabled": true}' \
  --sms-mfa-configuration '{
    "SmsAuthenticationMessage": "Your code is {####}",
    "SmsConfiguration": {
      "SnsCallerArn": "arn:aws:iam::111122223333:role/CognitoSMSRole",
      "ExternalId": "cognito-external-id",
      "SnsRegion": "us-east-1"
    }
  }'
```

**MFA Options:**
| Method | Security | UX Impact | Cost |
|--------|----------|-----------|------|
| TOTP (Authenticator app) | High | Medium | Free |
| SMS | Medium (SIM swap risk) | Low | Per-message SNS cost |
| Email OTP | Medium | Low | SES cost |

**Recommendation:** Use TOTP as primary, SMS as backup only for account recovery.

### 3.5 Advanced Security Features (Threat Protection)

Advanced Security provides **adaptive authentication** and **compromised credential detection**:

```bash
# Enable Advanced Security in ENFORCED mode
aws cognito-idp update-user-pool \
  --user-pool-id us-east-1_XXXXXXXXX \
  --user-pool-add-ons '{"AdvancedSecurityMode": "ENFORCED"}'

# AUDIT mode: logs risk but doesn't block (use for testing)
# ENFORCED mode: actively blocks high-risk auth attempts
```

**Advanced Security Features:**
1. **Compromised credentials detection** — Checks passwords against known breach databases
2. **Adaptive authentication** — Risk-based MFA challenges (low/medium/high risk)
3. **IP-based blocking** — Block or allow specific IP ranges
4. **Device tracking** — Remember trusted devices to reduce MFA friction

### 3.6 Lambda Triggers (Customization Hooks)

Lambda triggers execute custom logic at specific points in the authentication lifecycle:

| Trigger | When It Fires | Common Use Case |
|---------|---------------|-----------------|
| Pre Sign-up | Before user registration | Validate email domain, check tenant limits |
| Pre Authentication | Before password verification | Block users, check account status |
| Post Authentication | After successful auth | Audit logging, update last-login timestamp |
| Pre Token Generation | Before tokens are issued | Add custom claims (tenant_id, roles, permissions) |
| Post Confirmation | After email/phone verified | Provision tenant resources, welcome email |
| Custom Message | When sending email/SMS | Custom branding, localization |
| Define Auth Challenge | Custom auth flow definition | Multi-step verification |
| Create Auth Challenge | Generate challenge | Send OTP, present CAPTCHA |
| Verify Auth Challenge | Validate response | Check OTP correctness |
| User Migration | Sign-in for migrated user | Migrate from legacy user store |
| Custom Email Sender | Override email delivery | Use custom email service |
| Custom SMS Sender | Override SMS delivery | Use custom SMS provider |

#### Pre Token Generation Lambda (Most Important for SaaS)

```python
# Lambda: Add tenant context to tokens
import json

def lambda_handler(event, context):
    """
    Pre Token Generation trigger — injects tenant claims into tokens.
    This runs AFTER authentication but BEFORE token issuance.
    """
    # Get tenant_id from user attributes
    user_attributes = event['request']['userAttributes']
    tenant_id = user_attributes.get('custom:tenant_id', 'unknown')
    tenant_role = user_attributes.get('custom:tenant_role', 'viewer')
    
    # Add custom claims to ID token
    event['response']['claimsOverrideDetails'] = {
        'claimsToAddOrOverride': {
            'tenant_id': tenant_id,
            'tenant_role': tenant_role,
            'platform_version': 'v2'
        },
        'claimsToSuppress': [
            'custom:internal_flag'  # Remove sensitive attributes from token
        ]
    }
    
    # Add custom scopes to access token (V2 trigger only)
    # Requires trigger version V2_0
    event['response']['claimsOverrideDetails']['accessTokenGeneration'] = {
        'claimsToAddOrOverride': {
            'tenant_id': tenant_id
        },
        'scopesToAdd': [f'tenant/{tenant_id}/read', f'tenant/{tenant_id}/write']
    }
    
    return event
```

#### Pre Sign-up Lambda (Tenant Validation)

```python
import json
import boto3

dynamodb = boto3.resource('dynamodb')
tenants_table = dynamodb.Table('Tenants')

def lambda_handler(event, context):
    """
    Pre Sign-up trigger — validates tenant before allowing registration.
    """
    email = event['request']['userAttributes'].get('email', '')
    tenant_id = event['request']['userAttributes'].get('custom:tenant_id')
    
    # Validate tenant exists and has capacity
    if tenant_id:
        response = tenants_table.get_item(Key={'tenant_id': tenant_id})
        tenant = response.get('Item')
        
        if not tenant:
            raise Exception("Invalid tenant ID")
        
        if tenant.get('user_count', 0) >= tenant.get('max_users', 100):
            raise Exception("Tenant user limit reached")
        
        # Validate email domain matches tenant's allowed domains
        allowed_domains = tenant.get('allowed_domains', [])
        email_domain = email.split('@')[1] if '@' in email else ''
        
        if allowed_domains and email_domain not in allowed_domains:
            raise Exception(f"Email domain {email_domain} not allowed for this tenant")
    
    # Auto-confirm and auto-verify for federated users
    if event['triggerSource'] == 'PreSignUp_ExternalProvider':
        event['response']['autoConfirmUser'] = True
        event['response']['autoVerifyEmail'] = True
    
    return event
```

### 3.7 Identity Pool Configuration

Identity Pools (Federated Identities) map authenticated/unauthenticated users to IAM roles:

```bash
# Create Identity Pool
aws cognito-identity create-identity-pool \
  --identity-pool-name "saas-platform-identity-pool" \
  --allow-unauthenticated-identities false \
  --cognito-identity-providers '[{
    "ProviderName": "cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXXXXXX",
    "ClientId": "1234567890abcdef",
    "ServerSideTokenCheck": true
  }]' \
  --supported-login-providers '{
    "accounts.google.com": "google-client-id.apps.googleusercontent.com"
  }'
```

#### IAM Role for Authenticated Users (with Tenant Isolation)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::saas-tenant-data/${cognito-identity.amazonaws.com:sub}/*"
      ],
      "Condition": {
        "StringEquals": {
          "s3:prefix": ["${cognito-identity.amazonaws.com:sub}/"]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:111122223333:table/TenantData",
      "Condition": {
        "ForAllValues:StringEquals": {
          "dynamodb:LeadingKeys": ["${cognito-identity.amazonaws.com:sub}"]
        }
      }
    }
  ]
}
```

#### Trust Policy for Identity Pool Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        },
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "authenticated"
        }
      }
    }
  ]
}
```

#### Role Mapping (Claims-Based)

```bash
# Set role mapping — use token claims to determine IAM role
aws cognito-identity set-identity-pool-roles \
  --identity-pool-id "us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
  --roles '{
    "authenticated": "arn:aws:iam::111122223333:role/CognitoAuthDefault",
    "unauthenticated": "arn:aws:iam::111122223333:role/CognitoUnauthDefault"
  }' \
  --role-mappings '{
    "cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXXXXXX:1234567890abcdef": {
      "Type": "Rules",
      "AmbiguousRoleResolution": "Deny",
      "RulesConfiguration": {
        "Rules": [
          {
            "Claim": "custom:tenant_role",
            "MatchType": "Equals",
            "Value": "admin",
            "RoleARN": "arn:aws:iam::111122223333:role/TenantAdminRole"
          },
          {
            "Claim": "custom:tenant_role",
            "MatchType": "Equals",
            "Value": "operator",
            "RoleARN": "arn:aws:iam::111122223333:role/TenantOperatorRole"
          },
          {
            "Claim": "custom:tenant_role",
            "MatchType": "Equals",
            "Value": "viewer",
            "RoleARN": "arn:aws:iam::111122223333:role/TenantViewerRole"
          }
        ]
      }
    }
  }'
```

### 3.8 Resource Server Configuration (Custom Scopes)

Resource servers define custom OAuth 2.0 scopes for fine-grained API access control:

```bash
# Create resource server with custom scopes
aws cognito-idp create-resource-server \
  --user-pool-id us-east-1_XXXXXXXXX \
  --identifier "api" \
  --name "SaaS Platform API" \
  --scopes '[
    {"ScopeName": "read", "ScopeDescription": "Read access to tenant data"},
    {"ScopeName": "write", "ScopeDescription": "Write access to tenant data"},
    {"ScopeName": "admin", "ScopeDescription": "Administrative operations"},
    {"ScopeName": "incidents.read", "ScopeDescription": "Read incidents"},
    {"ScopeName": "incidents.write", "ScopeDescription": "Create/update incidents"},
    {"ScopeName": "assets.read", "ScopeDescription": "Read CMDB assets"},
    {"ScopeName": "assets.write", "ScopeDescription": "Modify CMDB assets"}
  ]'

# Scopes are referenced as: api/read, api/write, api/admin, etc.
# Used in app client AllowedOAuthScopes and API Gateway authorization
```

### 3.9 SAML 2.0 Federation (Enterprise IdP)

```bash
# Create SAML identity provider
aws cognito-idp create-identity-provider \
  --user-pool-id us-east-1_XXXXXXXXX \
  --provider-name "OktaCorp" \
  --provider-type "SAML" \
  --provider-details '{
    "MetadataURL": "https://corp.okta.com/app/xxx/sso/saml/metadata",
    "IDPSignout": "true",
    "RequestSigningAlgorithm": "rsa-sha256"
  }' \
  --attribute-mapping '{
    "email": "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
    "given_name": "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname",
    "family_name": "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname",
    "custom:tenant_id": "tenant_id",
    "custom:tenant_role": "role"
  }' \
  --idp-identifiers '["corp.okta.com", "okta-tenant-123"]'
```

### 3.10 WAF Integration (Protect Cognito Endpoints)

```bash
# Associate WAF Web ACL with Cognito User Pool
aws wafv2 associate-web-acl \
  --web-acl-arn "arn:aws:wafv2:us-east-1:111122223333:regional/webacl/cognito-protection/xxx" \
  --resource-arn "arn:aws:cognito-idp:us-east-1:111122223333:userpool/us-east-1_XXXXXXXXX"
```

**WAF Rules for Cognito:**
- Rate limiting on `/oauth2/token` endpoint (prevent token abuse)
- Geo-blocking for compliance (restrict auth to allowed countries)
- IP reputation lists (block known bad actors)
- Bot control (prevent automated credential stuffing)

---

## 4. Threat Mitigation Coverage

### 4.1 Threat Matrix

| Threat | Layer | Cognito Feature | Configuration |
|--------|-------|-----------------|---------------|
| Credential stuffing | Application | Advanced Security — compromised credentials | ENFORCED mode |
| Brute force attacks | Application | Account lockup + adaptive auth | Lockout after 5 attempts |
| Account takeover | Application | Adaptive authentication + MFA | Risk-based MFA challenges |
| Token theft/replay | Application | Short token TTL + refresh token rotation | 1hr access, enable rotation |
| Phishing | Application | Custom domain + WebAuthn | FIDO2 passkeys |
| Username enumeration | Application | Prevent user existence errors | Enable on app client |
| Session hijacking | Network | Token signing + HTTPS only | Verify JWT signatures |
| Man-in-the-middle | Network | SRP protocol + TLS | USER_SRP_AUTH flow |
| Privilege escalation | Authorization | Scoped tokens + role mapping | Least-privilege IAM roles |
| Bot attacks | Infrastructure | WAF integration | Rate limiting + bot control |

### 4.2 Credential Stuffing Mitigation

**Attack:** Automated use of stolen username/password pairs from other breaches.

**Cognito Defense:**
- **Compromised Credentials Detection** (Advanced Security) — Checks every password at sign-in and sign-up against a database of known leaked credentials
- **Adaptive Authentication** — Detects unusual login patterns (new device, new location, impossible travel)
- **WAF Rate Limiting** — Throttle authentication attempts per IP

**Configuration:**
```bash
# Enable Advanced Security in ENFORCED mode
aws cognito-idp update-user-pool \
  --user-pool-id us-east-1_XXXXXXXXX \
  --user-pool-add-ons '{"AdvancedSecurityMode": "ENFORCED"}'

# Advanced Security actions when compromised credentials detected:
# - BLOCK: Prevent sign-in entirely
# - ALLOW: Allow but log (AUDIT mode)
# Event types: SIGN_IN, SIGN_UP, PASSWORD_CHANGE
```

**How it works internally:**
1. User submits credentials
2. Cognito checks password hash against AWS-maintained breach database
3. If match found → event flagged as `CompromisedCredentialsRisk`
4. Based on configuration: block sign-in OR force password change OR allow with warning

### 4.3 Account Takeover Protection

**Attack:** Attacker gains access to valid account through various means.

**Cognito Defense — Adaptive Authentication:**
```
Risk Assessment Factors:
├── Device fingerprint (new vs recognized)
├── IP address reputation
├── Geographic location (impossible travel detection)
├── Login time patterns
├── Network characteristics
└── Request metadata
```

**Risk Levels and Actions:**
| Risk Level | Trigger | Default Action | Recommended Action |
|------------|---------|----------------|-------------------|
| Low | Known device, usual location | Allow | Allow |
| Medium | New device, known location | Optional MFA | Require MFA |
| High | New device, unusual location, flagged IP | Block | Block + notify user |

**Configuration for Adaptive Auth:**
```bash
# Configure risk-based actions via User Pool Advanced Security
# (Configured via Console: Cognito → User Pool → Sign-in experience → Advanced security)
# Programmatic via UpdateUserPool with UserPoolAddOns

# Event actions are configured as:
# - AccountTakeoverRiskConfiguration
#   - NotifyConfiguration (email the user)
#   - Actions:
#     - LowAction: NO_ACTION | MFA_IF_CONFIGURED | MFA_REQUIRED | BLOCK
#     - MediumAction: NO_ACTION | MFA_IF_CONFIGURED | MFA_REQUIRED | BLOCK
#     - HighAction: NO_ACTION | MFA_IF_CONFIGURED | MFA_REQUIRED | BLOCK
```

### 4.4 Brute Force Protection

**Attack:** Repeated login attempts with different passwords against a target account.

**Cognito Defense:**
- **Automatic lockout** — After 5 failed attempts, temporary lockout (exponential backoff)
- **Device tracking** — Legitimate devices bypass additional challenges
- **WAF rate limiting** — IP-based throttling before requests reach Cognito

**Built-in Behavior:**
```
Failed Attempt 1-4:  Normal processing
Failed Attempt 5:    Account temporarily locked
Recovery:            Exponential backoff timer
                     User can reset via "Forgot Password" flow
                     Admin can force password reset via AdminSetUserPassword
```

**Important Exam Note:** Cognito's lockout behavior is built-in and NOT configurable. You cannot change the 5-attempt threshold. To customize, use Lambda triggers (Pre Authentication) or WAF rules.

### 4.5 Token Theft and Replay

**Attack:** Intercepting or stealing JWT tokens to impersonate users.

**Cognito Defense:**
1. **Short-lived tokens** — Access/ID tokens expire in 1 hour (configurable: 5min–1day)
2. **Refresh token rotation** — Each use invalidates the previous refresh token
3. **Token revocation** — `GlobalSignOut` and `AdminUserGlobalSignOut` revoke all tokens
4. **Device tracking** — Tokens bound to device context
5. **Token signing** — RS256 with key rotation via JWKS endpoint

**Token Validation Best Practice (API Gateway / Backend):**
```python
import jwt
import requests
from functools import lru_cache

COGNITO_REGION = "us-east-1"
USER_POOL_ID = "us-east-1_XXXXXXXXX"
APP_CLIENT_ID = "1234567890abcdef"

JWKS_URL = f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{USER_POOL_ID}/.well-known/jwks.json"
ISSUER = f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{USER_POOL_ID}"

@lru_cache(maxsize=1)
def get_jwks():
    return requests.get(JWKS_URL).json()

def validate_token(token, token_use="access"):
    """Validate Cognito JWT token."""
    # Decode header to get key ID (kid)
    headers = jwt.get_unverified_header(token)
    kid = headers['kid']
    
    # Find matching key in JWKS
    jwks = get_jwks()
    key = next((k for k in jwks['keys'] if k['kid'] == kid), None)
    if not key:
        raise ValueError("Key not found in JWKS")
    
    # Construct public key and verify
    public_key = jwt.algorithms.RSAAlgorithm.from_jwk(key)
    
    decoded = jwt.decode(
        token,
        public_key,
        algorithms=['RS256'],
        issuer=ISSUER,
        options={
            "verify_exp": True,
            "verify_iss": True,
            "verify_aud": False  # Access tokens don't have 'aud' claim
        }
    )
    
    # Verify token_use claim
    if decoded.get('token_use') != token_use:
        raise ValueError(f"Invalid token_use: expected {token_use}")
    
    # For ID tokens, verify audience (client_id)
    if token_use == "id" and decoded.get('aud') != APP_CLIENT_ID:
        raise ValueError("Invalid audience")
    
    # For access tokens, verify client_id claim
    if token_use == "access" and decoded.get('client_id') != APP_CLIENT_ID:
        raise ValueError("Invalid client_id")
    
    return decoded
```

### 4.6 Phishing Protection

**Attack:** Tricking users into entering credentials on fake login pages.

**Cognito Defense:**
- **Custom domain** — Users recognize `auth.yourdomain.com` vs random URLs
- **WebAuthn / FIDO2 Passkeys** — Phishing-resistant authentication (domain-bound)
- **Email verification** — Prevents account registration with stolen emails
- **Custom UI** — Hosted UI customization with brand logos and colors

### 4.7 Username Enumeration

**Attack:** Determining if an account exists by analyzing different error messages.

**Cognito Defense:**
```bash
# Enable on app client — returns generic error for non-existent users
--prevent-user-existence-errors "ENABLED"

# Without this setting:
#   Non-existent user: "User does not exist"
#   Wrong password:    "Incorrect username or password"
#
# With this setting:
#   Both cases return: "Incorrect username or password"
```

---

## 5. Real-World Use Cases

### 5.1 Multi-Tenant SaaS ITOM/ITSM Platform

**Business Context:** A SaaS platform provides IT Operations Management (incident management, CMDB, monitoring) to multiple enterprise customers. Each tenant must be completely isolated.

**Architecture:**
```
┌─────────────────────────────────────────────────────────────────────┐
│                        TENANT ISOLATION ARCHITECTURE                  │
│                                                                       │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐                       │
│  │ Tenant A  │  │ Tenant B  │  │ Tenant C  │   (Enterprise         │
│  │ Users     │  │ Users     │  │ Users     │    Customers)          │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘                       │
│        │               │               │                             │
│        └───────────────┼───────────────┘                             │
│                        ▼                                             │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │              COGNITO USER POOL                           │        │
│  │  ┌─────────────────────────────────────────────────┐    │        │
│  │  │  Custom Attributes:                              │    │        │
│  │  │    - custom:tenant_id (immutable)                │    │        │
│  │  │    - custom:tenant_role (admin/operator/viewer)  │    │        │
│  │  │    - custom:org_unit                             │    │        │
│  │  └─────────────────────────────────────────────────┘    │        │
│  │                                                          │        │
│  │  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐   │        │
│  │  │ App Client  │  │  App Client  │  │  App Client  │   │        │
│  │  │ (Web SPA)   │  │  (Mobile)    │  │  (M2M/API)   │   │        │
│  │  └─────────────┘  └──────────────┘  └──────────────┘   │        │
│  └─────────────────────────────────────────────────────────┘        │
│                        │                                             │
│                        ▼                                             │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │              PRE TOKEN GENERATION LAMBDA                  │        │
│  │  - Injects tenant_id into token claims                   │        │
│  │  - Adds tenant-specific scopes                           │        │
│  │  - Validates tenant subscription status                   │        │
│  └─────────────────────────────────────────────────────────┘        │
│                        │                                             │
│                        ▼                                             │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │              API GATEWAY (JWT AUTHORIZER)                 │        │
│  │  - Validates token signature                             │        │
│  │  - Checks scopes for endpoint access                     │        │
│  │  - Passes tenant_id to backend via context               │        │
│  └─────────────────────────────────────────────────────────┘        │
│                        │                                             │
│                        ▼                                             │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │              EKS CLUSTER (BACKEND)                        │        │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │        │
│  │  │Tenant A  │  │Tenant B  │  │Tenant C  │ (K8s         │        │
│  │  │Namespace │  │Namespace │  │Namespace │  Namespaces)  │        │
│  │  └──────────┘  └──────────┘  └──────────┘              │        │
│  └─────────────────────────────────────────────────────────┘        │
│                        │                                             │
│                        ▼                                             │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │              RDS (TENANT DATA ISOLATION)                  │        │
│  │  - Schema-per-tenant: tenant_a.incidents, tenant_b.*    │        │
│  │  - Row-level security with tenant_id column             │        │
│  │  - Connection via tenant_id from JWT claim              │        │
│  └─────────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────────┘
```

**Key Design Decisions:**
- **Single User Pool** — All tenants share one User Pool (simpler management, supports 40M+ users)
- **Tenant isolation via custom attributes** — `custom:tenant_id` is immutable after sign-up
- **Pre Token Generation Lambda** — Injects tenant context into every token
- **API Gateway enforcement** — JWT authorizer validates tokens before any backend access
- **Backend double-check** — Services always validate `tenant_id` from token matches data access

### 5.2 B2B SAML Federation (Enterprise Customers)

**Business Context:** Enterprise customers want their employees to use existing corporate credentials (Okta, Azure AD) to access the SaaS platform without creating separate accounts.

```
┌──────────────────┐           ┌──────────────────┐
│  Enterprise A    │           │  Enterprise B    │
│  ┌────────────┐  │           │  ┌────────────┐  │
│  │ Okta IdP   │  │           │  │ Azure AD   │  │
│  └─────┬──────┘  │           │  └─────┬──────┘  │
└────────┼─────────┘           └────────┼─────────┘
         │ SAML 2.0                     │ OIDC
         │ Assertion                    │ Token
         ▼                              ▼
┌─────────────────────────────────────────────────────┐
│           COGNITO USER POOL                          │
│                                                      │
│  Identity Providers:                                 │
│  ┌────────────┐  ┌────────────┐  ┌──────────────┐  │
│  │ OktaCorp   │  │ AzureAD-B  │  │ Cognito      │  │
│  │ (SAML)     │  │ (OIDC)     │  │ (native)     │  │
│  └────────────┘  └────────────┘  └──────────────┘  │
│                                                      │
│  Attribute Mapping:                                  │
│  IdP claim → Cognito attribute                       │
│  "groups" → "custom:tenant_role"                     │
│  "tenant" → "custom:tenant_id"                       │
│                                                      │
│  App Client:                                         │
│  - Supported IdPs: OktaCorp, AzureAD-B, COGNITO     │
│  - Hosted UI shows IdP selection                     │
└─────────────────────────────────────────────────────┘
```

**Configuration for SAML Federation:**
```bash
# 1. Create SAML IdP in Cognito
aws cognito-idp create-identity-provider \
  --user-pool-id us-east-1_XXXXXXXXX \
  --provider-name "EnterpriseA-Okta" \
  --provider-type "SAML" \
  --provider-details '{
    "MetadataURL": "https://enterprise-a.okta.com/app/xxx/sso/saml/metadata",
    "IDPSignout": "true",
    "RequestSigningAlgorithm": "rsa-sha256",
    "EncryptedResponses": "true"
  }' \
  --attribute-mapping '{
    "email": "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
    "custom:tenant_id": "urn:oid:1.3.6.1.4.1.99999.1.1",
    "custom:tenant_role": "urn:oid:1.3.6.1.4.1.99999.1.2"
  }'

# 2. Update app client to support the new IdP
aws cognito-idp update-user-pool-client \
  --user-pool-id us-east-1_XXXXXXXXX \
  --client-id 1234567890abcdef \
  --supported-identity-providers "COGNITO" "EnterpriseA-Okta" "EnterpriseB-AzureAD"
```

**IdP-Initiated vs SP-Initiated SSO:**
| Type | Flow | Cognito Support |
|------|------|-----------------|
| SP-Initiated | User starts at app → redirected to IdP → back to app | Fully supported |
| IdP-Initiated | User starts at IdP portal → direct to app | Supported (must configure relay state) |

### 5.3 Machine-to-Machine (M2M) Authentication

**Business Context:** Microservices and external integrations need to authenticate without user interaction — using OAuth 2.0 Client Credentials Grant.

```
┌──────────────────┐                    ┌──────────────────┐
│  Service A       │                    │  Cognito User    │
│  (EKS Pod)      │                    │  Pool            │
│                  │  1. POST /oauth2/token                │
│                  │     grant_type=client_credentials     │
│                  │     client_id=xxx                     │
│                  │     client_secret=yyy                 │
│                  │     scope=api/read api/write          │
│                  │─────────────────────────────────────▶│
│                  │                    │                  │
│                  │  2. Access Token   │                  │
│                  │     (scopes only,  │                  │
│                  │      no user info) │                  │
│                  │◀─────────────────────────────────────│
└────────┬─────────┘                    └──────────────────┘
         │
         │  3. API call with Bearer token
         ▼
┌──────────────────┐
│  Service B       │
│  (API Gateway)   │
│  Validates:      │
│  - Token sig     │
│  - Scopes        │
│  - client_id     │
└──────────────────┘
```

**Configuration:**
```bash
# 1. Create resource server (defines custom scopes)
aws cognito-idp create-resource-server \
  --user-pool-id us-east-1_XXXXXXXXX \
  --identifier "api" \
  --name "Internal API" \
  --scopes '[
    {"ScopeName": "read", "ScopeDescription": "Read operations"},
    {"ScopeName": "write", "ScopeDescription": "Write operations"},
    {"ScopeName": "admin", "ScopeDescription": "Admin operations"}
  ]'

# 2. Create M2M app client (with secret, client_credentials flow)
aws cognito-idp create-user-pool-client \
  --user-pool-id us-east-1_XXXXXXXXX \
  --client-name "service-a-m2m" \
  --generate-secret \
  --allowed-o-auth-flows "client_credentials" \
  --allowed-o-auth-scopes "api/read" "api/write" \
  --allowed-o-auth-flows-user-pool-client
# Note: No callback URLs needed for client_credentials flow
```

**Exam Tip:** Client Credentials flow:
- Returns ONLY an access token (no ID token, no refresh token)
- Token contains `scope` and `client_id` claims — NO user-related claims
- Requires a confidential client (with client_secret)
- Resource servers (custom scopes) MUST be configured

### 5.4 Social Login + Enterprise IdP (Hybrid)

**Business Context:** Platform supports both social login (for individual users/trials) and enterprise federation (for paid B2B customers).

```bash
# Social IdP — Google
aws cognito-idp create-identity-provider \
  --user-pool-id us-east-1_XXXXXXXXX \
  --provider-name "Google" \
  --provider-type "Google" \
  --provider-details '{
    "client_id": "xxx.apps.googleusercontent.com",
    "client_secret": "GOCSPX-xxx",
    "authorize_scopes": "openid email profile"
  }' \
  --attribute-mapping '{
    "email": "email",
    "given_name": "given_name",
    "family_name": "family_name",
    "username": "sub",
    "picture": "picture"
  }'

# Social IdP — Apple Sign In
aws cognito-idp create-identity-provider \
  --user-pool-id us-east-1_XXXXXXXXX \
  --provider-name "SignInWithApple" \
  --provider-type "SignInWithApple" \
  --provider-details '{
    "client_id": "com.yourapp.service",
    "team_id": "ABCDE12345",
    "key_id": "KEY123",
    "private_key": "-----BEGIN PRIVATE KEY-----\n...",
    "authorize_scopes": "email name"
  }' \
  --attribute-mapping '{
    "email": "email",
    "given_name": "firstName",
    "family_name": "lastName"
  }'
```

---

## 6. Defense-in-Depth Positioning

### 6.1 Layer Classification

Amazon Cognito operates primarily as a **Preventive Control** (Layer 1) with detective capabilities:

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEFENSE-IN-DEPTH MODEL                         │
│                                                                   │
│  Layer 1: PREVENTIVE CONTROLS                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  ★ Amazon Cognito (Authentication + Authorization)       │    │
│  │    - User authentication (SRP, MFA, federation)          │    │
│  │    - Token-based authorization                           │    │
│  │    - Adaptive authentication (risk-based blocking)       │    │
│  │    - Compromised credential detection                    │    │
│  │    - Account lockout                                     │    │
│  │                                                          │    │
│  │  + WAF (protect Cognito endpoints)                       │    │
│  │  + SCPs (prevent Cognito misconfiguration)               │    │
│  │  + IAM (control who can modify Cognito settings)         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                   │
│  Layer 2: DETECTIVE CONTROLS                                     │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Cognito Advanced Security Events →                      │    │
│  │    - CloudWatch Logs (auth events, risk scores)          │    │
│  │    - CloudTrail (API activity)                           │    │
│  │    - User activity logs                                  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                   │
│  Layer 3: RESPONSIVE CONTROLS                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Cognito Events → EventBridge → Lambda                   │    │
│  │    - Auto-disable compromised accounts                   │    │
│  │    - Alert on high-risk sign-ins                         │    │
│  │    - Trigger incident response workflows                 │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Integration with Other Security Services

| Service | Integration Pattern | Purpose |
|---------|-------------------|---------|
| **AWS WAF** | Web ACL associated with User Pool | Protect auth endpoints from DDoS, bots, credential stuffing |
| **CloudFront** | Custom domain backed by CF distribution | Edge caching, DDoS protection for Hosted UI |
| **API Gateway** | JWT Authorizer (Cognito) | Validate tokens, enforce scopes on API endpoints |
| **Lambda** | Triggers (Pre/Post auth, Pre Token Gen) | Custom auth logic, tenant injection, audit logging |
| **CloudTrail** | Automatic API logging | Audit all Cognito management plane operations |
| **CloudWatch** | User Pool logs, Advanced Security metrics | Monitor auth patterns, detect anomalies |
| **EventBridge** | Cognito events → automation | Trigger responses on sign-up, auth failures |
| **Secrets Manager** | Store app client secrets | Rotate Cognito client secrets securely |
| **KMS** | Custom encryption of user data | Encrypt User Pool data with CMK |
| **IAM** | Identity Pool role mapping | Map authenticated users to least-privilege AWS roles |
| **SNS** | SMS MFA delivery | Send MFA codes via SMS |
| **SES** | Custom email delivery | Branded verification/MFA emails |
| **Shield Advanced** | DDoS protection for custom domain | Layer 7 attack protection on auth endpoints |

### 6.3 AWS Well-Architected Security Pillar Alignment

| Pillar Best Practice | Cognito Implementation |
|---------------------|------------------------|
| **SEC01** — Operate workloads securely | Centralized identity management, IAM controls on Cognito admin |
| **SEC02** — Manage identities | User Pools for human users, Identity Pools for AWS access |
| **SEC03** — Manage permissions | Token scopes, Identity Pool role mapping, least-privilege |
| **SEC04** — Detect threats | Advanced Security, adaptive auth, compromised credentials |
| **SEC05** — Protect network | WAF on Cognito, custom domain TLS, private endpoints |
| **SEC06** — Protect compute | Token validation in EKS services, no embedded credentials |
| **SEC07** — Protect data | KMS encryption, short-lived tokens, refresh token rotation |
| **SEC08** — Incident response | Auth event logging, automated disable, forensic trails |

### 6.4 Cost vs Risk Trade-offs

| Feature | Monthly Cost (est.) | Risk Mitigated | Recommendation |
|---------|--------------------|--------------------|----------------|
| Advanced Security | $0.050/MAU | Credential stuffing, account takeover | **Always enable** for production |
| MFA (TOTP) | Free | Account takeover | **Always require** |
| MFA (SMS) | ~$0.01/message | Account takeover (weaker) | Backup only |
| WAF on Cognito | $5/rule + $0.60/M requests | Bot attacks, DDoS | **Enable for production** |
| Custom domain | Free (ACM cert cost) | Phishing | **Always use** |
| Lambda triggers | Per-invocation | Varies | Enable as needed |

---

## 7. Exam-Critical Points

### 7.1 Must-Know Facts

1. **User Pools = Authentication (who are you?); Identity Pools = Authorization (what can you access in AWS?)**
2. **User Pools issue JWTs (ID + Access + Refresh); Identity Pools issue temporary AWS credentials (via STS)**
3. **SRP auth flow** is the most secure — password never leaves the client device
4. **Client Credentials Grant** returns ONLY an access token (no ID token, no refresh token)
5. **Custom attributes** — prefixed with `custom:`, max 50 per User Pool, cannot be required, cannot be removed after creation
6. **Custom attributes are immutable** only if configured as such during User Pool creation
7. **Token revocation** — You cannot revoke individual access/ID tokens (they're stateless JWTs). You can revoke refresh tokens via `GlobalSignOut` or `RevokeToken`
8. **Refresh tokens** — Opaque (not JWT), stored server-side by Cognito, can be revoked
9. **Advanced Security** requires `ENFORCED` mode to block threats; `AUDIT` mode only logs
10. **Lambda triggers execute synchronously** — they add latency to the auth flow (5-second timeout)
11. **Pre Token Generation V2** — Required to customize access token claims (V1 only modifies ID token)
12. **Hosted UI** — Required for federation (SAML/OIDC) flows; not needed for native SDK auth
13. **Custom domain** requires ACM certificate in **us-east-1** (regardless of User Pool region)
14. **Identity Pool role mapping** — Rules-based (up to 25 rules) or Token-based (uses `cognito:roles`/`cognito:preferred_role` claims)
15. **User Pool max users** — No hard limit (soft limit 40M per pool, contactable)
16. **Groups** — Users can belong to multiple groups; group with lowest precedence value = highest priority for role mapping
17. **Device tracking** — "Always" (remembered) or "User opt-in"; remembered devices can skip MFA
18. **Cognito sends CloudTrail events** for ALL API calls in the management plane
19. **WAF can be associated directly with Cognito User Pools** (since 2022)
20. **Deletion protection** — Must be explicitly enabled; prevents accidental User Pool deletion

### 7.2 Common Exam Question Patterns

#### Pattern 1: "How to implement multi-tenant isolation?"
**Answer:** Use Cognito User Pool with `custom:tenant_id` attribute → Pre Token Generation Lambda to inject into tokens → API Gateway JWT authorizer → Backend validates tenant_id in token matches data access.

#### Pattern 2: "How to federate enterprise IdP?"
**Answer:** Create SAML/OIDC identity provider in User Pool → Configure attribute mapping → Update app client to include IdP → Users authenticate via Hosted UI → Cognito exchanges IdP token for Cognito tokens.

#### Pattern 3: "How to grant AWS access to authenticated mobile users?"
**Answer:** Cognito User Pool (authentication) → Identity Pool (maps User Pool token to IAM role) → Temporary AWS credentials via STS → Mobile app calls AWS services directly.

#### Pattern 4: "How to prevent credential stuffing?"
**Answer:** Enable Advanced Security (ENFORCED mode) + WAF with rate limiting + MFA enforcement. Advanced Security's compromised credentials detection checks against known breach databases.

#### Pattern 5: "Service-to-service authentication without user context?"
**Answer:** OAuth 2.0 Client Credentials Grant → App client with secret → Custom resource server scopes → Access token with scopes only (no user identity).

#### Pattern 6: "How to customize tokens with business data?"
**Answer:** Pre Token Generation Lambda trigger (V2 for access token, V1 for ID token only) → Inject custom claims from DynamoDB/external source → Claims available to downstream services.

#### Pattern 7: "User Pool vs Identity Pool — when to use which?"
**Answer:**
- Need user directory + sign-up/sign-in + MFA + federation → **User Pool**
- Need AWS service access (S3, DynamoDB) from client → **Identity Pool**
- Need both? Chain them: User Pool → Identity Pool

### 7.3 Tricky Concepts and Gotchas

| Gotcha | Explanation |
|--------|-------------|
| Can't revoke access tokens | Access/ID tokens are stateless JWTs — valid until expiry. Only refresh tokens can be revoked. Short TTL is the mitigation. |
| Custom attributes can't be required | Unlike standard attributes, custom attributes cannot be marked as required during sign-up |
| Hosted UI is mandatory for federation | SAML/OIDC flows REQUIRE the Hosted UI (or custom UI calling the `/authorize` endpoint). You cannot do SAML via API. |
| Lambda trigger timeout | 5-second hard limit. If trigger times out, auth fails. Keep Lambda cold start minimal. |
| client_credentials + resource server | Client Credentials Grant ONLY works with custom scopes from a resource server. Standard OIDC scopes (openid, email, profile) are NOT allowed. |
| Cognito prefix domain vs custom domain | Prefix domain: `https://your-prefix.auth.region.amazoncognito.com`. Custom domain: `https://auth.yourdomain.com`. Can't use both simultaneously. |
| User migration trigger | Only fires on USER_SRP_AUTH or USER_PASSWORD_AUTH, NOT on federated sign-in |
| Identity Pool role precedence | If user is in multiple groups, group with LOWEST precedence number wins (0 = highest priority) |
| Token size limits | ID token max ~8KB, Access token max ~20KB. Be careful with custom claims. |
| MFA TOTP association | User must verify TOTP within the same auth session. Cannot pre-provision TOTP devices via admin API. |

### 7.4 Comparison Tables

#### User Pool vs Identity Pool

| Feature | User Pool | Identity Pool |
|---------|-----------|---------------|
| Primary function | User directory + AuthN | Federated identity + AuthZ |
| What it issues | JWTs (ID, Access, Refresh) | Temporary AWS credentials |
| User management | Yes (CRUD users, groups) | No (no user store) |
| MFA | Yes (TOTP, SMS, Email) | No |
| Federation input | SAML, OIDC, Social IdPs | User Pool, SAML, OIDC, Social, Custom dev |
| Federation output | JWT tokens | IAM role credentials (STS) |
| Custom attributes | Yes (up to 50) | No |
| Lambda triggers | Yes (10+ triggers) | No |
| OAuth 2.0 server | Yes (full implementation) | No |
| API Gateway integration | JWT Authorizer | IAM Authorization |
| Standalone use | Yes | Yes (can federate without User Pool) |
| Advanced Security | Yes (adaptive auth, compromised creds) | No |
| WAF support | Yes | No |

#### Cognito vs IAM Identity Center (SSO)

| Feature | Cognito User Pools | IAM Identity Center |
|---------|-------------------|---------------------|
| Target users | External (customers, end-users) | Internal (employees, contractors) |
| Scale | Millions of users | Thousands of users |
| Multi-account access | Via Identity Pool only | Native (permission sets across accounts) |
| AWS Console access | No | Yes |
| SAML/OIDC federation | Yes (as IdP consumer) | Yes (as IdP consumer) |
| Custom apps | Yes (primary use case) | Yes (SAML/OIDC app portal) |
| Self-service sign-up | Yes | No |
| Pricing | Per MAU | Free (included with Organizations) |
| API Gateway auth | Native JWT authorizer | Via IAM or SAML |
| MFA | TOTP, SMS, Email | TOTP, FIDO2 |

#### Cognito Advanced Security vs WAF

| Feature | Advanced Security | WAF |
|---------|-------------------|-----|
| Layer | Application (user behavior) | Network/Application (request level) |
| Detection | Compromised creds, account takeover patterns | Bot patterns, rate limits, IP reputation |
| Scope | Only Cognito auth flows | Any HTTP endpoint (including Cognito) |
| Response | Block auth, require MFA, notify | Block request, CAPTCHA, rate limit |
| Cost basis | Per MAU | Per rule + per request |
| Use together? | **Yes — complementary** | **Yes — complementary** |

### 7.5 Domain Mapping

| SCS-C03 Domain | Cognito Relevance |
|----------------|-------------------|
| Domain 1: Threat Detection & Incident Response | Advanced Security events, CloudTrail logging, automated response |
| Domain 2: Security Logging & Monitoring | User activity logs, CloudWatch metrics, auth event analysis |
| Domain 3: Infrastructure Security | WAF integration, custom domain TLS, network architecture |
| **Domain 4: Identity & Access Management** | **PRIMARY DOMAIN** — User Pools, Identity Pools, federation, tokens |
| Domain 5: Data Protection | KMS encryption of user data, token security, secrets handling |
| Domain 6: Governance | Config rules for Cognito compliance, Organizations controls |
| Domain 7: AI/ML Security | Cognito + Bedrock access patterns (emerging) |

---

## 8. Pricing & Limits

### 8.1 Pricing Model (User Pools)

| Component | Free Tier | Cost (after free tier) |
|-----------|-----------|------------------------|
| Monthly Active Users (MAU) | 50,000 MAU/month (first 12 months) | Tiered: $0.0055–$0.0025/MAU |
| Advanced Security (Threat Protection) | N/A | $0.050/MAU (ENFORCED or AUDIT) |
| TOTP MFA | Included | Included |
| SMS MFA | N/A | SNS pricing ($0.00581/message US) |
| Client Credentials (M2M) | 250 tokens/month | Tiered: $2.25–$0.15 per 1000 tokens |
| SAML/OIDC Federation | Included in MAU | No additional charge |
| Custom SMS sender (Lambda) | Lambda free tier | Lambda pricing |
| Customize access token | 250 events/month free | $0.008/event |

**MAU Pricing Tiers (after free tier):**
| Tier | Range | Price per MAU |
|------|-------|---------------|
| Tier 1 | First 50,000 | $0.0055 |
| Tier 2 | 50,001–100,000 | $0.0046 |
| Tier 3 | 100,001–1,000,000 | $0.00325 |
| Tier 4 | 1,000,001–10,000,000 | $0.0025 |
| Tier 5 | 10,000,001+ | Contact AWS |

**Definition of MAU:** A user who has performed any identity operation (sign-in, sign-up, token refresh, password change) within a calendar month.

### 8.2 Pricing Model (Identity Pools)

| Component | Free Tier | Cost |
|-----------|-----------|------|
| GetId / GetCredentialsForIdentity | 50,000/month free | Included (no separate charge) |
| Temporary AWS credentials | N/A | Free (you pay for the AWS services accessed) |

**Identity Pools have no per-request charges** — cost is in the downstream AWS services the credentials access.

### 8.3 Service Limits (Quotas)

| Resource | Default Limit | Adjustable? |
|----------|---------------|-------------|
| User Pools per account | 1,000 | Yes |
| App clients per User Pool | 1,000 | Yes |
| Identity providers per User Pool | 300 | Yes |
| Resource servers per User Pool | 25 | Yes |
| Scopes per resource server | 100 | Yes |
| Custom attributes per User Pool | 50 | No |
| Groups per User Pool | 10,000 | Yes |
| Users per group | 60,000 | No (use custom attributes instead) |
| Identity Pools per account | 60 | Yes |
| User Pool custom domain | 4 per account | Yes |
| Lambda trigger timeout | 5 seconds | No |
| Token size (ID token) | ~8 KB | No |
| Token size (Access token) | ~20 KB | No |

**API Rate Limits (Throttling):**
| Category | Default RPS | Notes |
|----------|-------------|-------|
| UserAuthentication (SignIn) | 120 RPS | Soft limit, adjustable |
| UserCreation (SignUp) | 50 RPS | Soft limit |
| UserRead (GetUser) | 120 RPS | Soft limit |
| AccountRecovery (ForgotPassword) | 30 RPS | Soft limit |
| Token (Refresh) | 120 RPS | Soft limit |

**Exam Tip:** Rate limits can cause `TooManyRequestsException` — this is a common cause of auth failures in high-traffic SaaS. Solutions: implement exponential backoff, use caching, request limit increases.

### 8.4 Cost Optimization Tips

1. **Don't enable Advanced Security in dev/test** — Only ENFORCED in production
2. **Use TOTP over SMS** — TOTP is free; SMS costs per message
3. **Optimize token TTL** — Longer refresh tokens = fewer token refresh operations = lower MAU count
4. **M2M token caching** — Cache client_credentials tokens until expiry; don't request new tokens for every call
5. **Use Cognito free tier strategically** — 50K MAU free for first year is generous for startups

---

## 9. Troubleshooting

### 9.1 Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `NotAuthorizedException: Incorrect username or password` | Wrong credentials OR user doesn't exist (if prevent-user-existence enabled) | Check user status in Console; reset password |
| `UserNotConfirmedException` | User signed up but hasn't verified email/phone | Resend confirmation code; or admin-confirm user |
| `InvalidParameterException: USER_SRP_AUTH not enabled` | Auth flow not allowed on app client | Update app client to include `ALLOW_USER_SRP_AUTH` |
| `TooManyRequestsException` | API rate limit exceeded | Implement backoff; request limit increase |
| `InvalidIdentityPoolConfigurationException` | Identity Pool role trust policy wrong | Verify trust policy includes `cognito-identity.amazonaws.com` and correct pool ID |
| `CodeMismatchException` | Wrong verification code OR code expired | Codes expire after 24 hours (configurable); resend code |
| `ExpiredCodeException` | Verification code expired | Resend via `ResendConfirmationCode` |
| `LimitExceededException` | Service quota reached | Check quotas; request increase via Service Quotas |
| `InvalidLambdaResponseException` | Lambda trigger returned malformed response | Check Lambda return format matches trigger requirements |
| `UserLambdaValidationException` | Lambda trigger threw exception | Check Lambda logs in CloudWatch; exception message propagated to client |
| CORS errors on Hosted UI | Callback URL mismatch or missing origin | Verify callback URLs in app client match exactly |
| SAML federation fails | Clock skew, wrong metadata, attribute mapping | Check SAML assertion validity; verify metadata URL accessible; check attribute names |
| Tokens missing custom claims | Pre Token Generation Lambda not attached or failing | Verify Lambda is assigned and check CloudWatch logs for errors |
| Identity Pool returns wrong role | Role mapping rules not matching | Check claim values exactly match rule; verify rule priority order |

### 9.2 Debugging Techniques

**1. Enable Advanced Security logging:**
```bash
# User Pool activity is logged to CloudWatch Logs group:
# /aws/cognito/userpools/{user-pool-id}/activity

# Enable user activity logging
aws cognito-idp set-log-delivery-configuration \
  --user-pool-id us-east-1_XXXXXXXXX \
  --log-configurations '[{
    "LogLevel": "ERROR",
    "EventSource": "userNotification",
    "CloudWatchLogsConfiguration": {
      "LogGroupArn": "arn:aws:logs:us-east-1:111122223333:log-group:/aws/cognito/userpools/activity"
    }
  }]'
```

**2. CloudTrail for management plane:**
```bash
# Search for Cognito API calls
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=cognito-idp.amazonaws.com \
  --start-time "2025-01-20T00:00:00Z" \
  --end-time "2025-01-27T23:59:59Z"
```

**3. Test Lambda triggers locally:**
```bash
# Invoke Lambda with test event matching trigger input format
aws lambda invoke \
  --function-name PreTokenGenerationV2 \
  --payload file://test-event.json \
  output.json
```

**4. Decode JWT tokens for debugging:**
```bash
# Decode token (header.payload — don't verify signature for debugging)
echo "eyJhbGciOiJSUzI1Ni..." | cut -d'.' -f2 | base64 -d | jq .
```

### 9.3 Security Incident Response Checklist

When a Cognito-related security incident occurs:

1. **Immediate:** `AdminUserGlobalSignOut` — Revoke all tokens for affected user
2. **Immediate:** `AdminDisableUser` — Prevent any new authentication
3. **Investigate:** Check Advanced Security events in CloudWatch
4. **Investigate:** Review CloudTrail for `AdminCreateUser`, `AdminSetUserPassword`, `UpdateUserAttributes` calls
5. **Contain:** If app client compromised → delete and recreate app client (rotates secret)
6. **Recover:** `AdminResetUserPassword` — Force password change
7. **Prevent:** Enable/enforce MFA if not already required
8. **Monitor:** Set CloudWatch Alarms on `SignInSuccesses` / `TokenRefreshSuccesses` spikes

---

## 10. Documentation References

| Document | URL |
|----------|-----|
| Cognito Developer Guide | https://docs.aws.amazon.com/cognito/latest/developerguide/ |
| User Pool Authentication Flow | https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-authentication-flow.html |
| Token Handling | https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-tokens-with-identity-providers.html |
| Identity Pools (Federated Identities) | https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-identity.html |
| Advanced Security Features | https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pool-settings-advanced-security.html |
| Lambda Triggers | https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools-working-with-aws-lambda-triggers.html |
| SAML Federation | https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-saml-idp.html |
| OAuth 2.0 Scopes / Resource Servers | https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-define-resource-servers.html |
| WAF Integration | https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-waf.html |
| Pricing | https://aws.amazon.com/cognito/pricing/ |
| Service Quotas | https://docs.aws.amazon.com/cognito/latest/developerguide/limits.html |
| Well-Architected Security Pillar | https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/ |
| API Gateway JWT Authorizer | https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-jwt-authorizer.html |
| Identity Pool Role Mapping | https://docs.aws.amazon.com/cognito/latest/developerguide/role-based-access-control.html |

---

## Change Log

| Date | Change |
|------|--------|
| 2025-01-27 | Initial creation — complete deep-dive covering all 10 mandatory sections |

---

*All content sourced from official AWS documentation. Verify with latest AWS docs before exam.*
