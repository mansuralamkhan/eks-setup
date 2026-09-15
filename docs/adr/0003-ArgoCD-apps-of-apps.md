ADR-003: GitOps Deployment Pattern — Argo CD App-of-Apps

Context: As the number of services on the platform grows, managing each as an individually registered Argo CD Application doesn't scale operationally — every new service requires manual onboarding, and there's no single place to see or reason about the platform's full application inventory. The platform needs a pattern that lets new services be added declaratively and gives one entry point for platform-wide state.

Decision: Adopt the app-of-apps pattern: a root Argo CD Application manages a set of child Application manifests stored in Git, so onboarding a new service means adding one manifest to a directory rather than manually registering it in Argo CD.

Alternatives considered:

One Application per service, registered manually — rejected as the starting pattern; works at small scale but becomes an operational bottleneck and loses the single-source-of-truth view as service count grows.
ApplicationSet generators — considered as a more dynamic alternative (e.g., auto-generating Applications from a repo directory structure or cluster list); noted as the natural next step if onboarding volume grows further, but app-of-apps is simpler to reason about at current scale.

Consequences:

Gain: declarative onboarding, one visual root for the whole platform's deployed state, easier auditing of what's running where.
Cost: an extra layer of indirection (root app managing child apps) that adds a small learning curve for anyone new to the pattern.
Follow-up: revisit ApplicationSet generators if onboarding frequency increases significantly.