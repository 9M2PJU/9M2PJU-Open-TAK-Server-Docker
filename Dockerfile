# ---- Builder stage: install OTS into a venv with all build deps ------------
# Use the full (non-slim) Python image as the builder so we get git, g++,
# pkg-config, and common dev libraries pre-installed. The full image avoids a
# long apt-get list of build deps. The runtime stage stays slim.
FROM python:3.13 AS builder

ARG OTS_VERSION=1.7.13

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    libproj-dev \
    proj-bin \
    cargo \
    && rm -rf /var/lib/apt/lists/*

# Create a venv and install OTS + all deps into it.
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir --upgrade pip wheel \
    && pip install --no-cache-dir "opentakserver==${OTS_VERSION}"

# ---- Final stage: runtime image without compiler toolchain ------------------
FROM python:3.13-slim

ARG OTS_UI_VERSION=v1.7.5
ENV OTS_UI_VERSION=${OTS_UI_VERSION}
ENV PATH="/opt/venv/bin:$PATH"

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libproj25 \
    openssl \
    nginx \
    ffmpeg \
    supervisor \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Copy the pre-built venv from the builder. All compiled extensions (cffi,
# greenlet, gevent, matplotlib, unishox2-py3, etc.) are already built for
# the target arch. No compiler needed in the runtime stage.
COPY --from=builder /opt/venv /opt/venv

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
