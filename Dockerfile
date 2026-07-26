# ---- Builder stage: install build deps + Python wheels ---------------------
FROM python:3.13-slim AS builder

ARG OTS_VERSION=1.7.13

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libc6-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Build wheels into /wheels so the final stage can install without a compiler.
RUN pip install --no-cache-dir --upgrade pip wheel \
    && pip wheel --no-cache-dir --wheel-dir=/wheels \
       "opentakserver==${OTS_VERSION}"

# ---- Final stage: runtime image without compiler toolchain ------------------
FROM python:3.13-slim

ARG OTS_UI_VERSION=v1.7.5
ENV OTS_UI_VERSION=${OTS_UI_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    openssl \
    nginx \
    ffmpeg \
    supervisor \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install OTS from the wheels built above (no gcc/libc6-dev in this stage).
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/opentakserver-*.whl \
    && rm -rf /wheels

# OpenTAKServer's Web UI is a separate Vue.js app (OpenTAKServer-UI).
# The opentakserver package is API-only; nginx must serve the UI and proxy
# /api, /Marti and /socket.io to the Flask app on 127.0.0.1:8081.
RUN mkdir -p /var/www/html \
    && curl -fsSL -o /tmp/ots-ui.zip \
       "https://github.com/brian7704/OpenTAKServer-UI/releases/download/${OTS_UI_VERSION}/OpenTAKServer-UI-${OTS_UI_VERSION}.zip" \
    && unzip -q /tmp/ots-ui.zip -d /var/www/html \
    && rm /tmp/ots-ui.zip \
    && test -f /var/www/html/opentakserver/index.html

# Replace the default Debian nginx site with the OTS config
RUN rm -f /etc/nginx/sites-enabled/default
COPY scripts/nginx_ots.conf /etc/nginx/sites-enabled/ots_http.conf

COPY scripts/supervisord.conf /etc/supervisor/conf.d/ots.conf
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/wait-for-ca.sh /opt/ots/wait-for-ca.sh
COPY scripts/start.sh /opt/ots/start.sh
RUN chmod +x /entrypoint.sh /opt/ots/wait-for-ca.sh /opt/ots/start.sh

EXPOSE 8080 8081 8088 8089 8443 8446

VOLUME ["/data"]

# Lightweight liveness probe: nginx serving the UI on :8080.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8080/ >/dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
