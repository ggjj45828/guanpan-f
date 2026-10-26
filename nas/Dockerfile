FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app \
    F_MINUTE_HOST=0.0.0.0 \
    F_MINUTE_PORT=8788

RUN apt-get update \
    && apt-get install --no-install-recommends -y tzdata util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 10001 fminute \
    && useradd --system --uid 10001 --gid fminute --home-dir /nonexistent fminute
WORKDIR /app
COPY nas /app/nas
RUN python3 -c "import nas.fminute.server; import nas.fminute.runtime"
RUN mkdir -p /data && chown fminute:fminute /data
COPY nas/docker-entrypoint.sh /usr/local/bin/f-minute-entrypoint
RUN chmod 0755 /usr/local/bin/f-minute-entrypoint \
    && head -n 1 /usr/local/bin/f-minute-entrypoint | grep -qx '#!/bin/sh'
USER root:root
VOLUME ["/data"]
EXPOSE 8788
ENTRYPOINT ["/usr/local/bin/f-minute-entrypoint"]
CMD ["python3", "-m", "nas.fminute.server"]
