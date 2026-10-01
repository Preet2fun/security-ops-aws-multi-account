# Layout Guidelines

## 1. Grouping Principles

- AWS Cloud group as outermost layer
- Create sub-groups by functional unit
- Groups arranged horizontally, placed along data flow

### 1.1. Group Hierarchy

```text
AWS Cloud (outermost)
├── VPC
│   ├── Public Subnet
│   │   └── ALB, NAT Gateway, etc.
│   └── Private Subnet
│       └── ECS, RDS, Lambda, etc.
├── S3
├── CloudWatch
└── Other services
```

## 2. Connection Line Rules

### 2.1. Line Types

| Flow Type | Line Style | Usage |
|-----------|-----------|-------|
| Ingestion Flow | Dashed | Data intake |
| Query Flow | Solid | Query/reference |
| Control Flow | Dotted | Control/management |

### 2.2. Arrow Direction

- Arrows follow data flow direction
- Use two unidirectional arrows for bidirectional communication

## 3. Placement Principles

### 3.1. Left-to-Right Flow

```text
[Data Source] → [Processing] → [Storage] → [Analytics/Visualization]
```

### 3.2. Top-to-Bottom Flow (alternative)

```text
[User/Client]
      ↓
[Load Balancer]
      ↓
[Application]
      ↓
[Database]
```

## 4. Visibility

- Place labels near their elements
- Adjust layout to avoid arrow crossings
- Group related elements nearby
- Maintain appropriate whitespace for readability
