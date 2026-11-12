# Fixture for _test-container-check.yml and _test-config-lint.yml: small, hadolint-clean, non-root, with a healthcheck.
FROM alpine:3.24.4@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf

RUN addgroup -S -g 10001 app \
  && adduser -S -u 10001 -G app app

COPY --chown=10001:10001 index.html /srv/index.html

USER 10001:10001

HEALTHCHECK --interval=30s --timeout=5s CMD ["test", "-f", "/srv/index.html"]

CMD ["cat", "/srv/index.html"]
