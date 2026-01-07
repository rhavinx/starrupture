FROM steamcmd/steamcmd:debian-13

LABEL org.opencontainers.image.authors="RhavinX" \
      org.opencontainers.image.source=https://github.com/RhavinX/starrupture \
      org.opencontainers.image.description="StarRupture Dedicated Server"

ARG DEBIAN_FRONTEND=noninteractive

ENV TZ=UTC \
    PUID=1000 \
    PGID=1000 \
    SKIP_UPDATE=0 \
    ENABLE_LOG=1 \
    GAME_PORT=7777

COPY start.sh /start.sh
ADD --chmod=755 https://dl.winehq.org/wine-builds/winehq.key /etc/apt/keyrings/winehq-archive.key
ADD https://dl.winehq.org/wine-builds/debian/dists/trixie/winehq-trixie.sources /etc/apt/sources.list.d/winehq-trixie.sources
RUN set -eux && mkdir -p /starrupture/server /starrupture/data && chmod +x /start.sh && groupadd -g 1000 steam || true && useradd -u 1000 -g 1000 -ms /bin/bash steam || true && \
    apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends ca-certificates gosu tzdata xdg-user-dirs procps winehq-stable xvfb winbind && \
    apt-get clean -y && apt-get autopurge -y && \
    rm -rf /var/lib/apt/lists/*

VOLUME ["/starrupture/server", "/starrupture/data"]

EXPOSE 7777/udp
EXPOSE 7777/tcp

ENTRYPOINT [ "/start.sh" ]
