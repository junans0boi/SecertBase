# Socket Event Contract

Last updated: 2026-07-15

Socket.IO endpoint:

```text
Production: https://secertbase.kro.kr/socket.io/
Local:      http://localhost:4100/socket.io/
```

## Authentication

The client supplies its app JWT in the Socket.IO handshake:

```json
{ "auth": { "token": "jwt" } }
```

The server derives `userId`, the active Couple, and `roomCode` from that JWT. A
missing, invalid, or expired token fails the handshake with `AUTH_REQUIRED` or
`AUTH_INVALID`. A valid user without an active Couple receives
`ACTIVE_COUPLE_REQUIRED`. Client-provided user IDs, room codes, room secrets,
and the shared `ROOM_SECRET` bypass are not accepted.

After the handshake, emit `session:join` with optional presentation data:

```json
{ "profileEmoji": "🙂" }
```

Ack:

```json
{
  "ok": true,
  "roomCode": "room_1_2",
  "userId": "ABC123",
  "state": {}
}
```

## Public MVP Events

All events below require a successful `session:join`.

Common events:

```text
session:restore
sync:ping
profile:update
room:presence
```

Lobby events:

```text
game:lobby:join
game:lobby:leave
game:lobby:select_character
game:lobby:start
game:lobby:updated
game:lobby:started
```

Only `yut`, `bomb`, and `rps` are accepted lobby game types in the MVP.

Game events:

```text
game:yut:new / throw / move / state
game:bomb:new / answer / state
game:rps:start / pick / state
```

Yut and Bomb state is stored in the Couple's Redis namespace and returned by
`session:restore` after reconnect. An interrupted RPS round is not restored.

## Disabled Events

UNO, dice, roulette, telepathy, pirate, catch, and heart events are rejected
when `PUBLIC_FEATURE_SET=mvp`:

```json
{
  "ok": false,
  "error": { "code": "FEATURE_DISABLED", "feature": "uno" }
}
```

The dormant implementations remain in source but are not part of the public
MVP contract.
