# Amazon CloudFront — Deep Dive for Security Specialty Exam
<!-- STALE: CVE-2026-13762 / CVE-2026-13763 — AWS WAF HTTP/2 multi-frame request body inspection on CloudFront and ALB (2026-09-22) — run @content-updater cloudfront to refresh -->

## 1. Service Introduction & Significance

### What is Amazon CloudFront?
Amazon CloudFront is a global Content Delivery Network (CDN) service that securely delivers data, videos, applications, and APIs to users with low latency and high transfer speeds. It operates through a worldwide network of **450+ edge locations** and **13 regional edge caches** across 100+ cities in 50+ countries.

### Security Significance
CloudFront is the **first line of defense** in any AWS web application architecture. It sits at the edge of the network — between the internet and your origin servers — making it critical for:
- **DDoS absorption** — Shield Standard is automatically integrated
- **TLS termination** — Encrypts all viewer-to-edge traffic
- **Access control** — Signed URLs/cookies restrict content access
- **WAF integration** — Inspects and filters malicious requests before they reach origin
- **Origin protection** — Hides and restricts direct access to your backend

### Key Use Cases for SaaS/Enterprise
- Global API acceleration with edge-based security enforcement
- Multi-tenant content delivery with per-tenant access controls
- Static asset delivery with origin access control (OAC)
- Real-time streaming with DRM and signed cookie protection
- Field-level encryption for sensitive form data (PCI compliance)

---

## 2. Behind-the-Scenes Technical Flow

### How CloudFront Processes Requests (HTTPS End-to-End)

```
┌──────────┐    TLS 1.3    ┌─────────────┐    TLS 1.2+    ┌──────────┐
│  Viewer  │ ──────────── │ CloudFront  │ ─────────────── │  Origin  │
│ (Browser)│   Handshake   │ Edge Location│   Handshake    │ (S3/ALB) │
└──────────┘               └─────────────┘                └──────────┘
     │                           │                              │
     │ 1. DNS resolution         │                              │
     │    (Route 53 → CF)        │                              │
     │                           │                              │
     │ 2. TLS negotiation        │                              │
     │    (SNI → cert selection) │                              │
     │                           │                              │
     │ 3. HTTP request           │                              │
     │    (encrypted)            │                              │
     │                           │ 4. Cache check               │
     │                           │    (HIT → serve cached)      │
     │                           │                              │
     │                           │ 5. MISS → Origin request     │
     │                           │    (TLS to origin)           │
     │                           │                              │
     │                           │ 6. Cache response            │
     │                           │                              │
     │ 7. Return to viewer       │                              │
     │    (re-encrypted)         │                              │
     └───────────────────────────┘                              │
```

### Single-Account Flow
1. **DNS Resolution**: Route 53 alias record points to CloudFront distribution domain (d1234.cloudfront.net)
2. **Anycast Routing**: Request routed to nearest edge location via AWS global network
3. **TLS Termination**: Edge terminates TLS using certificate from ACM (stored encrypted with KMS)
4. **Cache Evaluation**: CloudFront checks cache based on cache key (URL, headers, cookies, query strings)
5. **Origin Fetch** (on MISS): CloudFront initiates new TLS connection to origin, sends request
6. **Response Caching**: Response cached at edge and optionally at Regional Edge Cache
7. **Response to Viewer**: Re-encrypted and delivered to viewer

**Key Internal Detail**: CloudFront uses the **s2n-tls library** (AWS's lightweight ~6,000-line TLS implementation) instead of OpenSSL for TLS operations. Private keys from ACM are encrypted with KMS, rotated every 24 hours, and never stored on disk at edge locations.

### Multi-Account Flow
In a multi-account Organizations setup:

```
┌─────────────────────────────────────────────────────────────────┐
│  Workload Account                                                │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  CloudFront Distribution                                    │ │
│  │  - ACM certificate (us-east-1 only)                        │ │
│  │  - WAF Web ACL attached                                    │ │
│  │  - OAC for S3 origin in same or different account          │ │
│  │  - Custom headers for ALB origin authentication            │ │
│  └────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  Logging Account                                                 │
│  - CloudFront access logs → S3 bucket (cross-account)           │
│  - Real-time logs → Kinesis Data Stream → S3/OpenSearch         │
├─────────────────────────────────────────────────────────────────┤
│  Audit Account                                                   │
│  - CloudTrail capturing CloudFront API calls                    │
│  - Config rules monitoring CloudFront compliance                │
│  - Security Hub findings for misconfigurations                  │
└─────────────────────────────────────────────────────────────────┘
```

**Cross-Account OAC Pattern**: CloudFront in Account A can use OAC to access S3 bucket in Account B. The bucket policy in Account B must grant `s3:GetObject` to the CloudFront service principal with a condition on the distribution ARN.

**Cross-Account Logging**: Standard access logs can be delivered to S3 buckets in other accounts. Real-time logs go to Kinesis Data Streams (same account only), which can then fan out cross-account.

---

## 3. Step-by-Step Configuration & Security Significance

### 3.1 SSL/TLS Configuration (Viewer ↔ CloudFront)

#### Viewer Protocol Policy
| Setting | Behavior | Security Significance |
|---------|----------|----------------------|
| HTTP and HTTPS | Accepts both | ❌ **Insecure** — allows unencrypted traffic |
| Redirect HTTP to HTTPS | 301 redirect | ✅ User-friendly enforcement of encryption |
| HTTPS Only | Rejects HTTP with 403 | ✅ Strictest — no plaintext exposure |

**Recommendation**: Use "Redirect HTTP to HTTPS" for public sites, "HTTPS Only" for APIs.

#### Security Policies (TLS Minimum Version)
| Policy | Min TLS | Use Case |
|--------|---------|----------|
| TLSv1.3_2025 | TLS 1.3 only | Maximum security, modern clients only |
| TLSv1.2_2025 | TLS 1.2 | Strong security with broad compatibility |
| TLSv1.2_2021 | TLS 1.2 | Recommended default for most workloads |
| TLSv1.2_2019 | TLS 1.2 | Slightly broader cipher support |
| TLSv1.2_2018 | TLS 1.2 | Legacy cipher support |
| TLSv1.1_2016 | TLS 1.1 | ⚠️ Deprecated protocol support |
| TLSv1_2016 | TLS 1.0 | ❌ Weak — only for legacy compatibility |
| TLSv1 | TLS 1.0 | ❌ Weak |
| SSLv3 | SSL 3.0 | ❌ **Never use** — vulnerable to POODLE |

**Exam-Critical**: TLSv1.2_2021 is the recommended minimum. TLS 1.3 provides perfect forward secrecy, one-roundtrip handshake, and eliminates weak cipher suites. CloudFront now supports **quantum-safe key exchanges** (X25519MLKEM768) but only with TLS 1.3.

#### Certificate Requirements
- **ACM Region**: Certificates MUST be in **us-east-1** (N. Virginia) for CloudFront
- **Key Types**: RSA (up to 4096-bit) or ECDSA (prime256v1 / P-256)
- **Format**: X.509 PEM
- **ACM vs Imported**: ACM handles auto-renewal; imported certs need manual renewal 24hrs before expiry
- **Domain Matching**: Certificate SAN must cover all alternate domain names (CNAMEs)

#### SNI (Server Name Indication)
- **SNI** (default, free): Client sends hostname in TLS handshake; CloudFront selects correct cert
- **Dedicated IP**: Legacy clients without SNI support; **$600/month per distribution** — rarely needed

### 3.2 SSL/TLS Configuration (CloudFront ↔ Origin)

#### Origin Protocol Policy
| Setting | Behavior | When to Use |
|---------|----------|-------------|
| HTTP Only | Always HTTP to origin | Never for production |
| HTTPS Only | Always HTTPS to origin | ✅ Custom origins (ALB, EC2, API GW) |
| Match Viewer | Same protocol as viewer request | S3 website endpoints |

**For S3 origins with OAC**: CloudFront always uses HTTPS automatically (SIGV4 signed requests).

#### Origin SSL Protocols
- TLSv1.2 (recommended minimum)
- TLSv1.1, TLSv1 (legacy only)
- SSLv3 (never use)

**Certificate Requirements for Custom Origins**:
- Must be issued by a CA in the Mozilla Included CA Certificate List
- Certificate CN or SAN must match the Origin Domain Name
- Certificate chain must be complete (intermediate certs included)
- Self-signed certificates are **NOT supported** for custom origins

### 3.3 Origin Access Control (OAC)

OAC replaces the legacy Origin Access Identity (OAI) for restricting S3 origin access.

**How OAC Works**:
1. CloudFront signs requests to S3 using SigV4
2. S3 bucket policy grants access to `cloudfront.amazonaws.com` service principal
3. Condition restricts to specific distribution ARN

**OAC vs OAI Comparison**:
| Feature | OAC | OAI (Legacy) |
|---------|-----|--------------|
| S3 SSE-KMS support | ✅ | ❌ |
| S3 in all regions | ✅ | ✅ |
| PUT/DELETE support | ✅ | ❌ |
| SigV4 signing | ✅ | Custom |
| Granular bucket policies | ✅ | Limited |

**Bucket Policy for OAC**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-bucket/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::111122223333:distribution/EDFDVBD6EXAMPLE"
        }
      }
    }
  ]
}
```

### 3.4 Signed URLs and Signed Cookies

**Purpose**: Restrict access to content in CloudFront edge caches to authorized users only.

**When to Use Each**:
| Method | Use Case |
|--------|----------|
| Signed URLs | Individual file access, sharing specific content |
| Signed Cookies | Multiple files (HLS streaming), no URL modification |

**Key Concepts**:
- **Trusted Key Groups** (recommended): Create key pairs, upload public key to CloudFront, sign with private key
- **Canned Policy**: Simple — includes URL and expiration only
- **Custom Policy**: Flexible — start/end time, IP range restrictions, wildcard URLs
- **Key Requirements**: RSA 2048 or ECDSA 256 private keys for signing

**Signed URL Structure**:
```
https://d1234.cloudfront.net/content/video.mp4
  ?Policy=<Base64-encoded-policy>
  &Signature=<hashed-and-signed>
  &Key-Pair-Id=<key-pair-id>
```

### 3.5 Field-Level Encryption

**Purpose**: Encrypt specific sensitive fields (credit card numbers, SSN) at the edge using asymmetric encryption. Data remains encrypted through the entire application stack until the specific service that needs it decrypts with the private key.

**How It Works**:
1. Create RSA 2048-bit key pair
2. Upload public key to CloudFront
3. Create encryption profile (map fields → public key)
4. Create configuration (map content type → profile)
5. Link configuration to cache behavior

**Key Details**:
- Encrypts up to 10 individual fields per request (POST body)
- Uses asymmetric (public-key) encryption
- Origin must support chunked encoding
- Encrypted using AWS Encryption SDK format
- Decryption uses private key at the specific origin service

**Use Case**: PCI DSS compliance — credit card fields encrypted at edge, only payment processor has private key.

### 3.6 Response Headers Policy (Security Headers)

CloudFront can add security headers to all responses without modifying your origin:

| Header | Purpose | Recommended Value |
|--------|---------|-------------------|
| `Strict-Transport-Security` (HSTS) | Forces HTTPS for future requests | `max-age=31536000; includeSubDomains; preload` |
| `Content-Security-Policy` | Controls resource loading sources | Application-specific |
| `X-Content-Type-Options` | Prevents MIME sniffing | `nosniff` |
| `X-Frame-Options` | Prevents clickjacking | `DENY` or `SAMEORIGIN` |
| `X-XSS-Protection` | Legacy XSS filter | `1; mode=block` |
| `Referrer-Policy` | Controls referrer information | `strict-origin-when-cross-origin` |

**Configuration**: Create a Response Headers Policy and attach to cache behaviors. "Origin override" setting controls whether CloudFront's policy headers override origin headers.

### 3.7 Geographic Restrictions

- **Whitelist**: Allow access only from specified countries
- **Blacklist**: Block access from specified countries
- Uses MaxMind GeoIP database for IP → country mapping
- Returns HTTP 403 for blocked viewers
- Country codes use ISO 3166-1 alpha-2 format

### 3.8 AWS WAF Integration

- WAF Web ACL attaches directly to CloudFront distribution
- Inspects requests BEFORE they reach origin
- Supports rate limiting, IP blocking, bot control, SQL injection/XSS protection
- One-click setup available via CloudFront Security Dashboard
- **Exam-Critical**: WAF on CloudFront is the only way to protect non-AWS origins (on-prem servers)

### 3.9 Custom Headers for Origin Restriction

For custom origins (ALB, API Gateway, EC2):
1. Configure CloudFront to add a secret custom header (e.g., `X-Origin-Verify: <secret>`)
2. Configure origin to reject requests without this header
3. Rotate the header value periodically

This prevents bypassing CloudFront by accessing the origin directly.

### 3.10 Mutual TLS (mTLS)

**Viewer mTLS**: CloudFront can require client certificates from viewers:
- Upload trusted CA certificate bundle to CloudFront trust store
- CloudFront verifies client cert during TLS handshake
- Use for B2B APIs, IoT devices, internal services

**Origin mTLS**: CloudFront can present a client certificate to origin:
- Upload client certificate to CloudFront
- Origin validates the certificate
- Ensures only CloudFront can reach the origin

### 3.11 Lambda@Edge and CloudFront Functions

**Security Use Cases**:
- Token validation and JWT verification at the edge
- Bot detection and fingerprinting
- Dynamic header manipulation
- Request signing (SigV4) for protected origins
- A/B testing with tenant isolation

| Feature | CloudFront Functions | Lambda@Edge |
|---------|---------------------|-------------|
| Runtime | JavaScript | Node.js, Python |
| Execution time | <1ms | Up to 30s (origin) |
| Triggers | Viewer request/response | All 4 events |
| Network access | ❌ | ✅ |
| Use case | Simple transforms | Complex auth logic |

---

## 4. Threat Mitigation Coverage

### Infrastructure-Level Threats

| Threat | How CloudFront Mitigates |
|--------|--------------------------|
| **DDoS (Layer 3/4)** | Shield Standard automatic protection on all distributions |
| **DDoS (Layer 7)** | WAF rate limiting + bot control + geo blocking |
| **TLS downgrade attacks** | Enforce minimum TLS 1.2/1.3 via security policy |
| **SSL renegotiation attacks** | CloudFront does NOT support renegotiation |
| **Origin exposure** | OAC (S3) / custom headers (ALB) / VPC origins |
| **DNS hijacking** | DNSSEC support via Route 53 + HTTPS enforcement |
| **Domain fronting abuse** | Account validation — cert account must match request account (421 response) |

### Application-Level Threats

| Threat | How CloudFront Mitigates |
|--------|--------------------------|
| **SQL Injection / XSS** | WAF managed rules (OWASP Top 10) |
| **Bot traffic** | WAF Bot Control (common/targeted) |
| **Content scraping** | Signed URLs/cookies + rate limiting |
| **Clickjacking** | Response headers policy (X-Frame-Options) |
| **MIME sniffing** | X-Content-Type-Options: nosniff |
| **Data exfiltration** | Field-level encryption protects sensitive fields end-to-end |
| **Man-in-the-middle** | Forced HTTPS + HSTS preload |
| **Unauthorized access** | Signed URLs/cookies + geo restriction + IP allowlists |
| **Credential theft** | mTLS for B2B, OAuth/JWT validation at edge |

### Attack Scenarios CloudFront Defends Against

1. **Volumetric DDoS**: Shield Standard absorbs at edge; Shield Advanced provides DRT + cost protection
2. **Slowloris**: Connection timeout settings (1-60 seconds) + Shield protection
3. **Account Takeover**: WAF account takeover prevention rules
4. **API Abuse**: Per-IP rate limiting + API key validation at edge
5. **Content Theft**: Signed URLs with IP restriction + short expiry

---

## 5. Defense-in-Depth Positioning

### Where CloudFront Sits in the Security Model

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 1: EDGE (CloudFront + WAF + Shield)                        │  ← PREVENTIVE + DETECTIVE
│  • TLS termination + certificate management                      │
│  • DDoS absorption (Shield)                                      │
│  • Request filtering (WAF rules)                                 │
│  • Geo restriction                                               │
│  • Bot management                                                │
│  • Rate limiting                                                 │
│  • Signed URLs/cookies                                           │
├─────────────────────────────────────────────────────────────────┤
│ Layer 2: NETWORK (VPC + Security Groups)                         │  ← PREVENTIVE
│  • VPC isolation                                                 │
│  • Security groups (CF managed prefix list)                      │
│  • NACLs                                                         │
├─────────────────────────────────────────────────────────────────┤
│ Layer 3: APPLICATION (ALB + API GW + EKS)                        │  ← PREVENTIVE + DETECTIVE
│  • Custom header validation                                      │
│  • JWT/OAuth validation                                          │
│  • Input validation                                              │
├─────────────────────────────────────────────────────────────────┤
│ Layer 4: DATA (RDS + S3 + KMS)                                   │  ← PREVENTIVE
│  • Field-level encryption (from edge)                            │
│  • Encryption at rest                                            │
│  • OAC restricting S3 access                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Integration with Other Security Services

| Service | Integration Pattern |
|---------|---------------------|
| **AWS WAF** | Web ACL attached to distribution; inspects all requests |
| **AWS Shield Standard** | Automatic on all distributions (free) |
| **AWS Shield Advanced** | Enhanced DDoS protection + DRT + cost protection |
| **Route 53** | DNSSEC + alias records + health checks |
| **ACM** | Auto-renewing SSL/TLS certs (us-east-1) |
| **AWS Config** | Rules: HTTPS enforcement, TLS version, logging enabled |
| **CloudTrail** | Logs all CloudFront API calls |
| **CloudWatch** | Metrics: requests, errors, cache hit ratio |
| **S3** | Access logs destination + origin with OAC |
| **KMS** | Encrypts private keys at edge; used for SSE-KMS with OAC |

### AWS Well-Architected Security Pillar Alignment

| Principle | CloudFront Implementation |
|-----------|---------------------------|
| **SEC01 (Security Foundations)** | Edge-first security model reduces origin exposure |
| **SEC02 (IAM)** | OAC uses service principal auth; signed URLs for viewer auth |
| **SEC03 (Detection)** | Real-time logs, CloudWatch metrics, WAF logging |
| **SEC04 (Infrastructure Protection)** | Network edge filtering, geo restriction, Shield |
| **SEC05 (Data Protection)** | TLS in transit, field-level encryption, HSTS |
| **SEC06 (Incident Response)** | Real-time logging enables rapid investigation |

### Cost vs Risk Recommendations

| Feature | Cost | Security Value | Recommendation |
|---------|------|----------------|----------------|
| CloudFront + Shield Standard | Free (per-request pricing) | High | ✅ Always use |
| TLS 1.2+ enforcement | Free | High | ✅ Always enforce |
| WAF (basic rules) | ~$5/month + per-request | High | ✅ Essential for public apps |
| Shield Advanced | $3,000/month | Medium-High | Only for critical production |
| Dedicated IP SSL | $600/month | Low | Only for legacy client support |
| Field-level encryption | Free (compute overhead) | High for PCI | Only when handling sensitive fields |
| Real-time logs | Per-record pricing | Medium | Recommended for security monitoring |

---

## 6. Exam-Critical Points

### 🎯 Must-Know Facts for SCS-C03

1. **ACM certificates for CloudFront MUST be in us-east-1** — this is the #1 tested fact
2. **OAC replaces OAI** — OAC supports SSE-KMS, PUT/DELETE, and SigV4; OAI is legacy
3. **Security policy determines minimum TLS** — know the policy names and what they allow
4. **CloudFront does NOT support SSL renegotiation** — security feature, not a limitation
5. **Signed URLs vs Signed Cookies**: URLs for individual files, cookies for multiple files/streams
6. **Field-level encryption ≠ S3 encryption**: FLE encrypts specific fields at edge for end-to-end protection
7. **WAF Web ACLs on CloudFront can protect non-AWS origins** — only edge-based WAF can do this
8. **Custom headers for ALB origin restriction** — rotate headers periodically
9. **Geo restriction uses MaxMind database** — not 100% accurate for VPNs/proxies
10. **Shield Standard is automatic and free on ALL CloudFront distributions**
11. **Domain fronting mitigation**: CloudFront validates cert account matches requesting account
12. **s2n-tls library**: AWS's lightweight TLS implementation used at all edge locations
13. **Quantum-safe key exchange**: Only with TLS 1.3 (X25519MLKEM768)
14. **Private keys at edge**: Encrypted with KMS, rotated every 24 hours, never stored on disk

### Common Exam Question Patterns

**Pattern 1: "Which security policy should you use?"**
- If exam says "modern browsers only" → TLSv1.2_2021 or TLSv1.3_2025
- If exam says "legacy clients" → TLSv1 (but flag this as insecure)
- Default recommendation → TLSv1.2_2021

**Pattern 2: "How to restrict S3 origin access?"**
- Answer: Origin Access Control (OAC) + bucket policy
- NOT OAI (legacy, doesn't support KMS)
- NOT making bucket public

**Pattern 3: "How to serve private content?"**
- Signed URLs for individual downloads
- Signed Cookies for streaming (HLS) or multiple files
- Both use Trusted Key Groups (recommended over Trusted Signers)

**Pattern 4: "How to protect ALB origin from direct access?"**
- Custom headers + ALB listener rule validation
- OR CloudFront managed prefix list in security groups
- OR VPC origins (newer feature)

**Pattern 5: "Certificate issues returning 502?"**
- Origin cert expired, self-signed, or wrong domain
- Certificate chain incomplete (missing intermediates)
- Origin not supporting required TLS version/ciphers

### Tricky Concepts & Gotchas

1. **OAC + SSE-KMS**: KMS key policy must grant `kms:Decrypt` to `cloudfront.amazonaws.com`
2. **Alternate domain names**: MUST have matching certificate SAN — CloudFront validates this
3. **HTTP/2 and HTTP/3**: Supported for viewer connections; HTTP/1.1 or HTTP/2 to origin
4. **Real-time logs vs Standard logs**: Real-time → Kinesis (seconds); Standard → S3 (up to 1 hour delay)
5. **Cache behavior ordering**: First matching path pattern wins — order matters for security
6. **Origin failover**: Can route to secondary origin on 5xx errors — useful for DR but doesn't retry on 4xx

### Comparison: CloudFront vs ALB for TLS

| Aspect | CloudFront | ALB |
|--------|-----------|-----|
| TLS termination location | Edge (global) | Regional |
| Certificate source | ACM (us-east-1 only) | ACM (same region) |
| mTLS support | ✅ Viewer + Origin | ✅ |
| TLS 1.3 | ✅ | ✅ |
| WAF integration | ✅ | ✅ |
| DDoS protection | Shield (all layers) | Shield (L3/L4 only) |
| Custom security headers | Response Headers Policy | ALB action |
| Field-level encryption | ✅ | ❌ |

---

## 7. Exam Domain Mapping

| Domain | CloudFront Relevance |
|--------|---------------------|
| **Domain 1: Threat Detection** | Real-time logs → detection; Shield Advanced → DDoS response |
| **Domain 2: Logging & Monitoring** | Access logs, real-time logs, CloudWatch metrics |
| **Domain 3: Infrastructure Security** | ✅ **PRIMARY** — WAF, Shield, TLS, geo restriction, OAC |
| **Domain 4: IAM** | OAC service principal, signed URLs (key management) |
| **Domain 5: Data Protection** | TLS in transit, field-level encryption, HSTS |
| **Domain 6: Governance** | Config rules for compliance, Security Hub findings |

---

## 8. Real-World Scenarios & SSL/TLS Configuration Examples

### Scenario 1: Multi-Tenant SaaS API with End-to-End HTTPS

**Situation**: A SaaS company serves APIs through CloudFront → API Gateway → EKS. They need TLS 1.2+ enforcement, per-tenant rate limiting, and protection against API abuse.

**Solution Architecture**:
```
Tenant A Browser                    Tenant B Browser
       │                                   │
       │ TLS 1.3 (ECDSA cert)             │ TLS 1.3
       ▼                                   ▼
┌──────────────────────────────────────────────────┐
│ CloudFront (Security Policy: TLSv1.2_2021)       │
│ • ACM cert: *.api.saascompany.com (us-east-1)   │
│ • WAF: Rate limit 1000 req/5min per IP          │
│ • WAF: Bot Control (targeted)                    │
│ • Response Headers: HSTS + CSP + X-Frame-Options│
├──────────────────────────────────────────────────┤
│ Cache Behavior: /api/* → API Gateway origin      │
│ • Viewer Protocol: HTTPS Only                    │
│ • Origin Protocol: HTTPS Only                    │
│ • Custom Header: X-CF-Secret: <rotated-value>   │
│ • Cache Policy: CachingDisabled (API)            │
└──────────────────────────────────────────────────┘
       │
       │ TLS 1.2 (Origin Protocol)
       ▼
┌──────────────────────────┐
│ API Gateway              │
│ • Validates X-CF-Secret  │
│ • Per-tenant throttling  │
│ • JWT/OAuth validation   │
└──────────────────────────┘
```

**SSL/TLS Configuration Details**:
- Viewer: TLSv1.2_2021 security policy (TLS 1.2 + 1.3, strong ciphers only)
- Origin: HTTPS Only, TLSv1.2
- Certificate: Wildcard `*.api.saascompany.com` via ACM (auto-renewing)
- SNI: Enabled (default, no cost)

**Why This Works**:
- Zero plaintext exposure (HTTPS both directions)
- Strong ciphers prevent downgrade attacks
- Custom header prevents API GW bypass
- WAF rate limiting prevents per-IP abuse
- HSTS prevents future HTTP connections

---

### Scenario 2: Compliance-Sensitive Data with Field-Level Encryption

**Situation**: Healthcare SaaS application processes patient forms with SSN and medical record numbers. Must comply with HIPAA — sensitive fields cannot be readable by intermediate systems.

**Solution**:
```
Patient Browser
       │
       │ TLS 1.3 (POST /submit-form)
       │ Body: { name: "John", ssn: "123-45-6789", mrn: "MRN001" }
       ▼
┌──────────────────────────────────────────────────┐
│ CloudFront (Field-Level Encryption)              │
│ • FLE Profile: ssn, mrn → PublicKey-Healthcare   │
│ • Encrypted at edge before forwarding            │
│ Body becomes:                                    │
│ { name: "John",                                  │
│   ssn: "AQA...encrypted...==",                   │
│   mrn: "AQA...encrypted...==" }                  │
└──────────────────────────────────────────────────┘
       │
       │ TLS 1.2 (encrypted fields remain encrypted)
       ▼
┌──────────────────────────────────────────────────┐
│ Application Server (EKS)                         │
│ • Cannot read ssn/mrn — doesn't have private key│
│ • Processes name, routes to downstream service   │
└──────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────┐
│ HIPAA-Compliant Processing Service               │
│ • Has private key for PublicKey-Healthcare       │
│ • Decrypts ssn and mrn using AWS Encryption SDK │
│ • Processes sensitive data in isolated env       │
└──────────────────────────────────────────────────┘
```

**Exam Relevance**: Field-level encryption provides defense-in-depth beyond TLS — even if a component in the processing chain is compromised, the sensitive data remains encrypted.

---

### Scenario 3: Private Video Streaming with Signed Cookies

**Situation**: E-learning platform delivers premium video content. Only paid subscribers should access content. Videos use HLS format (multiple .ts segments + .m3u8 playlists).

**Solution**:
```
Authenticated User Login
       │
       │ 1. Login → Backend validates subscription
       ▼
┌──────────────────────────────────────────────────┐
│ Application Server                               │
│ • Validates payment status                       │
│ • Generates signed cookies (Custom Policy):      │
│   - Resource: https://cdn.example.com/videos/*   │
│   - DateLessThan: 24 hours from now              │
│   - IpAddress: User's current IP                 │
│ • Sets 3 cookies:                                │
│   - CloudFront-Policy                            │
│   - CloudFront-Signature                         │
│   - CloudFront-Key-Pair-Id                       │
└──────────────────────────────────────────────────┘
       │
       │ 2. Set-Cookie headers in response
       ▼
┌──────────────────────────────────────────────────┐
│ Browser with signed cookies                      │
│ • Requests .m3u8 playlist                        │
│ • Each .ts segment request includes cookies      │
└──────────────────────────────────────────────────┘
       │
       │ 3. HTTPS request + cookies
       ▼
┌──────────────────────────────────────────────────┐
│ CloudFront                                       │
│ • Trusted Key Group validates signature          │
│ • Checks expiration (DateLessThan)               │
│ • Checks IP restriction                          │
│ • On valid → serve from cache or fetch origin    │
│ • On invalid → 403 Forbidden                    │
├──────────────────────────────────────────────────┤
│ Origin: S3 with OAC                              │
│ • Bucket is NOT public                           │
│ • Only CloudFront OAC can read objects           │
└──────────────────────────────────────────────────┘
```

**Why Signed Cookies (not URLs)**:
- HLS streams have 100s of segment files — can't modify each URL
- Cookies apply to all requests matching the resource pattern
- Custom policy allows wildcard paths (`/videos/*`)

---

### Scenario 4: Multi-Region Origin Failover with SSL

**Situation**: Global SaaS with primary region in us-east-1 and failover in eu-west-1. Both origins use custom SSL certificates. Need zero-downtime failover with consistent TLS.

**Solution**:
```
┌──────────────────────────────────────────────────┐
│ CloudFront Distribution                          │
│ • Origin Group (failover):                       │
│   - Primary: ALB us-east-1                       │
│   - Secondary: ALB eu-west-1                     │
│ • Failover criteria: 500, 502, 503, 504         │
│ • Both origins: HTTPS Only, TLSv1.2             │
├──────────────────────────────────────────────────┤
│ Origin SSL Requirements:                         │
│ • Both ALBs have ACM certs (in their regions)   │
│ • Cert CN/SAN matches origin domain name        │
│ • Complete certificate chain                     │
│ • CloudFront validates cert on every connection  │
└──────────────────────────────────────────────────┘
```

**Key Points**:
- Origin failover only triggers on 5xx errors (not 4xx)
- Each origin can have different SSL certificates (region-specific ACM)
- Viewer always sees same CloudFront certificate regardless of which origin serves
- Origin Shield can reduce origin load during failover scenarios

---

### Scenario 5: Zero-Trust API with mTLS

**Situation**: B2B SaaS where partner systems must authenticate with client certificates. Only verified partners with valid certs can access the API.

**Solution**:
```
Partner System
       │
       │ 1. TLS handshake with client certificate
       │    Client cert signed by trusted CA
       ▼
┌──────────────────────────────────────────────────┐
│ CloudFront (Viewer mTLS enabled)                 │
│ • Trust Store: CA bundle uploaded                │
│ • Validates: cert chain, expiry, revocation     │
│ • On success: adds headers:                      │
│   - X-Amz-Cf-Client-Cert-Verified              │
│   - X-Amz-Cf-Client-Cert-Subject              │
│   - X-Amz-Cf-Client-Cert-Serial               │
│ • On failure: 403 Forbidden (no TLS handshake)  │
├──────────────────────────────────────────────────┤
│ Lambda@Edge (Viewer Request)                     │
│ • Extracts partner ID from cert subject          │
│ • Validates against allowed partners list        │
│ • Sets tenant context headers                    │
├──────────────────────────────────────────────────┤
│ Origin (API Gateway / ALB)                       │
│ • Origin mTLS: CloudFront presents client cert  │
│ • Origin validates CloudFront's cert             │
│ • Processes request with tenant context          │
└──────────────────────────────────────────────────┘
```

**mTLS Certificate Flow**:
- Viewer → CloudFront: Partner's client cert (verified against trust store)
- CloudFront → Origin: CloudFront's client cert (configured per distribution)
- Both directions authenticated — true zero-trust

---

### Scenario 6: SSL/TLS Troubleshooting — 502 Bad Gateway

**Situation**: After rotating certificates on the origin ALB, CloudFront starts returning 502 errors to all viewers.

**Root Cause Analysis**:
```
CloudFront → TLS handshake → Origin (ALB)
                    │
                    ├── Check 1: Certificate expired? → 502
                    ├── Check 2: Certificate CN/SAN doesn't match origin domain? → 502
                    ├── Check 3: Self-signed certificate? → 502
                    ├── Check 4: Incomplete certificate chain (missing intermediates)? → 502
                    ├── Check 5: Origin not responding on port 443? → 502
                    └── Check 6: Origin only supports ciphers CloudFront doesn't? → 502
```

**Diagnosis Steps**:
1. Check CloudFront error response headers for error code
2. Verify origin cert: `openssl s_client -connect origin:443 -servername origin.example.com`
3. Confirm cert chain is complete (intermediate certs present)
4. Verify CN/SAN matches the Origin Domain Name in CloudFront config
5. Check origin supports TLSv1.2 and compatible ciphers

**Resolution**: Ensure the new cert has correct SAN, complete chain, and the origin supports ECDHE-RSA-AES128-GCM-SHA256 or similar CloudFront-compatible cipher.

---

## 9. Pricing & Cost Optimization

### Cost Components
| Component | Pricing Model |
|-----------|---------------|
| Data Transfer Out | Per-GB, varies by region ($0.085-$0.170/GB) |
| HTTP/HTTPS Requests | Per 10,000 requests ($0.0075-$0.016) |
| HTTPS requests | Slightly higher than HTTP |
| Field-level encryption | Per 10,000 requests ($0.02) |
| Real-time logs | Per log line ($0.01 per million) |
| Dedicated IP SSL | $600/month per distribution |
| Origin Shield | Incremental per 10,000 requests |
| WAF | Separate pricing (Web ACL + rules + requests) |

### Cost Optimization Tips
1. Use Origin Shield to reduce origin fetches
2. Optimize cache hit ratio to reduce origin requests
3. Use SNI (free) instead of Dedicated IP ($600/month)
4. Choose appropriate security policy (no cost difference)
5. Use CloudFront Functions instead of Lambda@Edge for simple logic (1/6th the price)

---

## 10. Common Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| 502 Bad Gateway | Origin SSL mismatch | Fix origin cert (CN/SAN/chain) |
| 403 Forbidden (geo) | Geo restriction | Check allowlist/blocklist |
| 403 Forbidden (signed) | Expired/invalid signature | Check clock sync, key pair, policy |
| 421 Misdirected Request | Domain fronting detected | Use correct account for cert + request |
| Mixed content warnings | Origin returns HTTP links | Enforce HTTPS + fix origin responses |
| CORS errors | Missing CORS headers | Use Response Headers Policy |
| Slow TTFB | High origin latency | Enable Origin Shield + optimize origin |

---

## 11. Documentation References

- [Use HTTPS with CloudFront](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-https.html)
- [Supported Protocols and Ciphers](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/secure-connections-supported-viewer-protocols-ciphers.html)
- [SSL/TLS Certificate Requirements](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html)
- [Restrict Access to S3 Origin (OAC)](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)
- [Field-Level Encryption](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/field-level-encryption.html)
- [Response Headers Policies](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/understanding-response-headers-policies.html)
- [Serve Private Content (Signed URLs/Cookies)](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/PrivateContent.html)
- [CloudFront Security](https://aws.amazon.com/cloudfront/security/)
- [Securing HTTPS Delivery Whitepaper](https://docs.aws.amazon.com/whitepapers/latest/secure-content-delivery-amazon-cloudfront/securing-https-delivery.html)

---

*All content sourced from official AWS documentation via AWS Knowledge and Documentation MCP servers. Last updated: June 2026.*

---

## 12. Detailed Attack Mitigation Reference

> The following section provides expanded real-world attack scenarios with detailed configurations. This supplements Section 4 (Threat Mitigation Coverage) with deeper analysis per attack type.


## Attack 1: Volumetric DDoS (Layer 3/4)

### Classification: Infrastructure-Level Attack

### What It Is
Massive flood of traffic (UDP floods, SYN floods, DNS amplification) aimed at saturating network bandwidth and exhausting server resources. Attackers use botnets with thousands of compromised machines.

### Real-World Examples
- **2020 AWS Shield mitigated 2.3 Tbps attack** — largest ever recorded at the time
- **GitHub DDoS (2018)** — 1.35 Tbps memcached amplification attack
- **Gaming/SaaS platforms** regularly targeted during peak usage (competitive disruption)

### How CloudFront Mitigates

| Layer | Mitigation |
|-------|-----------|
| Network absorption | CloudFront's 450+ edge locations absorb traffic at source, distributing the load globally |
| AWS Shield Standard | Automatic, always-on protection against SYN floods, UDP floods, reflection attacks — FREE |
| Anycast routing | Attack traffic spreads across entire edge network instead of hitting single origin |
| Origin isolation | Origin never sees DDoS traffic — CloudFront absorbs it entirely |

### Configuration
```
No configuration needed — Shield Standard is automatic on all CloudFront distributions.

For enhanced protection:
- Enable Shield Advanced ($3,000/month)
- Get DDoS Response Team (DRT) access
- Cost protection (AWS doesn't charge for DDoS-related scaling)
- Health-based detection via Route 53 health checks
```

### Key Exam Point
> Shield Standard protects against most common L3/L4 DDoS attacks automatically. Shield Advanced adds proactive engagement, cost protection, and access to DRT for L7 attacks.

---

## Attack 2: HTTP Flood (Layer 7 DDoS)

### Classification: Application-Level Attack

### What It Is
Legitimate-looking HTTP requests sent at massive scale to overwhelm application servers. Harder to detect than volumetric attacks because each request appears normal — it's the volume that causes damage.

### Real-World Examples
- **Mirai botnet variants** sending millions of GET/POST requests to APIs
- **Credential stuffing campaigns** — 100M+ login attempts using leaked credentials
- **Flash sale exploitation** — competitors flooding checkout APIs during promotions

### How CloudFront Mitigates

| Feature | How It Helps |
|---------|-------------|
| WAF Rate Limiting | Block IPs exceeding threshold (e.g., 2000 req/5min) |
| WAF Bot Control | ML-based detection of automated traffic patterns |
| CloudFront caching | Cached responses served without hitting origin — absorbs read-heavy floods |
| Shield Advanced (L7) | Automatic L7 DDoS detection with proactive DRT engagement |
| Geographic blocking | Block traffic from regions where you have no customers |

### Configuration
```json
// WAF Rate-Based Rule
{
  "Name": "RateLimitRule",
  "Priority": 1,
  "Statement": {
    "RateBasedStatement": {
      "Limit": 2000,
      "AggregateKeyType": "IP"
    }
  },
  "Action": { "Block": {} },
  "VisibilityConfig": {
    "SampledRequestsEnabled": true,
    "CloudWatchMetricsEnabled": true,
    "MetricName": "RateLimitRule"
  }
}
```

### Key Exam Point
> WAF rate-based rules on CloudFront are the primary defense against L7 DDoS. They evaluate over a 5-minute window and automatically block IPs exceeding the threshold.

---

## Attack 3: SQL Injection (SQLi)

### Classification: Application-Level Attack

### What It Is
Attacker injects malicious SQL code through input fields, URL parameters, or headers to manipulate database queries. Can lead to data exfiltration, privilege escalation, or complete database compromise.

### Real-World Examples
- **Capital One breach (2019)** — SSRF + misconfiguration, but SQLi is the most common web app attack vector
- **Equifax breach (2017)** — exploited application vulnerability to access 147M records
- **SaaS platforms** — multi-tenant SQLi can leak data between tenants

### How CloudFront Mitigates

| Feature | How It Helps |
|---------|-------------|
| WAF SQLi Rules | AWS Managed Rules detect SQL injection patterns in URI, body, headers |
| WAF Custom Rules | Block known SQLi payloads (UNION SELECT, DROP TABLE, etc.) |
| Request size limits | CloudFront rejects oversized requests (body limit configurable) |
| Input validation at edge | CloudFront Functions can validate/sanitize query params before origin |

### Configuration
```json
// WAF Managed Rule Group for SQLi
{
  "Name": "AWSManagedRulesSQLiRuleSet",
  "Priority": 2,
  "OverrideAction": { "None": {} },
  "Statement": {
    "ManagedRuleGroupStatement": {
      "VendorName": "AWS",
      "Name": "AWSManagedRulesSQLiRuleSet"
    }
  }
}
```

### Attack Flow (Before Mitigation)
```
Attacker → GET /api/users?id=1' OR '1'='1 → ALB → Database (dumps all users)
```

### Attack Flow (With CloudFront + WAF)
```
Attacker → GET /api/users?id=1' OR '1'='1 → CloudFront → WAF detects SQLi → 403 BLOCKED
                                                            (never reaches origin)
```

### Key Exam Point
> WAF on CloudFront inspects requests BEFORE they reach origin. AWS Managed Rules cover OWASP Top 10 including SQLi. This is the only way to protect non-AWS origins (on-prem servers) with AWS WAF.

---

## Attack 4: Cross-Site Scripting (XSS)

### Classification: Application-Level Attack

### What It Is
Attacker injects malicious JavaScript into web pages viewed by other users. Can steal session cookies, redirect users to phishing sites, or deface the application.

### Real-World Examples
- **British Airways (2018)** — Magecart group injected JS to steal 380,000 payment cards
- **XSS worms on social platforms** — self-propagating scripts in user content
- **SaaS admin panels** — stored XSS in support ticket systems affecting admins

### How CloudFront Mitigates

| Feature | How It Helps |
|---------|-------------|
| WAF XSS Rules | Detects `<script>`, event handlers, and encoded XSS patterns |
| Response Headers Policy | `X-XSS-Protection: 1; mode=block` enables browser XSS filter |
| Content-Security-Policy | Restricts script sources to trusted domains only |
| X-Content-Type-Options | `nosniff` prevents MIME-type confusion attacks |

### Configuration (Response Headers Policy)
```
Security Headers:
  Content-Security-Policy: default-src 'self'; script-src 'self' cdn.trusted.com
  X-XSS-Protection: 1; mode=block
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
```

### Key Exam Point
> CloudFront Response Headers Policy provides defense against XSS at two levels: WAF blocks malicious input, and response headers instruct browsers to reject suspicious scripts. CSP is the strongest defense but requires careful configuration.

---

## Attack 5: Domain Fronting

### Classification: Infrastructure-Level Attack

### What It Is
Attacker uses a legitimate CDN domain (like cloudfront.net) in the TLS SNI field but routes the actual HTTP request to a different (malicious) CloudFront distribution. Used to disguise C2 (command and control) traffic as legitimate CDN traffic, bypassing firewalls.

### Real-World Examples
- **APT groups (Signal, Telegram)** — used domain fronting to bypass censorship
- **Cobalt Strike C2** — used cloudfront.net domains to hide malware communication
- **Nation-state actors** — disguised data exfiltration as CDN traffic

### How CloudFront Mitigates

| Feature | How It Helps |
|---------|-------------|
| Account validation | CloudFront verifies the AWS account owning the TLS certificate matches the account making subsequent requests |
| 421 Misdirected Request | If accounts don't match, CloudFront returns 421 error |
| CNAME validation | Alternate domain names require certificate ownership proof |
| Dangling DNS warnings | CloudFront warns when CNAMEs could be hijacked |

### How The Mitigation Works
```
Attacker Setup:
  TLS SNI: d1234.cloudfront.net (legitimate company's distribution)
  Host header: d5678.cloudfront.net (attacker's distribution)

CloudFront Response:
  1. Checks certificate account ≠ request account
  2. Returns HTTP 421 Misdirected Request
  3. Attack fails — traffic not forwarded to attacker's origin
```

### Key Exam Point
> AWS mitigated domain fronting by validating that the certificate's owning AWS account matches the account handling the HTTP request. This is automatic — no configuration needed.

---

## Attack 6: SSL/TLS Downgrade Attacks (POODLE, BEAST, DROWN)

### Classification: Infrastructure-Level Attack

### What It Is
Attacker forces a connection to use an older, vulnerable protocol version (SSL 3.0, TLS 1.0) then exploits known vulnerabilities in that protocol to decrypt traffic.

### Real-World Examples
- **POODLE (2014)** — exploits SSL 3.0 CBC padding to decrypt data
- **BEAST (2011)** — exploits TLS 1.0 CBC mode vulnerability
- **DROWN (2016)** — uses SSLv2 to decrypt modern TLS connections
- **Logjam (2015)** — exploits weak Diffie-Hellman to downgrade key exchange

### How CloudFront Mitigates

| Feature | How It Helps |
|---------|-------------|
| Security Policy (TLSv1.2_2021+) | Disables TLS 1.0, 1.1, and all SSL versions |
| No SSL renegotiation | CloudFront does NOT support renegotiation (prevents renegotiation attacks) |
| Strong cipher suites only | ECDHE-based ciphers provide Perfect Forward Secrecy |
| HSTS enforcement | Tells browsers to never attempt non-HTTPS connection |
| s2n-tls library | AWS's minimal TLS implementation — smaller attack surface than OpenSSL |

### Configuration
```
Distribution Settings:
  Security Policy: TLSv1.2_2021 (minimum)
  
  This enforces:
    ✅ TLS 1.2 and 1.3 only
    ✅ ECDHE key exchange (Perfect Forward Secrecy)
    ✅ AES-GCM ciphers (AEAD — no CBC padding attacks)
    ❌ No SSL 3.0, TLS 1.0, TLS 1.1
    ❌ No RC4, DES, 3DES ciphers
    ❌ No static RSA key exchange (no PFS)

Response Headers:
  Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
  (Prevents future HTTP connections — browser remembers for 1 year)
```

### Key Exam Point
> Setting security policy to TLSv1.2_2021 or higher eliminates ALL known protocol-level attacks. Combined with HSTS preload, even the first connection attempt is secured via browser's preload list.

---

## Attack 7: Content/Data Theft (Hotlinking & Unauthorized Access)

### Classification: Application-Level Attack

### What It Is
Unauthorized users access premium or private content by: guessing S3 URLs, hotlinking from other websites, sharing direct download links, or using browser developer tools to find asset URLs.

### Real-World Examples
- **Netflix content leaks** — unauthorized access to streaming segments
- **Stock photo theft** — competitors hotlinking premium images
- **SaaS data exfiltration** — former customers accessing content after subscription ends
- **API data scraping** — automated extraction of proprietary datasets

### How CloudFront Mitigates

| Feature | How It Helps |
|---------|-------------|
| Signed URLs | Individual file access requires cryptographic signature + expiration |
| Signed Cookies | Entire content libraries protected with session-based auth |
| OAC (S3 origin) | S3 bucket completely locked — only CloudFront can read |
| Custom headers (ALB) | Origin rejects direct access without CloudFront's secret header |
| Referrer checking (WAF) | Block requests from unauthorized referrer domains |
| IP restriction (in signed URLs) | Content only accessible from user's network |

### Attack Flow (Before Mitigation)
```
Attacker finds: https://my-bucket.s3.amazonaws.com/premium/video.mp4
→ Direct download — no authentication needed
```

### Attack Flow (With CloudFront + OAC + Signed URLs)
```
Attacker finds: https://my-bucket.s3.amazonaws.com/premium/video.mp4
→ S3 returns 403 (Block Public Access + OAC-only policy)

Attacker tries: https://d1234.cloudfront.net/premium/video.mp4
→ CloudFront returns 403 (missing valid signed URL/cookie)

Legitimate user: https://d1234.cloudfront.net/premium/video.mp4?Policy=...&Signature=...&Key-Pair-Id=...
→ CloudFront validates signature → serves content
→ URL expires in 1 hour — can't be reshared indefinitely
```

### Key Exam Point
> OAC protects the origin (S3), signed URLs/cookies protect the edge (CloudFront cache). Both are needed for complete content protection. OAC alone doesn't prevent unauthorized CloudFront access — you also need signed URLs or WAF rules.

---

## Attack 8: Credential Stuffing & Account Takeover

### Classification: Application-Level Attack

### What It Is
Attackers use leaked username/password databases (from breaches of other sites) to attempt automated logins against your application. If users reused passwords, attackers gain access.

### Real-World Examples
- **Dunkin' Donuts (2019)** — credential stuffing compromised customer rewards accounts
- **Disney+ launch (2019)** — thousands of accounts taken over on day one
- **Enterprise SaaS** — attackers target admin accounts for data access

### How CloudFront Mitigates

| Feature | How It Helps |
|---------|-------------|
| WAF Rate Limiting | Limits login attempts per IP (e.g., 10/minute on /login) |
| WAF Account Takeover Prevention | AWS Managed Rule group specifically for credential stuffing |
| WAF Bot Control (Targeted) | Detects automated tools (Selenium, headless browsers) |
| CAPTCHA/Challenge actions | WAF can issue CAPTCHA instead of blocking outright |
| IP reputation lists | AWS Threat Intelligence blocks known malicious IPs |
| Lambda@Edge | Custom logic: device fingerprinting, anomaly detection |

### Configuration
```json
// WAF Rate Limit on Login Endpoint
{
  "Name": "LoginRateLimit",
  "Statement": {
    "RateBasedStatement": {
      "Limit": 100,
      "AggregateKeyType": "IP",
      "ScopeDownStatement": {
        "ByteMatchStatement": {
          "SearchString": "/api/auth/login",
          "FieldToMatch": { "UriPath": {} },
          "PositionalConstraint": "STARTS_WITH"
        }
      }
    }
  },
  "Action": { "Block": {} }
}

// AWS Managed Rule - Account Takeover Prevention
{
  "Name": "AWSManagedRulesATPRuleSet",
  "ManagedRuleGroupStatement": {
    "VendorName": "AWS",
    "Name": "AWSManagedRulesATPRuleSet",
    "ManagedRuleGroupConfigs": [
      {
        "LoginPath": "/api/auth/login",
        "PayloadType": "JSON",
        "UsernameField": { "Identifier": "/email" },
        "PasswordField": { "Identifier": "/password" }
      }
    ]
  }
}
```

### Key Exam Point
> AWS WAF Account Takeover Prevention (ATP) is a managed rule group that detects credential stuffing by analyzing login patterns, stolen credential databases, and behavioral signals. It's specific to CloudFront and ALB.

---

## Attack 9: Man-in-the-Middle (MITM)

### Classification: Infrastructure-Level Attack

### What It Is
Attacker positions themselves between the user and the server to intercept, read, or modify traffic. Can happen on public WiFi, compromised DNS, or through ARP poisoning.

### Real-World Examples
- **Public WiFi interception** — coffee shop attackers capture session cookies
- **DNS spoofing** — redirect users to attacker's server with lookalike cert
- **BGP hijacking** — route traffic through attacker's network
- **SSL stripping** — downgrade HTTPS to HTTP transparently

### How CloudFront Mitigates

| Feature | How It Helps |
|---------|-------------|
| Forced HTTPS | Viewer Protocol Policy: HTTPS Only or Redirect |
| HSTS (response header) | Browser never attempts HTTP — even for first request (preload) |
| Certificate pinning (client-side) | Mobile apps can pin to expected CloudFront cert |
| TLS 1.3 | 0-RTT eliminated, encrypted SNI (ECH), PFS mandatory |
| s2n-tls | Minimal TLS stack reduces vulnerability surface |
| DNSSEC (Route 53) | Prevents DNS poisoning that could redirect traffic |
| Certificate Transparency | ACM certs logged publicly — detects rogue cert issuance |

### Defense Layers
```
Layer 1: DNSSEC (Route 53) — prevents DNS poisoning
Layer 2: HTTPS enforcement — prevents SSL stripping
Layer 3: HSTS preload — browser refuses HTTP connection
Layer 4: TLS 1.3 + PFS — even captured traffic can't be decrypted later
Layer 5: Certificate Transparency — detects if attacker gets rogue cert
Layer 6: mTLS — mutual authentication prevents impersonation
```

### Key Exam Point
> End-to-end HTTPS (viewer → CloudFront → origin) combined with HSTS preload provides comprehensive MITM protection. TLS 1.3 with Perfect Forward Secrecy ensures even recorded traffic can't be decrypted if keys are later compromised.

---

## Attack 10: Clickjacking (UI Redress Attack)

### Classification: Application-Level Attack

### What It Is
Attacker embeds the target website in an invisible iframe on their malicious page. When users click what they think is the attacker's page, they're actually clicking buttons on the embedded legitimate site (e.g., "Delete Account", "Transfer Funds").

### Real-World Examples
- **Facebook likejacking** — tricking users into liking pages via invisible frames
- **Banking trojans** — overlaying fake forms on real banking interfaces
- **OAuth consent hijacking** — tricking users into granting permissions

### How CloudFront Mitigates

| Feature | How It Helps |
|---------|-------------|
| X-Frame-Options header | `DENY` or `SAMEORIGIN` — prevents embedding in iframes |
| Content-Security-Policy | `frame-ancestors 'self'` — modern replacement for X-Frame-Options |
| Response Headers Policy | Native CloudFront feature — no origin changes needed |

### Configuration
```
Response Headers Policy → Security Headers:
  X-Frame-Options: DENY
  Content-Security-Policy: frame-ancestors 'self'
  
  Origin Override: true (ensures header is always present even if origin sets differently)
```

### Key Exam Point
> CloudFront Response Headers Policy can add `X-Frame-Options: DENY` globally without modifying any origin application code. This is the fastest way to protect all content from clickjacking.

---

## Attack 11: Bot Scraping & Competitive Intelligence Theft

### Classification: Application-Level Attack

### What It Is
Automated bots systematically crawl and extract content from websites — pricing data, product catalogs, proprietary research, user reviews. Used for competitive intelligence, price undercutting, or content theft.

### Real-World Examples
- **Airline fare scraping** — competitors extract pricing in real-time
- **E-commerce price scraping** — bots extract entire product catalogs
- **Content farms** — scrape news articles and republish
- **API abuse** — automated extraction of data through API endpoints

### How CloudFront Mitigates

| Feature | How It Helps |
|---------|-------------|
| WAF Bot Control (Common) | Blocks known bot signatures, blocks unverified bots |
| WAF Bot Control (Targeted) | ML-based detection of sophisticated bots mimicking humans |
| Rate limiting | Throttles requests per IP/session |
| CAPTCHA challenge | WAF can issue challenge instead of blocking |
| JavaScript challenge | Silent browser verification (fails for headless browsers) |
| Signed URLs | Require authentication for each content request |
| CloudFront Functions | Custom fingerprinting and token validation |

### Configuration
```json
// WAF Bot Control (Targeted Level)
{
  "Name": "BotControlTargeted",
  "Statement": {
    "ManagedRuleGroupStatement": {
      "VendorName": "AWS",
      "Name": "AWSManagedRulesBotControlRuleSet",
      "ManagedRuleGroupConfigs": [
        {
          "AWSManagedRulesBotControlRuleSetProperty": {
            "InspectionLevel": "TARGETED"
          }
        }
      ]
    }
  }
}
```

### Key Exam Point
> WAF Bot Control has two levels: Common (signature-based, blocks known bots) and Targeted (ML-based behavioral analysis for sophisticated bots). Targeted costs more but catches advanced scrapers that mimic real browsers.

---

## Attack 12: Origin Exposure / Direct Origin Access

### Classification: Infrastructure-Level Attack

### What It Is
Attacker discovers the origin server's direct IP or URL (via DNS history, SSL certificate transparency logs, or error messages) and bypasses CloudFront entirely — avoiding WAF rules, rate limits, and geo restrictions.

### Real-World Examples
- **CrimeFlare databases** — publicly map CloudFront distributions to origin IPs
- **DNS history tools** — show historical DNS records before CDN was added
- **Certificate Transparency logs** — reveal origin server domains
- **Error messages** — application errors leaking internal hostnames

### How CloudFront Mitigates

| Feature | How It Helps |
|---------|-------------|
| OAC (S3 origins) | S3 bucket only accepts requests from CloudFront service principal |
| Custom headers (ALB/EC2) | Origin rejects requests without secret header from CloudFront |
| VPC origins | Origin in private subnet, no public IP at all |
| CloudFront managed prefix list | Security groups only allow CloudFront IP ranges |
| Origin Shield | Additional caching layer reduces origin visibility |

### Defense Configuration
```
For ALB/EC2 Origins:

1. CloudFront: Add custom header
   Header: X-Origin-Verify
   Value: <random-64-char-secret-rotated-monthly>

2. ALB Listener Rule:
   IF header X-Origin-Verify != <secret>
   THEN return 403

3. Security Group:
   Inbound: Allow HTTPS from CloudFront managed prefix list (com.amazonaws.global.cloudfront.origin-facing)
   (blocks all non-CloudFront traffic at network level)

4. Rotate secret monthly:
   - Update CloudFront custom header
   - Update ALB listener rule
   - Brief overlap period accepts both old and new values
```

### Key Exam Point
> Three layers of origin protection should be used together: (1) Security groups with CloudFront prefix list (network level), (2) Custom header validation (application level), (3) OAC for S3 or VPC origins for compute (access control level).

---

## Summary: Attack Classification Matrix

| Attack | Level | Primary Defense | CloudFront Feature |
|--------|-------|-----------------|-------------------|
| Volumetric DDoS (L3/L4) | Infrastructure | Absorption | Shield Standard (automatic) |
| HTTP Flood (L7 DDoS) | Application | Throttling | WAF Rate Limiting + Shield Advanced |
| SQL Injection | Application | Filtering | WAF SQLi Managed Rules |
| Cross-Site Scripting | Application | Filtering + Headers | WAF XSS Rules + CSP |
| Domain Fronting | Infrastructure | Validation | Account-cert matching (automatic) |
| TLS Downgrade | Infrastructure | Protocol enforcement | Security Policy TLSv1.2_2021+ |
| Content Theft | Application | Access control | Signed URLs/Cookies + OAC |
| Credential Stuffing | Application | Rate limit + detection | WAF ATP + Bot Control |
| Man-in-the-Middle | Infrastructure | Encryption | HTTPS + HSTS + TLS 1.3 |
| Clickjacking | Application | Frame control | Response Headers (X-Frame-Options) |
| Bot Scraping | Application | Detection | WAF Bot Control (Targeted) |
| Origin Bypass | Infrastructure | Origin lockdown | OAC + Custom Headers + Prefix List |

---

*All content sourced from official AWS documentation and real-world incident reports. Last updated: June 2026.*

---

## 13. Production Use Cases & Architecture Patterns

> The following section provides expanded real-world production scenarios with complete configurations. This supplements Section 8 (Real-World Scenarios) with additional enterprise patterns.


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
