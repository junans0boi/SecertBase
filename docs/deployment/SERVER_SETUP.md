# Server Deployment Documentation - SecertBase

This document outlines the current server configuration and deployment steps for the SecertBase project.

## Infrastructure
- **Operating System:** Ubuntu 24.04 LTS
- **Database:** MariaDB (Database: `secretbase`, User: `junzzang`)
- **Cache/Store:** Redis (Local instance)
- **Web Server:** Caddy on Server 2, nginx legacy config retained for Server 1 reference
- **Process Manager:** PM2

## Backend (realtime-server)
- **Path:** `/home/ubuntu/SecertBase/services/realtime-server` on Server 2
- **Environment:** Node.js
- **Env File:** `/home/ubuntu/SecertBase/services/realtime-server/.env` on Server 2 (not committed)
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
- **Production/review path:** `/var/www/secretbase` (Static build from `SecertBase/apps/secret_base_app/build/web`)
- **Tester path:** `/var/www/secretbase-test`
- **Technology:** Flutter Web
- **Review injected URL:** `SOCKET_URL=https://secertbase.kro.kr`
- **Tester injected URL:** `SOCKET_URL=https://test.secertbase.kro.kr`

## Nginx Configuration (Server 1 / legacy)
- **Config Path:** `/etc/nginx/sites-available/secretbase`
- **Template:** `docs/deployment/nginx-secretbase-https.conf`
- **Domain:** `secertbase.kro.kr`
- **Port:** 80 -> 443 redirect, 443 HTTPS
- **Proxying:**
  - `/` -> Served from `/var/www/secretbase`
  - `/socket.io/` -> Proxied to `http://localhost:4100`
  - `/api/` -> Proxied to `http://localhost:4100/api/`
  - `/health` -> Proxied to `http://localhost:4100/health`

## Caddy Configuration (Server 2)
- **Config Path:** `/etc/caddy/Caddyfile`
- **Template:** `docs/deployment/Caddyfile`
- **Review domain:** `secertbase.kro.kr`
- **Tester domain:** `test.secertbase.kro.kr`
- **HTTPS:** Handled automatically by Caddy. It provisions and renews Let's Encrypt certificates without manual cert paths.
- **Proxying:**
  - `secertbase.kro.kr/` -> Served from `/var/www/secretbase` with SPA fallback to `index.html`
  - `test.secertbase.kro.kr/` -> Served from `/var/www/secretbase-test` with SPA fallback to `index.html`
  - `/api/*`, `/uploads/*`, `/health`, `/socket.io/*` -> Proxied to `http://127.0.0.1:4100`

Setup on Server 2:

```bash
sudo cp /home/ubuntu/SecertBase/docs/deployment/Caddyfile /etc/caddy/Caddyfile
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

The DNS records for `secertbase.kro.kr` and `test.secertbase.kro.kr` must point at Server 2's public IP, and ports 80/443 must be reachable so Caddy can complete the HTTP-01 challenge.

## Deployment Commands

Preferred deployment command:

```bash
cd /home/ubuntu/SecertBase
./scripts/deploy_server.sh
```

The server currently keeps `apps/secret_base_app/.env` with `KAKAO_REVIEW_AUTO_LOGIN=true` for the Kakao review build. Because `scripts/deploy_server.sh` prefers that `.env` file when it exists, do not use the normal deploy script for the tester build unless the `.env` behavior has been changed.

Tester build command used on 2026-07-12:

```bash
cd /home/ubuntu/SecertBase/apps/secret_base_app
flutter pub get
BUILD_ENV_FILE=$(mktemp)
{
  echo "SOCKET_URL=https://test.secertbase.kro.kr"
  grep -E "^GOOGLE_CLIENT_ID=" .env || true
  echo "KAKAO_REVIEW_AUTO_LOGIN=false"
} > "$BUILD_ENV_FILE"
flutter build web --release --no-wasm-dry-run --dart-define-from-file="$BUILD_ENV_FILE"
rm -f "$BUILD_ENV_FILE"
rsync -a --delete build/web/ /var/www/secretbase-test/
```

Backend CORS must allow both deployed origins:

```text
CORS_ORIGIN=https://secertbase.kro.kr,https://test.secertbase.kro.kr
```

Manual equivalent:

```bash
cd /home/junzzang/SecertBase/apps/secret_base_app
flutter build web --release --no-wasm-dry-run \
  --dart-define=SOCKET_URL=https://secertbase.kro.kr \
  --dart-define=GOOGLE_CLIENT_ID=<google-web-client-id>
sudo rsync -a --delete build/web/ /var/www/secretbase/

sudo cp /home/ubuntu/SecertBase/docs/deployment/nginx-secretbase-https.conf /etc/nginx/sites-available/secretbase
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
- Current Server 2 Tailscale IP: `100.97.58.29`

## SSH / Terminal Access

Preferred external SSH:

```bash
ssh -i /Users/junzzang/Downloads/ssh-key-2026-07-06.key -t ubuntu@100.97.58.29 'cd ~/SecertBase && exec bash -l'
```

DB/Redis tunnel for local development:

```bash
ssh -i /Users/junzzang/Downloads/ssh-key-2026-07-06.key -L 3307:127.0.0.1:3306 -L 6380:127.0.0.1:6379 ubuntu@100.97.58.29
```

Public domain SSH requires router/NAT port forwarding for TCP 22. As of the latest check, public `124.58.75.93:22` was not reachable, while Tailscale SSH was reachable.

## Current Notes

- HTTPS is active with Let's Encrypt.
- Caddy serves the Kakao review Flutter build from `/var/www/secretbase` on Server 2.
- Caddy serves the normal tester Flutter build from `/var/www/secretbase-test` on Server 2.
- PM2 owns the backend process `secretbase-realtime`.
- The server currently keeps local-only reference folders such as `trash/` and `uno/` untracked.
- `secertbase.kro.kr` is reserved for Kakao Developers review until approval. Use `test.secertbase.kro.kr` for friend/tester access.
