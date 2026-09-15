**ADR-004: Secrets Management — External Secrets Operator**

**Context:** Application manifests previously contained hardcoded or manually added credentials. This could cause differences between what is stored in Git and what is running in the cluster, and made secret rotation manual and error-prone. The platform needs secrets to come from a managed store and be synced automatically, while keeping sensitive values out of Git.

**Decision:** Use External Secrets Operator to sync secrets from AWS Secrets Manager into Kubernetes Secrets using SecretStore/ExternalSecret resources. In real EKS environments, authentication will use IRSA.

**Alternatives considered:**

* *Hardcoded Secrets in Git (sealed or plaintext)* — rejected; plaintext secrets are not acceptable, and sealed secrets still tie secret management to Git changes and do not provide automatic rotation.
* *AWS Secrets and Configuration Provider (CSI driver)* — considered as an alternative that mounts secrets directly as files instead of creating Kubernetes Secrets. Not chosen because ESO works more naturally with existing Deployments that use environment variables or Secret references, avoiding application changes.

**Consequences:**

* Gain: sensitive values never need to be stored in Git, secret rotation in Secrets Manager can be synced automatically, and services get a consistent way to access secrets.
* Cost: depends on correct IRSA configuration. A misconfigured IAM role can stop secret syncing, and ESO adds another component to the secret management flow.
* Follow-up: add alerts for ExternalSecret sync failures so stale secrets are detected before they cause problems, especially when applications restart.
