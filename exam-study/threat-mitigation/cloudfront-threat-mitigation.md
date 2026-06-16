# Amazon CloudFront — Real-World Cloud Attack Mitigation

## Overview
This document maps real-world cloud and web attacks to how Amazon CloudFront (combined with Shield, WAF, and edge features) prevents or mitigates them. Each attack includes its classification, real-world examples, and the specific CloudFront configuration that stops it.

---

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
