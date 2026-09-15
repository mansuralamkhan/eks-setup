ADR-006: Infrastructure as Code Tool — Terraform

Context: The platform's foundational infrastructure (VPC, EKS cluster, node groups, IRSA roles) needs to be provisioned reproducibly across environments, with changes reviewable before they hit real infrastructure, and without manual console drift accumulating over time.

Decision: Use Terraform as the sole IaC tool for cluster and networking infrastructure, with state stored remotely and changes gated through PR review and terraform plan output.

Alternatives considered:

AWS CloudFormation — rejected as the primary tool; tightly coupled to AWS, verbose for complex module composition, and less portable if the platform ever needs multi-cloud pieces.
Pulumi — considered for its general-purpose language support (writing infra in Python/TypeScript instead of HCL); not chosen because the added language flexibility wasn't worth the smaller ecosystem and less mature module registry compared to Terraform's.
AWS CDK — similar reasoning to Pulumi; stronger typing but a smaller pool of reusable community modules than Terraform.

Consequences:

Gain: mature module ecosystem, wide community support, clear plan/apply review workflow, tool-agnostic enough to extend beyond AWS later if needed.
Cost: HCL is less expressive than a general-purpose language for complex conditional logic; state management (locking, backend config) is an operational responsibility the team owns.
Follow-up: revisit if the platform expands to genuinely multi-cloud infrastructure where Terraform's provider model may need more glue code than a general-purpose IaC tool would.