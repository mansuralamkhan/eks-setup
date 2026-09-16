# ADR-010: EKS Node Access via AWS Systems Manager

## Context

EKS worker nodes require an operational access mechanism for troubleshooting
and maintenance.

The managed node IAM role currently includes
`AmazonSSMManagedInstanceCore`, which enables AWS Systems Manager Session
Manager access to the nodes.

The repository does not expose SSH or a bastion host as the node access
architecture.

## Decision

Use AWS Systems Manager Session Manager as the operational access mechanism
for EKS worker nodes.

SSH access and bastion hosts are not part of the baseline node-access design.

The managed node role will retain:

`AmazonSSMManagedInstanceCore`

## Consequences

### Positive

- No SSH access path is required for routine node administration.
- No bastion host is required solely for node access.
- Node access can be controlled through IAM.
- Session activity can be integrated with AWS operational auditing.

### Trade-offs

- Node access depends on Systems Manager connectivity.
- IAM permissions must be carefully controlled because SSM provides
  administrative access to the node.
- Session Manager configuration and operational procedures must be maintained.

## Follow-up

- Define the IAM roles permitted to start SSM sessions.
- Ensure SSM session activity is logged according to the platform's
  audit requirements.
