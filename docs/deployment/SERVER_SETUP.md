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
- **Service Name:** `secretbase-realtime` (PM2)
- **Port:** 4100
- **URL:** `http://SecertBase.kro.kr/socket.io/`

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

## HTTP Deployment Commands

Preferred deployment command:

```bash
cd /home/junzzang/SecertBase
./scripts/deploy_server.sh
```

Manual equivalent:

```bash
cd /home/junzzang/SecertBase/apps/secret_base_app
flutter build web --release --no-wasm-dry-run --dart-define=SOCKET_URL=https://secertbase.kro.kr
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
- **Allowed:** `Nginx Full` (80, 443), `OpenSSH`, `3389` (RDP), etc.

## Known Limitations
- **SSL:** Attempted but failed due to Let's Encrypt rate limits for `kro.kr`. Currently running on HTTP only.
- **Port Forwarding:** External access requires port 80 to be forwarded to this server's local IP.
