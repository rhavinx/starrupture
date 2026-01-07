# StarRupture Dedicated Server

## Info

This container is a dedicated server for the [StarRupture](https://starrupture-game.com/) game.
- Run the container and once it is up, in the game menu go to MANAGE SERVER enter your public (WAN) IP and set a password.
- Click on NEW GAME, and give it a name (It does not seem to like spaces in the "Session Name").
- Then click START GAME. (Sometimes, altho it seems a bit inconsistent, after a minute it may pop up a message saying the game is running.)
- If your container has restarted for whatever reason, you will have to go into the MANAGE SERVER again, and click LOAD GAME to get it running again.
- Once you are done in the MANAGE SERVER, hit ESC to get back to the game menu, and then click JOIN GAME.
- Enter your public (WAN) IP and enter the password you set in the SERVER MANAGER.

## Docker Compose (docker-compose.yml)

```yml
services:
  starrupture:
    image: rhavinx/starrupture:latest
    container_name: starrupture
    environment:
      TZ: "Country/City"
      PUID: "1000"
      PGID: "1000"
      SKIP_UPDATE: "0" # Updates are ON by default; set to "1" only if you want to skip
      ENABLE_LOG: "1"
      GAME_PORT: "7777"
    volumes:
      - /path/to/server:/starrupture/server
      - /path/to/data:/starrupture/data
      - /path/to/data:/starrupture/server/StarRupture/Saved
    ports:
      - "7777:7777/udp"
      - "7777:7777/tcp"
    restart: unless-stopped
```

## Directory Structure

```
.
├── data
│   ├── Config
│   ├── Logs
│   └── SaveGames <--- Your Saves will go here.
└── server
    ├── Engine
    ├── StarRupture
    └── steamapps
```
