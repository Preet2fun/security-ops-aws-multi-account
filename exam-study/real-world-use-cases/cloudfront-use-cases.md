# Amazon CloudFront — Real-World Security Use Cases

## Overview
This document covers real-world production scenarios where CloudFront security features solve actual business problems. Each use case includes architecture, configuration details, and the security rationale.

---

## Use Case 1: Multi-Tenant SaaS API Protection with End-to-End TLS

### Business Context
A B2B SaaS company (ITOM/ITSM) serves 500+ enterprise tenants through APIs. Each tenant has different rate limits and data residency requirements. The API must be encrypted end-to-end and protected from abuse.

### Architecture
```
Tenant A (US)          Tenant B (EU)          Tenant C (APAC)
     │                      │                       │
     │ TLS 1.3              │ TLS 1.3               │ TLS 1.3
     ▼                      ▼                       ▼
┌────────────────────────────────────────────────────────────┐
│ CloudFront Distribution                                     │
│ • Domain: api.saasplatform.com                              │
│ • ACM cert: *.saasplatform.com (us-east-1, auto-renew)     │
│ • Security Policy: TLSv1.2_2021                             │
│ • Viewer Protocol: HTTPS Only                               │
│ • WAF Web ACL attached:                                     │
│   - Rate limit: 2000 req/5min per IP                        │
│   - Bot Control: Targeted (blocks scrapers)                 │
│   - Geo match: Block embargoed countries                    │
│   - SQL injection + XSS managed rules                       │
│ • Response Headers Policy:                                  │
│   - HSTS: max-age=31536000; includeSubDomains; preload     │
│   - X-Content-Type-Options: nosniff                         │
│   - X-Frame-Options: DENY                                   │
│   - Referrer-Policy: strict-origin-when-cross-origin        │
├────────────────────────────────────────────────────────────┤
│ Cache Behaviors:                                            │
│ /api/v1/* → API Gateway origin (no caching)                │
│ /static/* → S3 origin (cache 1 year, OAC)                  │
│ /health  → Custom origin (cache 10s)                       │
├────────────────────────────────────────────────────────────┤
│ Origin Configuration:                                       │
│ • API GW: HTTPS Only, TLSv1.2, custom header X-CF-Verify  │
│ • S3: OAC with SigV4, SSE-KMS encryption                  │
└────────────────────────────────────────────────────────────┘
```

### SSL/TLS Configuration
```
Viewer → CloudFront:
  - Security Policy: TLSv1.2_2021
  - Supported: TLS 1.2 + TLS 1.3
  - Key exchange: ECDHE (PFS) + X25519MLKEM768 (quantum-safe for TLS 1.3)
  - Certificate: ACM wildcard, ECDSA P-256 (faster than RSA)
  - SNI: Enabled (free)

CloudFront → API Gateway:
  - Protocol: HTTPS Only
  - TLS: 1.2 minimum
  - Certificate validation: ACM cert on API GW custom domain
  - Custom header: X-CF-Verify: <rotated-monthly-secret>
```

### Security Rationale
- **TLS 1.2 minimum** eliminates BEAST, POODLE, and downgrade attacks
- **ECDSA P-256 cert** reduces TLS handshake latency by 2x vs RSA 2048
- **Custom header** prevents tenants from bypassing CloudFront to hit API GW directly
- **Per-IP rate limiting** stops credential stuffing without affecting legitimate tenants
- **HSTS preload** ensures browsers never attempt HTTP connection

---

## Use Case 2: HIPAA-Compliant Healthcare Platform with Field-Level Encryption

### Business Context
A healthcare SaaS processes patient intake forms containing PHI (Protected Health Information). Regulations require that sensitive data (SSN, medical record number, diagnosis codes) cannot be readable by intermediate systems — only the authorized claims processing service.

### Architecture
```
Patient Browser (submitting intake form)
       │
       │ POST /patient/intake
       │ Body: {
       │   "name": "Jane Doe",
       │   "email": "jane@email.com",
       │   "ssn": "123-45-6789",
       │   "mrn": "MRN-2024-001",
       │   "diagnosis_code": "J18.9"
       │ }
       │
       │ TLS 1.3 (encrypted in transit)
       ▼
┌──────────────────────────────────────────────────────────┐
│ CloudFront (Field-Level Encryption Enabled)               │
│                                                           │
│ FLE Profile: "PHI-Protection"                             │
│ • Fields encrypted:                                       │
│   - ssn → PublicKey-Claims (RSA 2048)                    │
│   - mrn → PublicKey-Claims                               │
│   - diagnosis_code → PublicKey-Claims                    │
│ • Provider: "HealthClaimsProcessor"                       │
│                                                           │
│ After encryption, body becomes:                           │
│ {                                                         │
│   "name": "Jane Doe",           ← plaintext (non-PHI)   │
│   "email": "jane@email.com",    ← plaintext (non-PHI)   │
│   "ssn": "AQC...base64...==",   ← encrypted at edge    │
│   "mrn": "AQC...base64...==",   ← encrypted at edge    │
│   "diagnosis_code": "AQC...==", ← encrypted at edge    │
│ }                                                         │
└──────────────────────────────────────────────────────────┘
       │
       │ TLS 1.2 (encrypted in transit + fields encrypted)
       ▼
┌──────────────────────────────────────────────────────────┐
│ Application Service (EKS)                                 │
│ • Reads name, email (for routing and notifications)      │
│ • CANNOT decrypt ssn, mrn, diagnosis_code                │
│ • Forwards to claims processor                           │
│ • Even if this service is compromised, PHI is safe       │
└──────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│ Claims Processing Service (Isolated EKS namespace)        │
│ • Has private key for "PublicKey-Claims"                  │
│ • Decrypts using AWS Encryption SDK                      │
│ • Processes PHI in HIPAA-compliant environment           │
│ • Private key stored in AWS Secrets Manager              │
│ • Access logged via CloudTrail                           │
└──────────────────────────────────────────────────────────┘
```

### Configuration Steps
1. Generate RSA 2048 key pair: `openssl genrsa -out private_key.pem 2048`
2. Extract public key: `openssl rsa -pubout -in private_key.pem -out public_key.pem`
3. Upload public key to CloudFront → Public Keys
4. Create FLE Profile: map `ssn`, `mrn`, `diagnosis_code` → public key
5. Create FLE Configuration: Content-Type `application/json` → Profile
6. Attach configuration to cache behavior for `/patient/*`
7. Store private key in Secrets Manager with restricted IAM access

### Security Rationale
- **Defense in depth**: Even with TLS termination, data remains encrypted through the stack
- **Least privilege**: Only the claims service has the private key
- **Blast radius**: Compromise of application tier doesn't expose PHI
- **Audit trail**: CloudTrail logs all key access via Secrets Manager
- **Compliance**: Meets HIPAA minimum necessary standard

---

## Use Case 3: Premium Content Platform with Signed Cookies (Video Streaming)

### Business Context
An e-learning platform delivers 4K video content to paid subscribers. Videos use HLS adaptive bitrate streaming (hundreds of .ts segments per video). Content must not be shareable via URL copying.

### Architecture
```
┌──────────────────────────────────────────────────────────┐
│ User Flow                                                 │
│                                                           │
│ 1. User logs in → App validates subscription             │
│ 2. App generates signed cookies (Custom Policy)          │
│ 3. Browser stores cookies for cdn.learnplatform.com      │
│ 4. Video player requests .m3u8 → cookies sent auto       │
│ 5. Each .ts segment request includes same cookies        │
│ 6. CloudFront validates signature on every request       │
└──────────────────────────────────────────────────────────┘

Subscriber Browser
       │
       │ Cookies:
       │   CloudFront-Policy: eyJ...base64-policy...
       │   CloudFront-Signature: abc123...signed...
       │   CloudFront-Key-Pair-Id: K2JCQP3Z7F8X9L
       │
       │ GET /courses/python-101/video/segment-045.ts
       ▼
┌──────────────────────────────────────────────────────────┐
│ CloudFront                                                │
│ • Trusted Key Group: "ContentSigners"                    │
│   - Public key uploaded (RSA 2048)                       │
│ • Validates cookie signature against public key          │
│ • Checks policy conditions:                              │
│   - DateLessThan: 1719100800 (24hr from login)          │
│   - IpAddress: 203.0.113.0/24 (user's network)         │
│   - Resource: https://cdn.learnplatform.com/courses/*   │
│ • Valid → serve from cache or fetch S3                   │
│ • Invalid → 403 Forbidden                               │
├──────────────────────────────────────────────────────────┤
│ Origin: S3 Bucket (with OAC)                             │
│ • Bucket policy: only CloudFront can GetObject          │
│ • SSE-S3 encryption at rest                             │
│ • No public access (Block Public Access = ON)           │
│ • Lifecycle: Glacier after 1 year                       │
└──────────────────────────────────────────────────────────┘
```

### Custom Policy JSON (generated server-side)
```json
{
  "Statement": [{
    "Resource": "https://cdn.learnplatform.com/courses/*",
    "Condition": {
      "DateLessThan": {
        "AWS:EpochTime": 1719100800
      },
      "DateGreaterThan": {
        "AWS:EpochTime": 1719014400
      },
      "IpAddress": {
        "AWS:SourceIp": "203.0.113.0/24"
      }
    }
  }]
}
```

### Why Signed Cookies Over Signed URLs
- HLS stream = 1 playlist + 200-1000 segments → can't modify every URL
- Cookies apply automatically to all matching requests
- Wildcard resource pattern covers entire course content
- No URL modification needed in video player code

### Security Rationale
- **IP restriction**: Cookie only works from user's network (prevents sharing)
- **Time-limited**: 24-hour window (prevents indefinite access after cancellation)
- **S3 not public**: Even if someone finds the S3 URL, they can't access directly
- **Signature validation**: Cryptographic proof that the cookie was issued by your application
- **Key rotation**: Rotate key pairs periodically; old keys can be kept for existing sessions

---

## Use Case 4: B2B Zero-Trust API with Mutual TLS (mTLS)

### Business Context
A fintech company exposes payment processing APIs to partner banks. Each bank must authenticate with a client certificate. No username/password or API keys — only cryptographic identity verification.

### Architecture
```
┌──────────────────────────────────────────────────────────┐
│ Partner Bank System (e.g., HSBC)                          │
│ • Client certificate issued by trusted CA                │
│ • CN: payments-api.hsbc.internal                         │
│ • Signed by: FinTechPartners-CA                          │
└──────────────────────────────────────────────────────────┘
       │
       │ TLS Handshake (mTLS):
       │ 1. CloudFront sends ServerHello + CertificateRequest
       │ 2. Client sends its certificate + CertificateVerify
       │ 3. CloudFront validates against trust store
       ▼
┌──────────────────────────────────────────────────────────┐
│ CloudFront (Viewer mTLS Enabled)                          │
│                                                           │
│ Trust Store Configuration:                                │
│ • CA Certificate: FinTechPartners-CA.pem                 │
│ • Validates: cert chain, expiration, signature           │
│ • CRL/OCSP: Checks revocation status                    │
│                                                           │
│ On Successful mTLS:                                       │
│ • Adds headers to origin request:                        │
│   X-Amz-Cf-Client-Cert-Verified: SUCCESS                │
│   X-Amz-Cf-Client-Cert-Subject: CN=payments-api.hsbc... │
│   X-Amz-Cf-Client-Cert-Serial: 0A:1B:2C:3D...          │
│   X-Amz-Cf-Client-Cert-Issuer: CN=FinTechPartners-CA   │
│   X-Amz-Cf-Client-Cert-Not-Before: 2024-01-01          │
│   X-Amz-Cf-Client-Cert-Not-After: 2025-01-01           │
│                                                           │
│ On Failed mTLS:                                           │
│ • Returns 403 (TLS handshake fails — no HTTP response)  │
├──────────────────────────────────────────────────────────┤
│ Lambda@Edge (Viewer Request)                              │
│ • Reads X-Amz-Cf-Client-Cert-Subject header             │
│ • Extracts partner ID from CN                            │
│ • Validates against DynamoDB partner registry            │
│ • Sets X-Partner-Id and X-Rate-Limit headers            │
│ • Blocks if partner is suspended                         │
├──────────────────────────────────────────────────────────┤
│ CloudFront → Origin (also mTLS)                          │
│ • CloudFront presents its own client certificate         │
│ • Origin ALB validates CloudFront's cert                 │
│ • Double authentication: both directions verified        │
└──────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│ Payment Processing Service                                │
│ • Receives verified partner identity in headers          │
│ • Applies partner-specific rate limits                   │
│ • Processes transaction with partner context             │
│ • All access logged with partner cert serial number      │
└──────────────────────────────────────────────────────────┘
```

### Security Rationale
- **No shared secrets**: Certificates can't be guessed or brute-forced (unlike API keys)
- **Non-repudiation**: Each request is cryptographically tied to the partner's identity
- **Revocation**: Compromised partner certs can be revoked immediately via CRL
- **Zero-trust**: Both viewer and origin must prove identity — no implicit trust
- **Audit trail**: Certificate serial number provides forensic traceability

---

## Use Case 5: Global E-Commerce with Geographic Compliance & DDoS Protection

### Business Context
An e-commerce platform operates in 30+ countries. Must comply with data residency requirements (EU data in EU, no service to OFAC-sanctioned countries). Experiences regular DDoS attacks during flash sales.

### Architecture
```
┌──────────────────────────────────────────────────────────┐
│ CloudFront Distribution: shop.globalcommerce.com          │
│                                                           │
│ Shield Advanced: ENABLED                                  │
│ • DDoS Response Team (DRT) access granted               │
│ • Cost protection for scaling during attack              │
│ • Health-based detection (Route 53 health checks)        │
│                                                           │
│ WAF Web ACL:                                             │
│ • Rule 1: Geo-Block (DENY): KP, IR, CU, SY, RU        │
│ • Rule 2: Rate Limit: 5000 req/5min per IP             │
│ • Rule 3: AWS Bot Control (Targeted)                    │
│ • Rule 4: AWS Managed Rules - Known Bad Inputs          │
│ • Rule 5: AWS Managed Rules - SQLi/XSS                  │
│ • Rule 6: Custom Rule - Block TOR exit nodes            │
│                                                           │
│ Geo Restriction (CloudFront native):                     │
│ • Blacklist: KP, IR, CU, SY (OFAC sanctioned)          │
│                                                           │
│ Cache Behaviors:                                         │
│ /api/checkout/* → Origin Group (failover)               │
│   Primary: ALB eu-west-1                                │
│   Secondary: ALB us-east-1                              │
│ /api/eu/* → ALB eu-west-1 only (data residency)        │
│ /static/* → S3 with OAC (cache 1 year)                 │
├──────────────────────────────────────────────────────────┤
│ SSL/TLS:                                                  │
│ • Viewer: TLSv1.2_2021 (TLS 1.2+1.3, strong ciphers)   │
│ • Origin: HTTPS Only, TLSv1.2                           │
│ • Certificate: ACM wildcard *.globalcommerce.com        │
│ • HSTS: max-age=63072000; includeSubDomains; preload    │
└──────────────────────────────────────────────────────────┘
```

### DDoS Attack Scenario (Flash Sale)
```
Normal traffic: 50,000 req/min
Attack traffic: 5,000,000 req/min (100x spike)

Shield Advanced Response:
1. Automatic detection (baseline deviation)
2. Traffic profiling (identifies attack signature)
3. WAF rate limiting blocks individual IPs
4. Shield Advanced scales CloudFront capacity
5. DRT contacted for complex Layer 7 attacks
6. Cost protection: AWS doesn't charge for attack traffic
7. Post-attack: Forensic report generated
```

### Security Rationale
- **Dual geo-blocking**: WAF (flexible rules) + CloudFront native (simple blacklist) for defense-in-depth
- **Origin failover**: If primary region goes down, traffic automatically routes to secondary
- **Data residency**: Separate cache behaviors route EU API calls only to EU origins
- **Cost protection**: Shield Advanced caps costs during volumetric attacks
- **Layered rate limiting**: CloudFront + WAF + API Gateway (each at different threshold)

---

## Use Case 6: Static Website with Complete Origin Lockdown (S3 + OAC + KMS)

### Business Context
A company hosts their marketing website and customer portal static assets on S3. Requirements: no public bucket access, encryption at rest with customer-managed KMS key, and only CloudFront can serve the content.

### Architecture
```
User Browser
       │
       │ HTTPS (TLS 1.3)
       ▼
┌──────────────────────────────────────────────────────────┐
│ CloudFront Distribution                                   │
│ • Default root object: index.html                        │
│ • Custom error pages: 403 → /404.html                   │
│ • Viewer Protocol: Redirect HTTP to HTTPS                │
│ • Origin Access Control (OAC): Enabled                   │
│   - Signing behavior: Always sign                        │
│   - Signing protocol: SigV4                              │
│   - Origin type: S3                                      │
└──────────────────────────────────────────────────────────┘
       │
       │ SigV4 signed request (via OAC)
       ▼
┌──────────────────────────────────────────────────────────┐
│ S3 Bucket: website-assets-prod                           │
│                                                           │
│ Block Public Access: ALL ENABLED                         │
│ Bucket Policy:                                           │
│ {                                                         │
│   "Effect": "Allow",                                     │
│   "Principal": {                                         │
│     "Service": "cloudfront.amazonaws.com"                │
│   },                                                      │
│   "Action": ["s3:GetObject", "s3:ListBucket"],           │
│   "Resource": [                                           │
│     "arn:aws:s3:::website-assets-prod",                  │
│     "arn:aws:s3:::website-assets-prod/*"                 │
│   ],                                                      │
│   "Condition": {                                         │
│     "StringEquals": {                                    │
│       "AWS:SourceArn":                                   │
│         "arn:aws:cloudfront::123456789012:distribution/E1X2Y3Z4"│
│     }                                                     │
│   }                                                       │
│ }                                                         │
│                                                           │
│ Encryption: SSE-KMS (Customer Managed Key)               │
│ KMS Key Policy must include:                             │
│ {                                                         │
│   "Effect": "Allow",                                     │
│   "Principal": {                                         │
│     "Service": "cloudfront.amazonaws.com"                │
│   },                                                      │
│   "Action": "kms:Decrypt",                               │
│   "Resource": "*",                                       │
│   "Condition": {                                         │
│     "StringEquals": {                                    │
│       "AWS:SourceArn":                                   │
│         "arn:aws:cloudfront::123456789012:distribution/E1X2Y3Z4"│
│     }                                                     │
│   }                                                       │
│ }                                                         │
└──────────────────────────────────────────────────────────┘
```

### Key Configuration Points
- **OAC + SSE-KMS**: Requires KMS key policy granting `kms:Decrypt` to CloudFront service principal — this is a common gotcha
- **Block Public Access**: Entire bucket locked down, OAC is the only path
- **ListBucket permission**: Needed so CloudFront gets proper 404 (not 403) for missing objects
- **Custom error pages**: Map 403 → friendly 404 page (hides bucket existence)

### Security Rationale
- **Zero direct access**: S3 URL returns 403 even if someone discovers the bucket name
- **Encryption at rest**: CMK means you control key lifecycle and audit access
- **No data leakage**: Combined with Response Headers Policy (CSP, X-Frame-Options)
- **Origin lockdown**: Condition on specific distribution ARN prevents other distributions from using this bucket

---

## Use Case 7: Microservices with Lambda@Edge JWT Validation

### Business Context
A SaaS platform uses microservices behind CloudFront. Instead of each microservice implementing JWT validation independently, the company validates tokens at the edge — rejecting unauthorized requests before they reach any origin.

### Architecture
```
Mobile App / SPA
       │
       │ Authorization: Bearer eyJhbGciOiJSUzI1NiI...
       │ TLS 1.3
       ▼
┌──────────────────────────────────────────────────────────┐
│ CloudFront                                                │
│                                                           │
│ Lambda@Edge (Viewer Request trigger):                     │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ 1. Extract Authorization header                       │ │
│ │ 2. Decode JWT (header.payload.signature)             │ │
│ │ 3. Fetch JWKS from cache (Cognito/.well-known)      │ │
│ │ 4. Verify signature with public key                  │ │
│ │ 5. Check expiration (exp claim)                      │ │
│ │ 6. Check audience (aud claim)                        │ │
│ │ 7. Check issuer (iss claim)                          │ │
│ │ 8. Extract tenant_id from custom claim               │ │
│ │                                                       │ │
│ │ On VALID:                                            │ │
│ │   → Add header: X-Tenant-Id: tenant_123             │ │
│ │   → Add header: X-User-Role: admin                  │ │
│ │   → Forward request to origin                        │ │
│ │                                                       │ │
│ │ On INVALID:                                          │ │
│ │   → Return 401 Unauthorized immediately             │ │
│ │   → Request never reaches origin                    │ │
│ └──────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
       │
       │ Only valid, enriched requests reach origin
       ▼
┌──────────────────────────────────────────────────────────┐
│ Origin (ALB → EKS Microservices)                         │
│ • Trusts X-Tenant-Id header (already validated)         │
│ • Applies tenant-specific business logic                │
│ • No JWT library needed in each microservice            │
│ • Reduced attack surface on compute layer               │
└──────────────────────────────────────────────────────────┘
```

### Security Rationale
- **Shift-left security**: Invalid requests rejected at the edge (nearest to attacker)
- **Reduced origin load**: 30-40% of requests may be bots/unauthenticated — filtered before reaching compute
- **Consistent enforcement**: All microservices get same auth validation without implementing it individually
- **Latency benefit**: Token validation at edge = lower latency than origin-side validation
- **Tenant context propagation**: Trusted headers eliminate need for each service to re-validate

---

## Use Case 8: Certificate Rotation & Disaster Recovery

### Business Context
A financial services company must maintain zero-downtime during certificate rotation and have a plan for certificate compromise/expiry incidents.

### Normal Certificate Lifecycle
```
┌─────────────────────────────────────────────────────────┐
│ ACM Auto-Renewal (Recommended Path)                      │
│                                                          │
│ Day 0: ACM cert issued (valid 13 months)                │
│ Day 60 before expiry: ACM starts auto-renewal           │
│ Day 30 before expiry: ACM completes renewal             │
│ Continuous: CloudFront deploys new cert to all edges    │
│ Result: Zero manual intervention, zero downtime          │
└─────────────────────────────────────────────────────────┘
```

### Emergency: Certificate Compromise Response
```
Incident: Private key potentially leaked

Response Timeline:
├── T+0min: Alert from security monitoring
├── T+5min: Revoke compromised cert in ACM
├── T+10min: Request new certificate in ACM (us-east-1)
│            - DNS validation (instant if Route 53)
│            - Or email validation (slower)
├── T+15min: Associate new cert with CloudFront distribution
├── T+20min: CloudFront begins deploying to edge locations
├── T+35min: Full deployment to all 450+ edge locations
├── T+40min: Verify via curl/openssl that new cert is served
└── T+60min: Confirm old cert no longer served anywhere

Key Points:
• ACM cert deployment to CloudFront takes ~15-35 minutes
• During deployment, some edges serve old cert, some new
• Both old and new cert are valid during transition
• CloudFront does NOT support SSL renegotiation (limits exploit window)
• HSTS preload prevents downgrade during transition
```

### Imported Certificate Rotation (Non-ACM)
```
For imported certs (e.g., from DigiCert/Comodo):

1. Import new cert to ACM (us-east-1) 24+ hours before expiry
2. Update CloudFront distribution to use new cert
3. Wait for full deployment (check all edges)
4. Verify with: openssl s_client -connect domain:443 -servername domain

WARNING: If cert expires before rotation:
• CloudFront continues serving with expired cert
• Browsers show security warnings
• Some clients refuse connection entirely
• Recovery: Import valid cert → update distribution → 15-35 min deploy
```

### Security Rationale
- **ACM auto-renewal eliminates human error** (most common cause of cert expiry)
- **24-hour rotation window**: Always rotate 24+ hours before expiry (CloudFront propagation is async)
- **HSTS preload**: Even during rotation, browsers enforce HTTPS
- **Monitor with Config**: AWS Config rule `cloudfront-viewer-policy-https` detects misconfigurations

---

## Use Case 9: Multi-Account CloudFront with Centralized Security

### Business Context
Large enterprise with separate AWS accounts for dev/staging/prod. Security team in the Audit account needs visibility into all CloudFront distributions and enforcement of security standards.

### Architecture
```
┌──────────────────────────────────────────────────────────┐
│ Management Account (Organizations)                        │
│ • SCP: Deny CloudFront without WAF attachment           │
│ • SCP: Deny security policy older than TLSv1.2_2021    │
└──────────────────────────────────────────────────────────┘
       │
       ├─────────────────────────────────────────────────────
       │
┌──────────────────────────────────────────────────────────┐
│ Workload Accounts (Dev / Staging / Prod)                  │
│ • CloudFront distributions created here                  │
│ • ACM certificates managed here (us-east-1)             │
│ • WAF Web ACLs managed here (or shared via Firewall Mgr)│
│ • Access logs → Logging Account S3 bucket               │
└──────────────────────────────────────────────────────────┘
       │
       ├─────────────────────────────────────────────────────
       │
┌──────────────────────────────────────────────────────────┐
│ Audit Account                                             │
│ • AWS Config Aggregator: monitors all accounts           │
│ • Config Rules:                                          │
│   - cloudfront-viewer-policy-https                       │
│   - cloudfront-default-root-object-configured            │
│   - cloudfront-origin-access-identity-enabled            │
│   - cloudfront-sni-enabled                               │
│   - cloudfront-minimum-protocol-version (≥ TLSv1.2)     │
│ • Security Hub: aggregates CloudFront findings           │
│ • Custom Lambda: alerts on non-compliant distributions   │
└──────────────────────────────────────────────────────────┘
       │
       ├─────────────────────────────────────────────────────
       │
┌──────────────────────────────────────────────────────────┐
│ Logging Account                                           │
│ • S3 bucket receives ALL CloudFront access logs          │
│ • Cross-account bucket policy allows CloudFront service  │
│ • Real-time logs → Kinesis → OpenSearch (SIEM)          │
│ • Retention: 90 days hot, 1 year Glacier, 7 year archive│
└──────────────────────────────────────────────────────────┘
```

### SCP to Enforce Minimum TLS
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyWeakTLS",
      "Effect": "Deny",
      "Action": [
        "cloudfront:CreateDistribution",
        "cloudfront:UpdateDistribution"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "cloudfront:ViewerProtocolPolicy": "https-only"
        }
      }
    }
  ]
}
```

### Security Rationale
- **Preventive controls (SCPs)**: Stop insecure distributions from being created
- **Detective controls (Config)**: Find existing non-compliant distributions
- **Centralized logging**: Security team has access to all access logs without accessing workload accounts
- **Consistent enforcement**: Firewall Manager can deploy WAF rules to all accounts

---

## Summary: When to Use Which CloudFront Security Feature

| Scenario | Feature |
|----------|---------|
| Protect S3 content from direct access | OAC |
| Protect ALB/EC2/API GW from direct access | Custom headers + security groups |
| Restrict content to paid users | Signed URLs or Signed Cookies |
| Encrypt sensitive form fields end-to-end | Field-Level Encryption |
| Block malicious requests | WAF Web ACL |
| Absorb DDoS attacks | Shield Standard (auto) + Advanced (paid) |
| Enforce HTTPS | Viewer Protocol Policy + HSTS |
| Verify client identity (B2B) | Mutual TLS (mTLS) |
| Validate tokens at edge | Lambda@Edge |
| Add security headers | Response Headers Policy |
| Block countries | Geo Restriction + WAF Geo Match |
| Prevent domain fronting | Automatic (cert account validation) |

---

*All content sourced from official AWS documentation via AWS Knowledge and Documentation MCP servers. Last updated: June 2026.*
