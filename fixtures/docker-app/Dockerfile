# Fixture for _test-container-check.yml and _test-config-lint.yml: small, hadolint-clean, non-root, with a healthcheck.
FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

RUN addgroup -S -g 10001 app \
  && adduser -S -u 10001 -G app app

COPY --chown=10001:10001 index.html /srv/index.html

USER 10001:10001

HEALTHCHECK --interval=30s --timeout=5s CMD ["test", "-f", "/srv/index.html"]

CMD ["cat", "/srv/index.html"]
