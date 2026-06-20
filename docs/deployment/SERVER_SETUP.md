# Server Deployment Documentation - SecertBase

This document outlines the current server configuration and deployment steps for the SecertBase project.

## Infrastructure
- **Operating System:** Ubuntu 24.04 LTS
- **Database:** MariaDB (Database: `secretbase`, User: `junzzang`)
- **Cache/Store:** Redis (Local instance)
- **Web Server:** Nginx (Reverse Proxy)
- **Process Manager:** PM2

## Backend (realtime-server)
- **Path:** `/home/junzzang/SecertBase/services/realtime-server`
- **Environment:** Node.js
- **Env File:** `/home/junzzang/SecertBase/services/realtime-server/.env` (not committed)
- **Google Login:** requires `GOOGLE_CLIENT_ID` in `.env` and deploy-time `GOOGLE_CLIENT_ID`
- **Service Name:** `secretbase-realtime` (PM2)
- **Port:** 4100
- **URL:** `https://secertbase.kro.kr/socket.io/`

## API Endpoints (New)
- **POST `/api/auth/register`:** User registration with auto-generated `UserCode`.
- **POST `/api/auth/login`:** JWT-based authentication.
- **POST `/api/user/partner`:** Link two users using `UserCode`.
- **GET `/api/user/profile/:userId`:** Fetch user profile and partner info.

## Frontend (secret_base_app)
- **Path:** `/var/www/secretbase` (Static build from `SecertBase/apps/secret_base_app/build/web`)
- **Technology:** Flutter Web
- **Injected URL:** `SOCKET_URL=https://secertbase.kro.kr`

## Nginx Configuration
- **Config Path:** `/etc/nginx/sites-available/secretbase`
- **Template:** `docs/deployment/nginx-secretbase-https.conf`
- **Domain:** `secertbase.kro.kr`
- **Port:** 80 -> 443 redirect, 443 HTTPS
- **Proxying:**
  - `/` -> Served from `/var/www/secretbase`
  - `/socket.io/` -> Proxied to `http://localhost:4100`
  - `/api/` -> Proxied to `http://localhost:4100/api/`
  - `/health` -> Proxied to `http://localhost:4100/health`

## Deployment Commands

Preferred deployment command:

```bash
cd /home/junzzang/SecertBase
./scripts/deploy_server.sh
```

Manual equivalent:

```bash
cd /home/junzzang/SecertBase/apps/secret_base_app
flutter build web --release --no-wasm-dry-run \
  --dart-define=SOCKET_URL=https://secertbase.kro.kr \
  --dart-define=GOOGLE_CLIENT_ID=<google-web-client-id>
sudo rsync -a --delete build/web/ /var/www/secretbase/

sudo cp /home/junzzang/SecertBase/docs/deployment/nginx-secretbase-https.conf /etc/nginx/sites-available/secretbase
sudo ln -sf /etc/nginx/sites-available/secretbase /etc/nginx/sites-enabled/secretbase
sudo nginx -t
sudo systemctl reload nginx

cd /home/junzzang/SecertBase/services/realtime-server
pm2 restart secretbase-realtime --update-env
```

HTTPS is enabled with Let's Encrypt. Port 80 should redirect to `https://secertbase.kro.kr` while keeping `/.well-known/acme-challenge/` available for renewal.

## Firewall (UFW)
- Public access required: 80, 443
- SSH from outside should use Tailscale where possible.
- Current Tailscale server IP: `100.82.126.57`

## SSH / Terminal Access

Preferred external SSH:

```bash
ssh -t junzzang@100.82.126.57 'cd ~/SecertBase && exec bash -l'
```

DB/Redis tunnel for local development:

```bash
ssh -L 3307:127.0.0.1:3306 -L 6380:127.0.0.1:6379 junzzang@100.82.126.57
```

Public domain SSH requires router/NAT port forwarding for TCP 22. As of the latest check, public `124.58.75.93:22` was not reachable, while Tailscale SSH was reachable.

## Current Notes

- HTTPS is active with Let's Encrypt.
- nginx serves the Flutter build from `/var/www/secretbase`.
- PM2 owns the backend process `secretbase-realtime`.
- The server currently keeps local-only reference folders such as `trash/` and `uno/` untracked.
