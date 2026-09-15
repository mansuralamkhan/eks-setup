ADR-008: Container Supply Chain Security — Cosign + SLSA

Context: Container images built in CI were previously deployed without any verification that they came from the expected build pipeline, meaning a compromised registry or a manually pushed image could reach production undetected.

Decision: Sign all container images in CI using Cosign, following SLSA provenance conventions, and enforce signature verification at admission time via Kyverno policy so unsigned images are rejected before scheduling.

Alternatives considered:

No image verification (registry access control only) — rejected as the status quo; relies entirely on registry permissions being airtight, with no cryptographic guarantee of image provenance.
Notary v2 — considered as an alternative signing tool; not chosen due to Cosign's simpler CLI/CI integration and stronger ecosystem alignment with Kyverno's built-in image verification support.

Consequences:

Gain: cryptographic proof that a running image came from the expected CI pipeline, closing a real supply-chain attack vector.
Cost: adds a signing step to every CI pipeline and a verification step to every deployment; a misconfigured or expired signing key can block legitimate deployments platform-wide.
Follow-up: document key rotation procedure explicitly — an unplanned key rotation without updating the verification policy would cause a platform-wide deployment outage.