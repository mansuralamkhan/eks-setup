# Runbook: image signing and verification (ADR-008)

## How it works

1. `.github/workflows/image.yml` builds `app/demo-app`, pushes it to
   `ghcr.io/<owner>/eks-setup/demo-app`, signs the digest with Cosign **keyless**
   (GitHub OIDC identity, recorded in the Rekor transparency log) and attaches SLSA
   build provenance.
2. `07-policy/policies/verify-image-signatures.yaml` makes Kyverno check that any image
   from that namespace was signed by exactly that workflow on `main`.

## One-time setup

- Run the `image` workflow once (push a change under `app/` or use *Run workflow*).
- In GitHub, set the package `eks-setup/demo-app` to **public** (Packages, then Package
  settings). The cluster needs to pull it, and Kyverno needs to read its signature.

## Verify from your laptop

```bash
IMAGE=ghcr.io/mansuralamkhan/eks-setup/demo-app
DIGEST=$(docker buildx imagetools inspect $IMAGE:latest --format '{{json .Manifest.Digest}}' | tr -d '"')
cosign verify "$IMAGE@$DIGEST" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity https://github.com/mansuralamkhan/eks-setup/.github/workflows/image.yml@refs/heads/main
```

## Verify in the cluster (Audit mode)

```bash
# signed image: no policy violation expected
kubectl run signed --image=$IMAGE@$DIGEST --restart=Never
# unsigned image in the same registry namespace: push anything there by hand
docker pull nginx:1.27-alpine && docker tag nginx:1.27-alpine ghcr.io/mansuralamkhan/eks-setup/unsigned-test:v1
docker push ghcr.io/mansuralamkhan/eks-setup/unsigned-test:v1
kubectl run unsigned --image=ghcr.io/mansuralamkhan/eks-setup/unsigned-test:v1 --restart=Never
kubectl get policyreport -A | grep -i verify    # the unsigned pod should be listed as a failure
```

## Moving to Enforce

Same rule as ADR-002: only after two weeks of clean reports. Change
`validationFailureAction` to `Enforce` and `mutateDigest` to `true`, and make sure every
image from the namespace is signed first.

## "Key rotation" with keyless signing

There are no long-lived keys to rotate (ADR-008 listed that as a risk). The trust anchor
is the workflow identity in the policy's `subject`. If you rename the workflow file,
change branches or move the repo, **update the policy in the same pull request**,
otherwise verification fails for new images.
