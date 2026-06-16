# Amazon CloudFront — Deep Dive for Security Specialty Exam

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
