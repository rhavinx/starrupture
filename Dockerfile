FROM teejo75/steamcmd-wine

LABEL org.opencontainers.image.authors="RhavinX"
LABEL org.opencontainers.image.source="https://github.com/RhavinX/starrupture"
LABEL org.opencontainers.image.description="StarRupture Dedicated Server"

ENV SERVERHOME="${HOMEDIR}/starrupture/server"
ENV GAMEDATA="${HOMEDIR}/starrupture/data"
ENV BACKUP="${GAMEDATA}/backup"

COPY start.sh /start.sh
COPY DSSettings.txt /DSSettings.txt

RUN mkdir -p ${SERVERHOME} ${GAMEDATA} ${BACKUP} && chmod +x /start.sh && \
    chown -R steam:steam ${SERVERHOME} && \
    chown -R steam:steam ${GAMEDATA} && \
    apt-get update && apt-get install -y --no-install-recommends jq \
    && apt-get clean -y && apt-get autopurge -y && \
    rm -rf /var/lib/apt/lists/*

VOLUME [${SERVERHOME}, ${GAMEDATA}]

EXPOSE 7777/udp

ENTRYPOINT [ "/start.sh" ]