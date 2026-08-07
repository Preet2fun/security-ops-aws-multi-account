# Amazon VPC Security — Deep Dive for Security Specialty Exam

## 1. Service Introduction & Significance

### What is Amazon VPC?
Amazon Virtual Private Cloud (VPC) is a logically isolated virtual network within AWS where you launch resources. It gives you complete control over your network environment — IP ranges, subnets, route tables, gateways, and security settings. VPC is the **foundation** of all network security in AWS.

### Security Significance
VPC provides **network-level isolation** — the most fundamental security boundary in cloud infrastructure. Every EC2 instance, RDS database, Lambda function (VPC-attached), EKS pod, and ELB runs inside a VPC. Without proper VPC security, all other security controls can be bypassed.

### Key Security Components
- **Security Groups** — Stateful instance-level firewall (primary control)
- **Network ACLs** — Stateless subnet-level firewall (secondary defense-in-depth)
- **VPC Endpoints / PrivateLink** — Private connectivity without internet exposure
- **Flow Logs** — Network traffic monitoring and forensics
- **Route Tables** — Control traffic routing between subnets and gateways
- **NAT Gateways** — Controlled outbound internet access for private subnets
- **Transit Gateway** — Multi-VPC/multi-account network hub

### Role in SaaS/Enterprise Security
- Tenant isolation via separate VPCs or subnets
- Database isolation in private subnets (no internet route)
- Compliance boundaries (PCI DSS network segmentation)
- Zero-trust micro-segmentation with security groups for pods

---

## 2. Behind-the-Scenes Technical Flow

### Single-Account VPC Traffic Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ VPC (10.0.0.0/16)                                                    │
│                                                                       │
│  ┌─────────────────── Public Subnet (10.0.1.0/24) ──────────────┐  │
│  │                                                                 │  │
│  │  Internet ──→ IGW ──→ Route Table ──→ NACL ──→ Security Group │  │
│  │                                              ──→ EC2 Instance   │  │
│  │                                                                 │  │
│  │  [Route: 0.0.0.0/0 → igw-xxx]                                 │  │
│  └─────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌─────────────────── Private Subnet (10.0.2.0/24) ─────────────┐  │
│  │                                                                 │  │
│  │  EC2 ──→ Route Table ──→ NAT GW (in public subnet) ──→ IGW   │  │
│  │                                                                 │  │
│  │  [Route: 0.0.0.0/0 → nat-xxx]                                 │  │
│  │  [Route: 10.0.0.0/16 → local]                                 │  │
│  └─────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌─────────────────── Isolated Subnet (10.0.3.0/24) ────────────┐  │
│  │                                                                 │  │
│  │  RDS ──→ No internet route at all                              │  │
│  │  [Route: 10.0.0.0/16 → local ONLY]                            │  │
│  │  [VPC Endpoint for S3/DynamoDB if needed]                      │  │
│  └─────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Traffic Evaluation Order (Inbound)
```
1. Route Table    → Determines if traffic can reach the subnet
2. Network ACL   → Subnet-level stateless filter (allow/deny)
3. Security Group → Instance-level stateful filter (allow only)
4. OS Firewall   → Host-level (iptables, Windows Firewall)
```

### Traffic Evaluation Order (Outbound)
```
1. Security Group → Instance-level stateful (return traffic auto-allowed)
2. Network ACL   → Subnet-level stateless (ephemeral ports needed for return)
3. Route Table   → Determines egress path (IGW, NAT, VPC endpoint, TGW)
```

### Multi-Account VPC Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│ AWS Organizations                                                   │
├────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────────── Shared Services Account ──────────────┐ │
│  │  VPC: 10.0.0.0/16                                              │ │
│  │  • DNS (Route 53 Resolver)                                     │ │
│  │  • Active Directory                                            │ │
│  │  • VPC Endpoints (shared via RAM)                             │ │
│  └────────────────────────────────────────────────────────────────┘ │
│       │                                                              │
│       │ Transit Gateway (hub-and-spoke)                              │
│       │                                                              │
│  ┌────┴───────────── Workload Account (Prod) ────────────────────┐ │
│  │  VPC: 10.1.0.0/16                                              │ │
│  │  • EKS in private subnets                                      │ │
│  │  • RDS in isolated subnets                                     │ │
│  │  • NLB in public subnets                                       │ │
│  └────────────────────────────────────────────────────────────────┘ │
│       │                                                              │
│  ┌────┴───────────── Workload Account (Dev) ─────────────────────┐ │
│  │  VPC: 10.2.0.0/16                                              │ │
│  │  • Isolated from Prod (TGW route table segmentation)           │ │
│  └────────────────────────────────────────────────────────────────┘ │
│       │                                                              │
│  ┌────┴───────────── Inspection Account ─────────────────────────┐ │
│  │  VPC: 10.100.0.0/16                                            │ │
│  │  • AWS Network Firewall                                        │ │
│  │  • All egress traffic routed here for inspection               │ │
│  └────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────┘
```

**Key Multi-Account Patterns**:
- **Transit Gateway** connects VPCs across accounts (shared via RAM)
- **TGW Route Tables** provide network segmentation (Prod can't route to Dev)
- **Centralized egress** through inspection VPC with Network Firewall
- **Shared VPC** via RAM — subnets shared across accounts, single VPC management
- **VPC Peering** — direct connection (non-transitive, no overlapping CIDRs)

---

## 3. Step-by-Step Configuration & Security Significance

### 3.1 Security Groups (Primary Control)

| Property | Detail |
|----------|--------|
| Level | Instance (ENI) level |
| State | **Stateful** — return traffic automatically allowed |
| Rules | **Allow only** — no explicit deny |
| Evaluation | All rules evaluated before decision |
| Default (inbound) | Deny all |
| Default (outbound) | Allow all |
| Limit | Up to 60 rules per SG (adjustable) |

**Key Security Patterns**:

```
# Web tier SG
Inbound: HTTPS (443) from 0.0.0.0/0
Inbound: HTTP (80) from 0.0.0.0/0  (redirect to HTTPS)
Outbound: HTTPS (443) to App-tier-SG

# App tier SG
Inbound: HTTPS (443) from Web-tier-SG  ← Reference another SG!
Outbound: PostgreSQL (5432) to DB-tier-SG

# DB tier SG
Inbound: PostgreSQL (5432) from App-tier-SG
Outbound: None needed (stateful return)
```

**Self-referencing SG** — allows instances in the same SG to communicate:
```
Inbound: All Traffic from sg-self (same SG ID)
```

**Exam-Critical**: Security groups can reference other security groups — this is cleaner than using IP ranges and automatically adapts when instances are added/removed.

### 3.2 Network ACLs (Secondary Defense-in-Depth)

| Property | Detail |
|----------|--------|
| Level | Subnet level |
| State | **Stateless** — return traffic must be explicitly allowed |
| Rules | **Allow AND Deny** |
| Evaluation | Rules in order (lowest number first) — first match wins |
| Default | Allow all (in default NACL) |
| Limit | 20 rules per direction (adjustable) |

**Key Pattern — Block Specific IPs (can't do with Security Groups)**:
```
Inbound Rules:
  Rule 50:  DENY  TCP  All Ports  from 198.51.100.0/24  (known attacker)
  Rule 100: ALLOW TCP  443        from 0.0.0.0/0
  Rule 110: ALLOW TCP  80         from 0.0.0.0/0
  Rule *:   DENY  All  All        from 0.0.0.0/0         (implicit)

Outbound Rules:
  Rule 100: ALLOW TCP  443        to 0.0.0.0/0
  Rule 110: ALLOW TCP  1024-65535 to 0.0.0.0/0   ← Ephemeral ports!
  Rule *:   DENY  All  All        to 0.0.0.0/0
```

**Exam-Critical**: NACLs are stateless — you MUST allow ephemeral ports (1024-65535) outbound for return traffic. Forgetting this breaks connectivity.

**What NACLs CANNOT block**:
- DNS to Route 53 Resolver (VPC+2 address)
- DHCP traffic
- Instance Metadata Service (IMDS) — use IMDSv2 instead
- EC2 instance metadata, ECS task metadata
- AWS Time Sync Service
- License activation for Windows

### 3.3 VPC Endpoints

#### Gateway Endpoints (S3 and DynamoDB only)
| Property | Detail |
|----------|--------|
| Cost | **Free** |
| How it works | Entry in route table pointing to endpoint |
| Security | Endpoint policy (resource-based) |
| DNS | No DNS change needed |
| Availability | Highly available by default |

```
Route Table Entry:
  Destination: pl-xxx (S3 prefix list)
  Target: vpce-xxx (gateway endpoint)

Endpoint Policy (restrict to specific bucket):
{
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": ["s3:GetObject", "s3:PutObject"],
    "Resource": "arn:aws:s3:::my-app-bucket/*"
  }]
}
```

#### Interface Endpoints (All other services)
| Property | Detail |
|----------|--------|
| Cost | ~$0.01/hour/AZ + data processing |
| How it works | ENI with private IP in your subnet |
| Security | Security groups + Endpoint policy |
| DNS | Private DNS (resolves service domain to private IP) |
| Availability | Deploy in multiple AZs |

**Security Pattern**: Remove NAT Gateway and use VPC endpoints for all AWS services — eliminates internet egress entirely.

### 3.4 VPC Flow Logs

| Property | Detail |
|----------|--------|
| Levels | VPC, Subnet, or ENI |
| Destinations | CloudWatch Logs, S3, Kinesis Data Firehose |
| Traffic types | All, Accept, Reject |
| Cost | Data ingestion + storage |
| Latency | ~10 minutes (aggregation window) |

**Default Format Fields**:
```
version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status
```

**Custom Format (add more fields)**:
```
${version} ${account-id} ${interface-id} ${srcaddr} ${dstaddr} 
${srcport} ${dstport} ${protocol} ${packets} ${bytes} 
${start} ${end} ${action} ${log-status} 
${vpc-id} ${subnet-id} ${tcp-flags} ${traffic-path}
```

**Exam-Critical**: Flow Logs do NOT capture:
- DNS requests to Route 53 Resolver
- DHCP traffic
- Traffic to instance metadata (169.254.169.254)
- Traffic to/from 169.254.169.123 (Time Sync)
- Amazon Windows license activation traffic

### 3.5 NAT Gateway vs NAT Instance

| Feature | NAT Gateway | NAT Instance |
|---------|-------------|--------------|
| Managed | ✅ AWS-managed, HA in AZ | ❌ Self-managed |
| Bandwidth | Up to 100 Gbps | Limited by instance type |
| Security Groups | ❌ Cannot attach | ✅ Can attach |
| NACLs | ✅ Applies | ✅ Applies |
| Bastion | ❌ No SSH | ✅ Can SSH through |
| Cost | Per-hour + per-GB | Instance cost |
| Port forwarding | ❌ | ✅ |

**Security**: NAT Gateway is preferred because it's managed, patched automatically, and can't be SSH'd into (smaller attack surface).

### 3.6 VPC Peering vs Transit Gateway

| Feature | VPC Peering | Transit Gateway |
|---------|-------------|-----------------|
| Connectivity | Point-to-point (1:1) | Hub-and-spoke (many:many) |
| Transitive | ❌ Non-transitive | ✅ Transitive |
| Cross-region | ✅ | ✅ |
| Cross-account | ✅ | ✅ (shared via RAM) |
| Overlapping CIDR | ❌ Not allowed | ❌ Not allowed |
| Route table segmentation | ❌ | ✅ (TGW route tables) |
| Bandwidth | No limit (within AZ) | Up to 50 Gbps per attachment |
| Cost | Free (in-AZ) | Per-attachment + per-GB |
| Security inspection | ❌ | ✅ (route through firewall VPC) |

**Exam-Critical**: VPC Peering is NOT transitive. If VPC-A peers with VPC-B and VPC-B peers with VPC-C, VPC-A CANNOT reach VPC-C through VPC-B. Use Transit Gateway for transitive routing.

---

## 4. Threat Mitigation Coverage

### Infrastructure-Level Threats

| Threat | VPC Feature That Mitigates |
|--------|---------------------------|
| **Unauthorized network access** | Security Groups (deny-all default inbound) |
| **Lateral movement** | Micro-segmentation with SGs per tier/service |
| **Data exfiltration (internet)** | Private subnets + no NAT/IGW route |
| **Data exfiltration (DNS tunneling)** | Route 53 Resolver DNS Firewall |
| **Port scanning / recon** | NACLs deny + Flow Logs detect |
| **DDoS at network level** | Shield Standard + NACLs at border |
| **Unauthorized AWS service access** | VPC Endpoint policies restrict service scope |
| **Cross-tenant traffic** | Separate VPCs / TGW route table isolation |
| **Man-in-the-middle (within VPC)** | VPC encryption in transit (Nitro), TLS enforcement |
| **Rogue NAT / DHCP** | AWS-managed NAT GW, no user DHCP servers |

### Application-Level Threats

| Threat | VPC Feature That Mitigates |
|--------|---------------------------|
| **SSRF to metadata service** | IMDSv2 + remove route to 169.254.169.254 |
| **Database exposure** | Isolated subnets (no IGW/NAT route) |
| **API endpoint exposure** | VPC Endpoints + PrivateLink (no internet) |
| **Container escape** | Security Groups for Pods (EKS) |
| **Overly permissive endpoints** | VPC Endpoint policies (restrict to specific resources) |

---

## 5. Defense-in-Depth Positioning

### Where VPC Security Sits

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 0: ACCOUNT ISOLATION (AWS Organizations / separate accounts)│
├─────────────────────────────────────────────────────────────────┤
│ Layer 1: NETWORK PERIMETER (VPC boundary)                        │
│  • VPC isolation from internet (private subnets)                │
│  • No IGW in isolated VPCs                                      │
│  • Transit Gateway route table segmentation                     │
├─────────────────────────────────────────────────────────────────┤
│ Layer 2: SUBNET CONTROLS (NACLs + Route Tables)                  │  ← VPC
│  • NACLs block known-bad IPs (stateless deny)                   │
│  • Route tables control egress paths                            │
│  • Separate subnets per tier (web/app/db)                       │
├─────────────────────────────────────────────────────────────────┤
│ Layer 3: INSTANCE CONTROLS (Security Groups)                     │  ← VPC
│  • Least-privilege per service/tier                              │
│  • SG-to-SG references (no IP ranges needed)                   │
│  • Deny-all default inbound                                     │
├─────────────────────────────────────────────────────────────────┤
│ Layer 4: DEEP PACKET INSPECTION (Network Firewall)               │
│  • IDS/IPS rules (Suricata-compatible)                          │
│  • Domain filtering, TLS inspection                             │
├─────────────────────────────────────────────────────────────────┤
│ Layer 5: APPLICATION LAYER (WAF, app-level auth)                 │
└─────────────────────────────────────────────────────────────────┘
```

### Integration with Other Security Services

| Service | VPC Integration |
|---------|-----------------|
| **GuardDuty** | Consumes VPC Flow Logs for threat detection |
| **Network Firewall** | Deployed in VPC subnets for IDS/IPS |
| **Security Hub** | Reports VPC misconfigurations (open SGs, no Flow Logs) |
| **AWS Config** | Rules: restricted-ssh, vpc-flow-logs-enabled, vpc-sg-open-only-to-authorized-ports |
| **CloudTrail** | Logs VPC API calls (CreateSecurityGroup, AuthorizeIngress) |
| **Transit Gateway** | Connects VPCs with route-based segmentation |
| **RAM** | Shares subnets and TGW across accounts |
| **Network Access Analyzer** | Identifies unintended network paths |
| **Reachability Analyzer** | Tests connectivity between resources |

### Cost vs Risk Recommendations

| Feature | Cost | Security Value | Recommendation |
|---------|------|----------------|----------------|
| Security Groups | Free | Critical | ✅ Always (primary control) |
| NACLs | Free | High | ✅ Always (defense-in-depth) |
| VPC Flow Logs | Per-GB ingested | High | ✅ Always enable at VPC level |
| Gateway Endpoints (S3/DDB) | Free | High | ✅ Always use |
| Interface Endpoints | ~$7/month/AZ | Medium-High | Use for compliance / zero-trust |
| NAT Gateway | ~$32/month + per-GB | Medium | Only when internet needed |
| Transit Gateway | Per-attachment + per-GB | High for multi-account | Use when >3 VPCs |
| Network Firewall | ~$0.395/hour + per-GB | High | For regulated workloads |

---

## 6. Exam-Critical Points

### 🎯 Must-Know Facts for SCS-C03

1. **Security Groups are stateful, NACLs are stateless** — #1 most tested VPC fact
2. **Security Groups have allow rules only; NACLs have allow AND deny** — key difference
3. **NACL rules evaluated in order (lowest number first)**; SG rules ALL evaluated before decision
4. **Ephemeral ports (1024-65535)** must be allowed in NACL outbound for return traffic
5. **VPC Peering is NOT transitive** — can't route through a peered VPC to reach a third VPC
6. **Gateway Endpoints are FREE** (S3 and DynamoDB only); Interface Endpoints cost money
7. **Flow Logs don't capture** DNS, DHCP, metadata, or time sync traffic
8. **Private DNS for interface endpoints** resolves public service domain to private IP
9. **VPC Endpoint policies** restrict WHAT can be accessed; SGs restrict WHO can access the endpoint
10. **NAT Gateway can't have Security Groups** — use NACLs for NAT GW subnets
11. **Default SG** allows all outbound and allows inbound from same SG only
12. **Default NACL** allows all inbound and outbound (custom NACLs deny all by default)
13. **Security Groups for Pods (EKS)** — Nitro-based instances allow per-pod SG assignment
14. **Transit Gateway route tables** provide network segmentation across accounts
15. **Prefix lists** — managed or custom, used in SGs and route tables (e.g., CloudFront managed prefix list)

### Common Exam Question Patterns

**Pattern 1: "Security Group vs NACL — which to use?"**
- Need to DENY specific IP → NACL (SGs can't deny)
- Need stateful filtering → Security Group
- Need subnet-level control → NACL
- Need instance-level control → Security Group
- Need to block traffic during DDoS → NACL

**Pattern 2: "How to provide private access to S3 without internet?"**
- Gateway Endpoint (free, route table entry)
- NOT Interface Endpoint (costs money for S3 unless you need cross-region)
- Endpoint Policy restricts to specific buckets

**Pattern 3: "Traffic being rejected — what's wrong?"**
- Check NACL ephemeral ports (stateless — return traffic needs explicit allow)
- Check SG allows the specific port/protocol
- Check route table has correct route
- Check NACL rule ORDER (lower number wins)

**Pattern 4: "How to connect 10+ VPCs securely?"**
- Transit Gateway (not peering — that's 45 connections for 10 VPCs)
- TGW route tables for segmentation
- Centralized inspection via firewall VPC

**Pattern 5: "How to prevent instances from reaching internet?"**
- No IGW attached to VPC, OR
- No route to IGW/NAT in subnet route table, OR
- Private subnet with no NAT route
- Use VPC endpoints for AWS service access

### Tricky Concepts & Gotchas

1. **NACL + SG interaction**: Traffic must pass BOTH. If NACL allows but SG denies → blocked. If SG allows but NACL denies → blocked.
2. **Default vs Custom NACL**: Default allows ALL; custom denies ALL. Associating a custom NACL to a subnet without adding allow rules breaks all traffic.
3. **Cross-AZ traffic**: Subnets are AZ-specific. Traffic between AZs in the same VPC crosses AZ boundary (cost + latency implications).
4. **SG rule limit**: 60 inbound + 60 outbound per SG. 5 SGs per ENI. Total 300 rules per ENI.
5. **VPC CIDR expansion**: Can add secondary CIDRs but ranges cannot overlap with existing CIDRs or peered VPCs.
6. **Endpoint Private DNS**: When enabled, the public DNS name (e.g., s3.amazonaws.com) resolves to private endpoint IP. This means ALL traffic to that service goes through the endpoint.

### Comparison: VPC Security Controls

| Feature | Security Group | NACL | Endpoint Policy | Network Firewall |
|---------|---------------|------|-----------------|------------------|
| Layer | Instance (L4) | Subnet (L4) | Service (L7) | Subnet (L3-L7) |
| Stateful | ✅ | ❌ | N/A | ✅ |
| Deny rules | ❌ | ✅ | ✅ | ✅ |
| Deep inspection | ❌ | ❌ | ❌ | ✅ |
| Domain filtering | ❌ | ❌ | ❌ | ✅ |
| Cost | Free | Free | Free | Paid |
| Use case | Primary filter | Block IPs | Restrict services | IDS/IPS |

---

## 7. Exam Domain Mapping

| Domain | VPC Relevance |
|--------|--------------|
| **Domain 1: Threat Detection** | Flow Logs → GuardDuty; Traffic Mirroring for forensics |
| **Domain 2: Logging & Monitoring** | VPC Flow Logs (format, analysis, destinations) |
| **Domain 3: Infrastructure Security** | ✅ **PRIMARY** — SGs, NACLs, endpoints, peering, TGW |
| **Domain 4: IAM** | Endpoint policies, SG management via IAM |
| **Domain 5: Data Protection** | PrivateLink (data in transit stays private), encryption in transit |
| **Domain 6: Governance** | Config rules, Network Access Analyzer, shared VPCs via RAM |

---

## 8. Documentation References

- [Infrastructure Security in VPC](https://docs.aws.amazon.com/vpc/latest/userguide/infrastructure-security.html)
- [Security Best Practices for VPC](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)
- [VPC Endpoints (PrivateLink)](https://docs.aws.amazon.com/vpc/latest/userguide/endpoint-services-overview.html)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [Flow Log Record Examples](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-records-examples.html)
- [Security Groups and NACLs (DDoS Best Practices)](https://docs.aws.amazon.com/whitepapers/latest/aws-best-practices-ddos-resiliency/security-groups-and-network-acls-bp5.html)
- [VPC Endpoint Policies](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-access.html)
- [Transit Gateway Documentation](https://aws.amazon.com/documentation-overview/transit-gateway/)

---

*All content sourced from official AWS documentation via AWS Knowledge and Documentation MCP servers. Last updated: June 2026.*

---

## Detailed Attack Mitigation Reference

> Expanded real-world attack scenarios showing how VPC security features mitigate infrastructure and application-level threats.


## Attack 1: Lateral Movement (Post-Compromise Network Propagation)

### Classification: Infrastructure-Level Attack

### What It Is
After compromising one instance (via phishing, vulnerability, or stolen credentials), the attacker moves through the network to reach higher-value targets — databases, admin systems, or other tenants. They scan the internal network and exploit trust relationships between systems.

### Real-World Examples
- **Capital One (2019)** — compromised WAF EC2 role → accessed S3 via metadata service → moved to other resources
- **SolarWinds (2020)** — initial foothold → lateral movement across network using trusted connections
- **NotPetya (2017)** — worm propagated through flat networks using SMB vulnerability

### How VPC Mitigates

| Feature | How It Helps |
|---------|-------------|
| Security Group micro-segmentation | Each tier/service has unique SG — web can't reach DB directly |
| SG-to-SG references | Only specific SGs can communicate (not entire CIDR) |
| Private subnets | Compromised public instance can't route to isolated DB subnet |
| Network ACLs | Deny ports not needed between subnets (defense-in-depth) |
| VPC isolation | Separate VPCs per workload = separate blast radius |
| Security Groups for Pods | Per-pod isolation within same EKS node |

### Configuration
```
Anti-Lateral-Movement SG Design:
  Web SG:   Inbound 443 from NLB-SG; Outbound 8080 to App-SG
  App SG:   Inbound 8080 from Web-SG; Outbound 5432 to DB-SG
  DB SG:    Inbound 5432 from App-SG; Outbound NONE

Result: Web → App → DB (uni-directional flow)
        Web ✗ DB (no direct path)
        App ✗ Web (can't go backward)
```

### Key Exam Point
> Security Groups referencing other Security Groups (not CIDRs) is the best practice for preventing lateral movement. Combined with private subnets and separate VPCs, blast radius is minimized.

---

## Attack 2: Data Exfiltration via DNS Tunneling

### Classification: Application-Level Attack

### What It Is
Attacker encodes stolen data in DNS queries (e.g., `base64-encoded-data.attacker-domain.com`). DNS is often allowed through firewalls, making it an invisible exfiltration channel. Traditional NACLs and SGs can't inspect DNS content.

### Real-World Examples
- **APT groups** routinely use DNS tunneling (DNScat2, Iodine) to bypass network controls
- **FrameworkPOS malware** — exfiltrated credit card data via DNS queries
- **Enterprise breaches** — DNS tunneling goes undetected for months in flat networks

### How VPC Mitigates

| Feature | How It Helps |
|---------|-------------|
| Route 53 Resolver DNS Firewall | Block queries to known-malicious domains |
| VPC Flow Logs | Detect unusual DNS traffic volumes (anomaly detection) |
| GuardDuty | `Trojan:EC2/DNSDataExfiltration` finding detects DNS tunneling |
| Private hosted zones | Limit DNS resolution to approved domains |
| NACLs | Block UDP 53 to external resolvers (force use of VPC resolver) |

### Configuration
```
Route 53 Resolver DNS Firewall Rules:
  Rule 1: BLOCK - AWS Managed Domain List (malware/botnet domains)
  Rule 2: BLOCK - Custom list of suspicious TLDs (.tk, .xyz, etc.)
  Rule 3: ALERT - Any query > 50 characters (potential encoding)
  Rule 4: ALLOW - *.amazonaws.com, *.your-company.com
  Rule 5: BLOCK - All others (allowlist approach)

NACL (defense-in-depth):
  DENY UDP 53 to 0.0.0.0/0 (block external DNS resolvers)
  ALLOW UDP 53 to VPC+2 (Route 53 Resolver only) — Note: NACLs can't actually block this
```

### Key Exam Point
> NACLs CANNOT block DNS traffic to Route 53 Resolver (VPC+2 address). Use Route 53 Resolver DNS Firewall for DNS-level filtering. GuardDuty detects DNS tunneling automatically.

---

## Attack 3: SSRF Targeting Instance Metadata Service (IMDS)

### Classification: Application-Level Attack

### What It Is
Server-Side Request Forgery (SSRF) tricks an application into making requests to the EC2 instance metadata service (169.254.169.254). Attacker extracts IAM role credentials, then uses those credentials to access other AWS services.

### Real-World Examples
- **Capital One (2019)** — SSRF via misconfigured WAF → retrieved IAM role credentials from IMDS → accessed 100M+ records in S3
- **Shopify bug bounty** — SSRF in image processing allowed metadata access
- **Multiple SaaS breaches** — SSRF is in OWASP Top 10 (A10:2021 - Server-Side Request Forgery)

### How VPC Mitigates

| Feature | How It Helps |
|---------|-------------|
| IMDSv2 enforcement | Requires session token (PUT request first) — blocks simple SSRF GET |
| Security Groups | Can't block IMDS (link-local), but limits what compromised instance reaches |
| Private subnets | Reduces attack surface (no direct internet exposure) |
| VPC Endpoint policies | Even with stolen creds, endpoint policy restricts accessible resources |
| Network Firewall | Can detect/block SSRF patterns in HTTP traffic |

### Configuration
```
IMDSv2 Enforcement (not VPC-specific, but critical):
  aws ec2 modify-instance-metadata-options \
    --instance-id i-xxx \
    --http-tokens required \    ← Forces IMDSv2 (session token required)
    --http-put-response-hop-limit 1 \  ← Prevents containers from reaching host IMDS
    --http-endpoint enabled

VPC-level defense:
  • Instance profile with minimal permissions (even if creds stolen, limited damage)
  • VPC Endpoint policy on S3: restrict to org buckets only
  • Network Firewall rule: block outbound to 169.254.0.0/16 from containers
```

### Key Exam Point
> IMDSv2 with `http-tokens: required` and `hop-limit: 1` is the primary defense against SSRF. VPC endpoint policies provide defense-in-depth by limiting what stolen credentials can access. NACLs CANNOT block traffic to IMDS (169.254.169.254).

---

## Attack 4: Port Scanning & Network Reconnaissance

### Classification: Infrastructure-Level Attack

### What It Is
Attacker scans IP ranges and ports to discover running services, identify vulnerabilities, and map the network topology. Often the first step before exploitation.

### Real-World Examples
- **Pre-breach scanning** — automated tools (Masscan, Nmap) scan entire VPC CIDRs
- **Internal recon after compromise** — attacker maps all listening services
- **Shodan/Censys** — public scanners constantly scanning cloud IP ranges

### How VPC Mitigates

| Feature | How It Helps |
|---------|-------------|
| Security Groups (deny-all default) | Only explicitly opened ports respond; all others silently drop |
| Private subnets | No public IP = not reachable from internet |
| VPC Flow Logs | Detect scanning patterns (many REJECT entries from single source) |
| GuardDuty | `Recon:EC2/PortProbeUnprotectedPort` finding detects probes |
| NACLs | Block known scanner IP ranges proactively |
| Network Access Analyzer | Find unintended access paths before attackers do |

### Configuration
```
Detection (GuardDuty + Flow Logs):
  GuardDuty finding: Recon:EC2/Portscan
  → Indicates an instance is performing port scans (compromised)

  Flow Log query (CloudWatch Insights):
    fields srcAddr, dstAddr, dstPort, action
    | filter action = "REJECT"
    | stats count(*) as attempts by srcAddr
    | filter attempts > 100
    | sort attempts desc
  → Identifies sources hitting many ports (scanner)

Response (automated):
  EventBridge → Lambda → Update NACL Rule 1: DENY srcAddr
```

### Key Exam Point
> Security Groups silently DROP non-matching traffic (don't send RST/ICMP unreachable) — this makes scanning slower and less informative. GuardDuty's `Recon:EC2/Portscan` finding detects when YOUR instances are scanning (indicates compromise).

---

## Attack 5: Unauthorized Cross-VPC/Cross-Account Access

### Classification: Infrastructure-Level Attack

### What It Is
Attacker gains access to one VPC/account and attempts to reach resources in other VPCs by exploiting overly permissive peering connections, Transit Gateway routes, or shared subnets.

### Real-World Examples
- **Multi-tenant SaaS breaches** — tenant in shared infrastructure accesses another tenant's resources
- **Dev → Prod lateral movement** — developer account compromised, reaches production database
- **Third-party integrations** — partner VPC with peering has excessive access

### How VPC Mitigates

| Feature | How It Helps |
|---------|-------------|
| TGW Route Table segmentation | Prod RT has no route to Dev, and vice versa |
| VPC Peering (non-transitive) | Can't hop through a peered VPC to reach a third |
| Security Groups | Must explicitly allow cross-VPC CIDR |
| NACLs | Deny unexpected cross-VPC CIDRs |
| Separate VPCs per tenant/environment | Hard network boundary |
| RAM sharing with conditions | Share subnets only to specific accounts/OUs |

### Configuration
```
TGW Route Table Segmentation:
  Prod Route Table:
    10.1.0.0/16 → Prod VPC attachment
    10.100.0.0/16 → Shared Services attachment
    0.0.0.0/0 → Inspection VPC attachment
    (NO entry for 10.2.0.0/16 — Dev is unreachable)

  Dev Route Table:
    10.2.0.0/16 → Dev VPC attachment
    10.100.0.0/16 → Shared Services attachment
    0.0.0.0/0 → Inspection VPC attachment
    (NO entry for 10.1.0.0/16 — Prod is unreachable)

Security Group (Prod DB):
  Inbound: 5432 from 10.1.0.0/16 ONLY (Prod VPC)
  NOT from 10.0.0.0/8 (too broad — includes Dev)
```

### Key Exam Point
> Transit Gateway route tables are the primary tool for multi-account network segmentation. VPC Peering is non-transitive by design. Always use specific CIDRs in SG rules, never overly broad ranges like 10.0.0.0/8.

---

## Attack 6: Cryptomining via Compromised Instances

### Classification: Infrastructure-Level Attack

### What It Is
Attacker gains access to EC2 instances and runs cryptocurrency mining software. The miner makes outbound connections to mining pools and consumes all CPU resources. Often detected only via unexpected bills.

### Real-World Examples
- **Tesla cloud breach (2018)** — unsecured Kubernetes dashboard → cryptominer deployed
- **Multiple AWS accounts (ongoing)** — leaked credentials → spot instances for mining
- **Container escape** — escape EKS pod → mine on host

### How VPC Mitigates

| Feature | How It Helps |
|---------|-------------|
| Restricted outbound SGs | No rule allowing outbound to mining pool IPs/ports |
| Network Firewall domain filtering | Block known mining pool domains (*.nanopool.org, etc.) |
| GuardDuty | `CryptoCurrency:EC2/BitcoinTool.B!DNS` finding detects mining DNS lookups |
| VPC Flow Logs | Detect sustained high-bandwidth outbound connections |
| NACLs | Block known mining pool CIDR ranges |
| Private subnets (no NAT) | Miners can't reach internet mining pools |

### Configuration
```
Network Firewall Domain Blocklist:
  • *.nanopool.org
  • *.ethermine.org  
  • *.f2pool.com
  • *.antpool.com
  • *.minergate.com
  • stratum+tcp://* (mining protocol)

Security Group (restrictive outbound):
  Outbound: 443 to VPC-endpoints-SG only
  Outbound: 443 to specific known-good CIDRs
  NOT: 0.0.0.0/0 (never allow all outbound in production)
```

### Key Exam Point
> GuardDuty detects cryptomining via DNS queries to mining pools and unusual network patterns. The best VPC prevention is restrictive OUTBOUND security groups (deny-all outbound except known-good) combined with Network Firewall domain filtering.

---

## Attack 7: Data Exfiltration to External S3 Buckets

### Classification: Application-Level Attack

### What It Is
Insider threat or compromised service uploads sensitive data to S3 buckets outside the organization. Default S3 access allows writing to ANY bucket if IAM permits it.

### Real-World Examples
- **Insider data theft** — employee copies customer database to personal S3 bucket
- **Supply chain attack** — compromised CI/CD pipeline exfils code to external bucket
- **Credential theft** — attacker uses stolen creds to copy data to their own account

### How VPC Mitigates

| Feature | How It Helps |
|---------|-------------|
| S3 Gateway Endpoint with org-restriction policy | Only org-owned buckets accessible |
| No internet route | Without NAT/IGW, can't reach S3 via public endpoint |
| VPC Endpoint Policy (aws:ResourceOrgID) | Restricts S3 access to organization buckets only |
| Network Firewall | Block S3 public endpoints if endpoint policy bypassed |
| Flow Logs | Detect unusual data volume to S3 endpoints |

### Configuration
```json
S3 Gateway Endpoint Policy:
{
  "Statement": [
    {
      "Sid": "AllowOrgBucketsOnly",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:ResourceOrgID": "o-myorgid123"
        }
      }
    }
  ]
}
```

### Key Exam Point
> VPC Endpoint policies with `aws:ResourceOrgID` condition create a "data perimeter" that prevents exfiltration to external S3 buckets regardless of IAM permissions. This works even if an admin has `s3:*` — the endpoint policy denies it.

---

## Attack 8: Man-in-the-Middle Within VPC

### Classification: Infrastructure-Level Attack

### What It Is
Attacker on a compromised instance attempts to intercept traffic between other instances in the same VPC — via ARP spoofing, DNS poisoning, or traffic redirection.

### Real-World Examples
- **Cloud MITM research** — demonstrated ARP spoofing within AWS VPCs (largely mitigated by AWS network infrastructure)
- **Container MITM** — pods in same node network attempting to intercept traffic
- **Insider threat** — admin with EC2 access deploying packet capture tools

### How VPC Mitigates

| Feature | How It Helps |
|---------|-------------|
| AWS network fabric | **ARP spoofing is not possible** — AWS hypervisor controls MAC-IP binding |
| Security Groups | Traffic between instances must be explicitly allowed |
| Encryption in transit | Nitro instances encrypt inter-instance traffic automatically |
| TLS enforcement | Application-level encryption prevents content reading |
| Private DNS (Route 53) | DNS is controlled by AWS (can't be poisoned by instances) |
| VPC encryption | Traffic between Nitro instances in same VPC is encrypted at network layer |

### Configuration
```
Defense (mostly built-in):
  1. AWS hypervisor prevents ARP/MAC spoofing (automatic)
  2. Nitro instances encrypt inter-node traffic (automatic)
  3. Enforce TLS between all services (application config)
  4. Use security groups to prevent unauthorized inter-instance communication
  5. Enable VPC Flow Logs to detect unusual traffic patterns
```

### Key Exam Point
> AWS network infrastructure prevents traditional MITM attacks (ARP spoofing, MAC flooding). However, you should still enforce TLS between services and use Security Groups to prevent unauthorized communication. Nitro-based instances provide automatic encryption for inter-instance traffic within the VPC.

---

## Attack 9: Security Group Misconfiguration (0.0.0.0/0 Inbound)

### Classification: Infrastructure-Level Attack

### What It Is
Overly permissive security groups expose services to the entire internet. The most common cloud misconfiguration — databases, admin panels, SSH, and internal APIs accidentally open to 0.0.0.0/0.

### Real-World Examples
- **MongoDB ransom attacks (2017)** — 28,000+ databases exposed to internet with no auth
- **Elasticsearch exposure (multiple)** — millions of records leaked from open instances
- **RDS exposure** — databases with 0.0.0.0/0 on port 3306/5432

### How VPC Mitigates

| Feature | How It Helps |
|---------|-------------|
| Security Group best practices | Use SG references instead of 0.0.0.0/0 |
| AWS Config rules | `restricted-ssh`, `vpc-sg-open-only-to-authorized-ports` detect violations |
| Security Hub | FSBP finding: "EC2.19 Security groups should not allow unrestricted access" |
| Network Access Analyzer | Proactively identifies unintended internet exposure |
| Private subnets | Even if SG is open, no public IP = not reachable |
| NACLs | Defense-in-depth — deny inbound from internet on DB ports |

### Configuration
```
AWS Config Rule (auto-remediation):
  Rule: restricted-ssh
  Trigger: SG allows 0.0.0.0/0 on port 22
  Remediation: SSM Automation → revoke ingress rule

  Rule: vpc-sg-open-only-to-authorized-ports
  Trigger: SG allows 0.0.0.0/0 on unauthorized ports
  Remediation: Lambda → remove the rule + SNS notification

Prevention (SCP):
{
  "Effect": "Deny",
  "Action": "ec2:AuthorizeSecurityGroupIngress",
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "ec2:IpPermission.IpProtocol": "tcp",
      "ec2:IpPermission.FromPort": "22",
      "ec2:IpPermission.ToPort": "22"
    },
    "ForAnyValue:IpPermission.IpRanges": "0.0.0.0/0"
  }
}
```

### Key Exam Point
> Config rules + auto-remediation is the standard pattern for detecting and fixing open security groups. Private subnets provide defense-in-depth — even if SG is misconfigured, instance without public IP is unreachable from internet.

---

## Attack 10: Unauthorized Internet Access from Sensitive Resources

### Classification: Infrastructure-Level Attack

### What It Is
Database servers, application backends, or sensitive data processing systems that should never have internet access accidentally get it through misconfigured route tables, overly broad NAT rules, or dual-homed instances.

### Real-World Examples
- **Compliance violations** — PCI DSS database with internet route = audit failure
- **Data exfil path** — RDS backup scripts accidentally uploading via internet
- **Malware C2** — compromised database instance communicating with C2 server via NAT

### How VPC Mitigates

| Feature | How It Helps |
|---------|-------------|
| Isolated subnets (no 0.0.0.0/0 route) | Route table has ONLY local route |
| VPC Endpoints | Access AWS services without internet |
| Network Access Analyzer | Detects paths from resource to internet gateway |
| NACLs | Explicit DENY to 0.0.0.0/0 (defense-in-depth) |
| Config rules | Detect route table changes that add internet routes |
| Restrictive outbound SG | Only allow traffic to specific VPC CIDRs/endpoints |

### Configuration
```
Isolated Subnet Route Table:
  10.0.0.0/16 → local
  pl-xxx → vpce-s3 (S3 gateway endpoint)
  (NO other routes — no 0.0.0.0/0)

NACL (belt-and-suspenders):
  Outbound Rule 1: DENY ALL to 0.0.0.0/0
  Outbound Rule 100: ALLOW TCP 5432 to 10.0.0.0/16 (local VPC only)
  Outbound Rule 110: ALLOW TCP 443 to pl-xxx (S3 prefix list)

Network Access Analyzer:
  Scope: Find paths from RDS ENIs → Internet Gateway
  Expected: No paths found
  Alert: If path found → immediate remediation
```

### Key Exam Point
> For compliance (PCI DSS, HIPAA), databases must be in subnets with NO internet route. Use VPC endpoints for any AWS service access needed. Network Access Analyzer proactively validates there's no unintended internet path.

---

## Summary: Attack Classification Matrix

| Attack | Level | Primary VPC Defense | Secondary Defense |
|--------|-------|---------------------|-------------------|
| Lateral Movement | Infrastructure | SG micro-segmentation | Separate VPCs/subnets |
| DNS Tunneling | Application | Route 53 DNS Firewall | GuardDuty detection |
| SSRF → IMDS | Application | IMDSv2 enforcement | VPC Endpoint policies |
| Port Scanning | Infrastructure | SG deny-all default | Flow Logs + GuardDuty |
| Cross-VPC Access | Infrastructure | TGW route segmentation | SG CIDR restrictions |
| Cryptomining | Infrastructure | Restrictive outbound SG | Network Firewall domains |
| S3 Exfiltration | Application | Endpoint Policy (OrgID) | No internet route |
| MITM in VPC | Infrastructure | AWS network fabric (auto) | TLS + SGs |
| Open SG (0.0.0.0/0) | Infrastructure | Config rules + auto-fix | Private subnets |
| Unauthorized Internet | Infrastructure | Isolated route table | NACL deny + NW Analyzer |

---

*All content sourced from official AWS documentation via AWS Knowledge and Documentation MCP servers. Last updated: June 2026.*

---

## Production Use Cases & Architecture Patterns

> Real-world production scenarios with complete VPC security configurations for enterprise environments.


## Use Case 1: Multi-Tier SaaS Platform (Public/Private/Isolated Subnets)

### Business Context
A multi-tenant ITOM SaaS platform needs complete network tier separation: public-facing load balancers, private application tier (EKS), and fully isolated database tier (RDS) with zero internet access.

### Architecture
```
┌───────────────────────────── VPC 10.0.0.0/16 ──────────────────────────┐
│                                                                          │
│  AZ-a                              AZ-b                                  │
│  ┌───────────────────┐            ┌───────────────────┐                 │
│  │ Public 10.0.1.0/24│            │ Public 10.0.4.0/24│                 │
│  │ • NLB             │            │ • NLB             │                 │
│  │ • NAT Gateway     │            │ • NAT Gateway     │                 │
│  │ Route: 0.0.0.0→IGW│            │ Route: 0.0.0.0→IGW│                 │
│  └────────┬──────────┘            └────────┬──────────┘                 │
│           │                                 │                            │
│  ┌────────┴──────────┐            ┌────────┴──────────┐                 │
│  │ Private 10.0.2.0/24│           │ Private 10.0.5.0/24│                │
│  │ • EKS worker nodes │           │ • EKS worker nodes │                │
│  │ • App containers   │           │ • App containers   │                │
│  │ Route: 0.0.0.0→NAT│           │ Route: 0.0.0.0→NAT│                │
│  └────────┬──────────┘            └────────┬──────────┘                 │
│           │                                 │                            │
│  ┌────────┴──────────┐            ┌────────┴──────────┐                 │
│  │ Isolated 10.0.3.0/24│          │ Isolated 10.0.6.0/24│               │
│  │ • RDS Primary      │          │ • RDS Standby      │               │
│  │ • ElastiCache      │          │ • ElastiCache      │               │
│  │ Route: 10.0.0.0/16 │          │ Route: 10.0.0.0/16 │               │
│  │        → local ONLY│          │        → local ONLY│               │
│  └───────────────────┘            └───────────────────┘                 │
│                                                                          │
│  VPC Endpoints (in private subnets):                                    │
│  • Gateway: S3, DynamoDB                                                │
│  • Interface: ECR, CloudWatch, STS, Secrets Manager, KMS               │
└──────────────────────────────────────────────────────────────────────────┘
```

### Security Group Configuration
```
NLB SG:       Inbound: 443 from 0.0.0.0/0 (or CloudFront prefix list)
EKS Node SG:  Inbound: 8443 from NLB-SG; 443 from EKS-control-plane
RDS SG:       Inbound: 5432 from EKS-Node-SG ONLY
              Outbound: NONE (stateful return only)
```

### Security Rationale
- **Isolated subnets** have NO route to internet (no IGW, no NAT) — database can't be exfiltrated via internet
- **VPC Endpoints** allow EKS to pull images (ECR) and write logs (CloudWatch) without internet
- **SG chaining** (NLB→EKS→RDS) means each tier can only talk to its neighbor
- **Multi-AZ** provides fault tolerance within the security boundary

---

## Use Case 2: Multi-Account VPC with Centralized Egress & Inspection

### Business Context
Enterprise with 50+ AWS accounts needs centralized internet egress through a firewall VPC for inspection, logging, and cost optimization. All traffic between environments must be inspectable.

### Architecture
```
┌─────────────────────────────────────────────────────────────────────┐
│                    Transit Gateway (TGW)                              │
│                                                                       │
│  TGW Route Tables:                                                   │
│  ┌─────────────────────┐  ┌────────────────┐  ┌─────────────────┐ │
│  │ Prod RT             │  │ Dev RT         │  │ Shared RT       │ │
│  │ 0.0.0.0/0→Inspect  │  │ 0.0.0.0/0→Insp│  │ 0.0.0.0/0→Insp│ │
│  │ 10.0.0.0/8→Shared  │  │ 10.0.0.0/8→Shr│  │ 10.0.0.0/8→all│ │
│  │ NO route to Dev!    │  │ NO route to Prd│  │                 │ │
│  └─────────────────────┘  └────────────────┘  └─────────────────┘ │
└──────────┬──────────────────────┬──────────────────────┬────────────┘
           │                      │                      │
    ┌──────┴──────┐       ┌──────┴──────┐      ┌───────┴───────┐
    │ Prod VPC    │       │ Dev VPC     │      │ Inspection VPC│
    │ 10.1.0.0/16│       │ 10.2.0.0/16│      │ 10.100.0.0/16 │
    │             │       │             │      │               │
    │ • EKS      │       │ • EKS      │      │ • AWS Network │
    │ • RDS      │       │ • RDS      │      │   Firewall    │
    │ • NLB      │       │ • Dev tools│      │ • NAT Gateway │
    └─────────────┘       └─────────────┘      │ • Egress IGW │
                                                └───────────────┘
```

### Configuration
```
Inspection VPC:
  Public Subnet:  NAT GW + IGW (outbound path to internet)
  Firewall Subnet: Network Firewall endpoints
  TGW Subnet:     TGW attachment

Appliance Mode: Enabled on TGW (ensures symmetric routing)

Network Firewall Rules:
  • Allow: *.amazonaws.com (AWS services)
  • Allow: specific-approved-domains.com
  • Deny: All other domains
  • IPS: Suricata rules for known threats
```

### Security Rationale
- **Prod can't reach Dev** — TGW route table has no route between them
- **All egress inspected** — Network Firewall sees every outbound packet
- **Centralized NAT** — single point for IP allowlisting by partners
- **Domain filtering** — prevents data exfil to unauthorized domains
- **Cost optimization** — fewer NAT Gateways (centralized instead of per-VPC)

---

## Use Case 3: Zero-Internet Database with VPC Endpoints Only

### Business Context
A financial services company must ensure their RDS databases can NEVER reach the internet (PCI DSS requirement), but still need to write logs to CloudWatch and perform automated backups to S3.

### Architecture
```
┌──────────── Isolated Database VPC (10.3.0.0/16) ────────────────┐
│                                                                    │
│  Route Table (ALL subnets):                                       │
│    10.3.0.0/16 → local                                           │
│    pl-xxx (S3 prefix list) → vpce-s3-gateway                    │
│    NO 0.0.0.0/0 route (no internet path exists)                  │
│                                                                    │
│  ┌─────────── DB Subnet Group ───────────────┐                   │
│  │  AZ-a: 10.3.1.0/24  │  AZ-b: 10.3.2.0/24│                   │
│  │  • RDS Primary       │  • RDS Standby     │                   │
│  └──────────────────────┴────────────────────┘                   │
│                                                                    │
│  VPC Endpoints:                                                   │
│  • Gateway: S3 (for backups, free)                               │
│  • Interface: CloudWatch Logs (for audit logs)                   │
│  • Interface: Secrets Manager (for credential rotation)          │
│  • Interface: KMS (for encryption operations)                    │
│                                                                    │
│  Endpoint Policy (S3 Gateway):                                    │
│  {                                                                │
│    "Effect": "Allow",                                            │
│    "Principal": "*",                                             │
│    "Action": ["s3:PutObject"],                                   │
│    "Resource": "arn:aws:s3:::rds-backups-prod/*",               │
│    "Condition": {                                                │
│      "StringEquals": {"aws:sourceVpc": "vpc-abc123"}            │
│    }                                                             │
│  }                                                                │
│                                                                    │
│  NACL:                                                            │
│  • DENY ALL to 0.0.0.0/0 (defense-in-depth, no route anyway)   │
│  • ALLOW 5432 from 10.1.0.0/16 (app VPC CIDR only)            │
│                                                                    │
│  Security Group (RDS):                                            │
│  • Inbound: 5432 from App-VPC-SG (via TGW or peering)          │
│  • Outbound: 443 to endpoint-SGs only                           │
└────────────────────────────────────────────────────────────────────┘
```

### Security Rationale
- **No internet route** — even if credentials are stolen, data can't be exfiltrated via internet
- **Endpoint policy restricts S3** — can only write to specific backup bucket, not arbitrary buckets
- **NACL as defense-in-depth** — explicitly denies internet even though no route exists
- **Endpoint SGs** — only the RDS instances can reach the VPC endpoints
- **Meets PCI DSS 1.3** — network segmentation preventing database from initiating outbound connections

---

## Use Case 4: EKS Cluster with Security Groups for Pods

### Business Context
A SaaS platform runs multiple microservices in the same EKS cluster. Different services need different network access patterns — the payment service needs RDS access, but the notification service only needs SES access. Traditional SGs apply to the entire node.

### Architecture
```
┌──────────────── EKS Private Subnet ────────────────────────┐
│                                                              │
│  Worker Node (m5.xlarge — Nitro-based)                      │
│  Node Security Group: sg-node (allows EKS control plane)   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Pod: payment-service                                 │   │
│  │ SG: sg-payment                                       │   │
│  │ • Outbound: 5432 to RDS-SG                          │   │
│  │ • Outbound: 443 to KMS endpoint                     │   │
│  │ • Inbound: 8080 from NLB-SG                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Pod: notification-service                            │   │
│  │ SG: sg-notification                                  │   │
│  │ • Outbound: 443 to SES endpoint ONLY                │   │
│  │ • Inbound: 8080 from payment-SG                     │   │
│  │ • NO access to RDS (no rule)                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Pod: monitoring-agent                                │   │
│  │ SG: sg-monitoring                                    │   │
│  │ • Outbound: 443 to CloudWatch endpoint              │   │
│  │ • Inbound: NONE (only makes outbound calls)         │   │
│  └─────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

### Configuration (SecurityGroupPolicy CRD)
```yaml
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: payment-service-sgp
spec:
  podSelector:
    matchLabels:
      app: payment-service
  securityGroups:
    groupIds:
      - sg-0123456789abcdef0  # sg-payment
```

### Security Rationale
- **Micro-segmentation** — each pod type has unique network rules
- **Blast radius containment** — compromised notification service can't reach database
- **Least privilege** — pods only get network access they need
- **Requirement**: Nitro-based instances (m5, c5, r5 or newer) for per-pod SG support

---

## Use Case 5: Hybrid Connectivity with Direct Connect + VPN Backup

### Business Context
Enterprise connects on-premises data center to AWS VPC via Direct Connect (primary) with Site-to-Site VPN as backup. Must ensure encrypted transit and no single point of failure.

### Architecture
```
On-Premises Data Center
       │
       ├── Direct Connect (10 Gbps) ── DX Gateway ──┐
       │   • Private VIF                              │
       │   • MACsec encryption (Layer 2)             │
       │                                              │
       ├── Site-to-Site VPN (backup) ────────────────┤── Transit Gateway
       │   • IPsec encrypted (AES-256)               │       │
       │   • 2 tunnels for HA                         │       │
       │   • BGP for routing                          │       │
       └──────────────────────────────────────────────┘       │
                                                              │
                                                        ┌─────┴─────┐
                                                        │ Prod VPC  │
                                                        │ 10.1.0.0  │
                                                        └───────────┘
TGW Route Priority:
  • DX: Higher BGP local preference (primary)
  • VPN: Lower preference (automatic failover)
```

### Security Configuration
```
Direct Connect:
  • MACsec (802.1AE): Encrypts at Layer 2 on the DX connection
  • Private VIF: Access to VPC (not public AWS services)
  • Route filtering: Only advertise specific VPC CIDRs to on-prem

VPN:
  • IKEv2 with AES-256-GCM
  • Perfect Forward Secrecy (DH Group 20)
  • Custom tunnel options (DPD timeout, rekey interval)
  • Accelerated VPN (uses AWS Global Accelerator)

Security Groups:
  • Allow on-prem CIDRs (10.200.0.0/16) to specific ports only
  • NOT 0.0.0.0/0 — restrict to known on-prem ranges
```

### Security Rationale
- **DX + MACsec** — dedicated connection + Layer 2 encryption (data never traverses public internet)
- **VPN as backup** — encrypted failover path if DX fails
- **TGW routing** — BGP provides automatic failover (no manual intervention)
- **Least-privilege SGs** — on-prem access only to specific ports, not entire VPC

---

## Use Case 6: VPC Endpoint Data Perimeter (Prevent Data Exfiltration)

### Business Context
A company must ensure that employees/services can only access S3 buckets owned by the organization — not upload data to personal or competitor buckets (insider threat / data exfil prevention).

### Architecture
```
┌────────────────── Corporate VPC ──────────────────────────────┐
│                                                                 │
│  S3 Gateway Endpoint with Restrictive Policy:                  │
│  {                                                             │
│    "Statement": [                                              │
│      {                                                         │
│        "Effect": "Allow",                                      │
│        "Principal": "*",                                       │
│        "Action": "s3:*",                                       │
│        "Resource": "*",                                        │
│        "Condition": {                                          │
│          "StringEquals": {                                     │
│            "aws:ResourceOrgID": "o-myorg123456"               │
│          }                                                     │
│        }                                                       │
│      },                                                        │
│      {                                                         │
│        "Effect": "Deny",                                       │
│        "Principal": "*",                                       │
│        "Action": "s3:*",                                       │
│        "Resource": "*",                                        │
│        "Condition": {                                          │
│          "StringNotEquals": {                                  │
│            "aws:ResourceOrgID": "o-myorg123456"               │
│          }                                                     │
│        }                                                       │
│      }                                                         │
│    ]                                                           │
│  }                                                             │
│                                                                 │
│  Result: Services can ONLY access S3 buckets within the org   │
│  Attempting to upload to external bucket → Access Denied       │
└─────────────────────────────────────────────────────────────────┘
```

### Security Rationale
- **Data perimeter** — even with valid IAM credentials, can't exfil to external buckets
- **Organization-wide** — `aws:ResourceOrgID` covers ALL accounts in the org
- **Defense against insider threat** — malicious admin can't upload to personal S3
- **No internet needed** — gateway endpoint keeps all traffic private
- **Complements SCPs** — SCP prevents creating buckets; endpoint policy prevents accessing external ones

---

## Use Case 7: Network Forensics with Flow Logs + Traffic Mirroring

### Business Context
Security team needs to investigate a suspected data breach. They need network-level evidence: what traffic went where, when, and packet-level capture for forensics.

### Architecture
```
┌──────────── Incident Response Flow ────────────────────────────┐
│                                                                  │
│  Step 1: VPC Flow Logs (already running)                        │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ 2 123456789012 eni-abc srcIP dstIP 443 52000 6         │    │
│  │   10 5000 1719014400 1719014460 ACCEPT OK              │    │
│  │                                                          │    │
│  │ Analysis: Query with CloudWatch Insights                 │    │
│  │   fields @timestamp, srcAddr, dstAddr, bytes            │    │
│  │   | filter dstPort = 443 and action = "ACCEPT"          │    │
│  │   | stats sum(bytes) by dstAddr                         │    │
│  │   | sort sum_bytes desc                                  │    │
│  │                                                          │    │
│  │ Finding: 50GB uploaded to suspicious IP in 1 hour       │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Step 2: Traffic Mirroring (activated for investigation)        │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Source: eni-abc (suspected compromised instance)         │    │
│  │ Target: NLB → Forensics EC2 (tcpdump/Zeek/Suricata)    │    │
│  │ Filter: All TCP traffic on port 443                      │    │
│  │                                                          │    │
│  │ Captures: Full packet headers + payload                  │    │
│  │ Analysis: Wireshark, Zeek conn.log, SSL certificate    │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Step 3: Containment (NACL + SG update)                        │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ NACL: Rule 1 — DENY ALL to suspicious-IP/32            │    │
│  │ SG: Remove all outbound rules from compromised instance│    │
│  │ Result: Instance isolated but still accessible for      │    │
│  │         forensics via Session Manager                    │    │
│  └────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

### Security Rationale
- **Flow Logs** — always-on lightweight monitoring (metadata only, no payload)
- **Traffic Mirroring** — on-demand deep packet capture when investigation needed
- **NACL for containment** — immediate deny (NACLs take effect instantly, no propagation delay)
- **SG for isolation** — remove outbound to prevent further data loss
- **Session Manager** — access isolated instance without SSH (no network dependency)

---

## Summary: VPC Security Design Patterns

| Pattern | When to Use |
|---------|-------------|
| Public/Private/Isolated subnets | Every production workload |
| SG chaining (tier references) | Multi-tier applications |
| Centralized egress (inspection VPC) | Regulated industries, 10+ accounts |
| VPC Endpoints everywhere | Zero-trust / air-gapped environments |
| Security Groups for Pods | EKS multi-tenant micro-segmentation |
| Endpoint policies with OrgID | Data perimeter / exfil prevention |
| Traffic Mirroring + Flow Logs | Incident response / forensics |
| TGW with route segmentation | Multi-account network isolation |

---

*All content sourced from official AWS documentation via AWS Knowledge and Documentation MCP servers. Last updated: June 2026.*
