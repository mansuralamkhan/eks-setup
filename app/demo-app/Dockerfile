# Tiny static demo image. It exists so CI has something real to build, sign and
# attest, and so Kyverno has a real signed image to verify (ADR-008).
FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 8080
