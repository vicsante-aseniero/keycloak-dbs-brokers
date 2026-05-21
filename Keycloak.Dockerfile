# ==============================================================================
# STAGE 1: Build & Optimize Keycloak
# ==============================================================================
FROM quay.io/keycloak/keycloak:26.2 AS builder

# Set build-time environment variables
ENV KC_DB=postgres
ENV KC_FEATURES=web-authn,token-exchange,client-policies,admin-fine-grained-authz,scripts,docker
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Run the build tool to compile the optimized runner binaries
RUN /opt/keycloak/bin/kc.sh build

# ==============================================================================
# STAGE 2: Lightweight Runtime Image
# ==============================================================================
FROM quay.io/keycloak/keycloak:26.2

# Copy optimized quarkus build from the builder stage
COPY --from=builder /opt/keycloak/lib/quarkus/ /opt/keycloak/lib/quarkus/

# Set standard runtime settings
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
