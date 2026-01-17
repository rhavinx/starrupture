# Source: https://github.com/CM2Walki/steamcmd/blob/master/bookworm/Dockerfile
# Updating for Trixie and customising for StarRupture Dedicated Server

FROM debian:trixie-slim AS build_stage

ARG DEBIAN_FRONTEND=noninteractive
ENV PUID=1000
ENV GUID=1000
ENV USER=steam
ENV HOMEDIR="/home/${USER}"
ENV STEAMCMDDIR="${HOMEDIR}/steamcmd"

RUN set -x \
	# Install, update & upgrade packages
	&& apt-get update \
    && apt-get upgrade -y \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
		lib32stdc++6 \
		lib32gcc-s1 \
		ca-certificates \
	    curl \
		locales \
        gosu \
        tzdata \
        procps \
        gpg \
	&& sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
	&& dpkg-reconfigure -f noninteractive locales \
    # Create group
    && groupadd -g "${GUID}" "${USER}" \
	# Create unprivileged user
	&& useradd -u "${PUID}" -g "${GUID}" -m "${USER}" \
	# Download SteamCMD, execute as user
	&& su "${USER}" -c \
		"mkdir -p \"${STEAMCMDDIR}\" \
                && curl -fsSL 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' | tar xvzf - -C \"${STEAMCMDDIR}\" \
                && \"./${STEAMCMDDIR}/steamcmd.sh\" +quit \
                && ln -s \"${STEAMCMDDIR}/linux32/steamclient.so\" \"${STEAMCMDDIR}/steamservice.so\" \
                && mkdir -p \"${HOMEDIR}/.steam/sdk32\" \
                && ln -s \"${STEAMCMDDIR}/linux32/steamclient.so\" \"${HOMEDIR}/.steam/sdk32/steamclient.so\" \
                && ln -s \"${STEAMCMDDIR}/linux32/steamcmd\" \"${STEAMCMDDIR}/linux32/steam\" \
                && mkdir -p \"${HOMEDIR}/.steam/sdk64\" \
                && ln -s \"${STEAMCMDDIR}/linux64/steamclient.so\" \"${HOMEDIR}/.steam/sdk64/steamclient.so\" \
                && ln -s \"${STEAMCMDDIR}/linux64/steamcmd\" \"${STEAMCMDDIR}/linux64/steam\" \
                && ln -s \"${STEAMCMDDIR}/steamcmd.sh\" \"${STEAMCMDDIR}/steam.sh\"" \
	# Symlink steamclient.so; So misconfigured dedicated servers can find it
 	&& ln -s "${STEAMCMDDIR}/linux64/steamclient.so" "/usr/lib/x86_64-linux-gnu/steamclient.so" \
    && apt-get clean -y && apt-get autopurge -y && rm -rf /var/lib/apt/lists/*

FROM build_stage AS trixie-root
WORKDIR ${STEAMCMDDIR}

# Intermediate for winehq repo key
FROM trixie-root AS winehqkey
WORKDIR /tmp
ADD --chmod=755 https://dl.winehq.org/wine-builds/winehq.key /tmp/winehq.key
RUN gpg --dearmor -o /winehq-archive.key /tmp/winehq.key

# Intermediate for Wine installation
FROM trixie-root AS trixie-wine
# Copy the key from the winehq stage
COPY --from=winehqkey /winehq-archive.key /etc/apt/keyrings/winehq-archive.key
ADD https://dl.winehq.org/wine-builds/debian/dists/trixie/winehq-trixie.sources /etc/apt/sources.list.d/winehq-trixie.sources
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends \
    xdg-user-dirs \
    winehq-stable \
    xvfb \
    winbind \
    && apt-get clean -y && apt-get autopurge -y && rm -rf /var/lib/apt/lists/*

# Actual Image - rebuilds are faster as wine is cached
FROM trixie-wine AS main

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
EXPOSE 7777/tcp

ENTRYPOINT [ "/start.sh" ]