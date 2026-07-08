FROM python:3.13-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl \
    nginx \
    ffmpeg \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir opentakserver

COPY scripts/supervisord.conf /etc/supervisor/conf.d/ots.conf
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/wait-for-ca.sh /opt/ots/wait-for-ca.sh
COPY scripts/start.sh /opt/ots/start.sh
RUN chmod +x /entrypoint.sh /opt/ots/wait-for-ca.sh /opt/ots/start.sh

EXPOSE 8081 8088 8089 8080 8443 8446

VOLUME ["/data"]

ENTRYPOINT ["/entrypoint.sh"]
