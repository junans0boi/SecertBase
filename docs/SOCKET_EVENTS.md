# Socket Event Contract

Last updated: 2026-07-15

Socket.IO endpoint:

```text
Production: https://secretbase.cloud/socket.io/
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
game:lobby:set_stake  { gameType, stake }        (host only, stake games only)
game:lobby:ready      { gameType, ready: bool }  (non-host consent for staked games)
game:lobby:set_option { gameType, key, value }    (host only, allowed values only)
game:lobby:start
game:lobby:updated    (includes `stake`, `options`, `ready: { [userCode]: true }`)
game:lobby:started    (metadata: { stake, gameId, options, yutBgm? })
```

**Stakes are server-authoritative (2026-11, #183).** Only `yut`, `uno*`, `tank`
and `gostop` settle stakes. When the stake is above 0, every non-host player must
send `game:lobby:ready { ready: true }` before the host can start
(`partner_not_ready` otherwise); changing the stake resets readiness.
`game:lobby:start` stores a pending game (`pending:{room}:{type}`, 120 s) with the
agreed stake and a `gameId`. The creation events (`game:yut:new`, `game:uno:new`,
`game:tank:new`, `game:gostop:new`) ignore any stake in their payload and consume
the pending game; without one the game is free. Settlement uses `<type>:<gameId>`
as the idempotency reference and runs before the Redis state is deleted.

**Lobby options (2026-11, games 2.0).** Per-game settings the host picks in the
lobby and the partner sees live. Allowed values live in `src/lobby-options.js`
(client mirror: `lib/screens/arcade/lobby_options.dart`): `penalty.cells` 3|6
(default 3), `pirate.holes` 6|8|12 (default 8), `uno.mode` go_wild|classic
(default go_wild). `game:lobby:set_option` answers `not_host`, `invalid_option`
or `lobby_not_found`, and a changed value resets readiness like a stake change.
The options are saved with the pending game; creation handlers read them from
`consumePendingGame(...).options` and ignore payload values (`game:uno:new` uses
the payload mode only for games started outside the lobby).

**Restart (rematch) protocol.** `game:restart:request { gameType }` records the
request for 30 s (`yut`, `uno`, `bomb`, `marble`, `tank`; others →
`unsupported_game`). `game:restart:respond { accept, gameType }` is accepted only
from the other player while that request exists (`no_restart_request` otherwise).

**Rejections.** Every game handler acks `{ ok: false, reason }` on failure and
`{ ok: false, reason: "internal_error" }` if it throws. The app shows the reason
as a short notice.

Only `yut`, `bomb`, and `rps` are accepted lobby game types in the MVP.

**`game:lobby:join` response shape** (as of 2026-08-03):

Normal (waiting for partner):
```json
{ "ok": true, "status": "waiting", "lobby": { "gameType": "yut", "host": "...", "players": [] } }
```

Resume (partner is already inside an active game — `yut` or `uno` only):
```json
{ "ok": true, "status": "resumed", "gameType": "yut", "state": {} }
```
The `state` is the same per-user serialization as `session:restore`. For UNO, `state.hand` contains only the requesting user's cards; the partner's hand is never sent.

**Game session presence events** — track which socket is viewing which game:

```text
game:session:enter  { gameType }   → { ok: true }
game:session:leave  { gameType }   → { ok: true }
```

The server adds the socket to a game-view subroom on `enter` and removes it on `leave` or disconnect. When the last viewer leaves, the active game state is deleted from Redis after a 90 second grace period (re-entering cancels it). `game:lobby:join` checks the subroom before creating a new lobby: if an active game has viewers, the joining socket is added to the subroom and a `resumed` result is returned instead of a lobby object. Unknown (non-public) `gameType` values are rejected by the socket feature gate.

Game events:

```text
game:yut:new / throw / move / state
game:bomb:new / answer / state
game:rps:start / pick / state / cancelled
```

Yut, One Card, Go-Stop, Marble and Bomb state is returned in `session:restore`
`activeGames`. For blackjack, oldmaid, penalty, bowling, tank and catch the server
re-sends the game's normal update event to the restoring socket and lists them in
`restored`. Their `start`/`new` events also resume an unfinished game
(`{ ok: true, resumed: true }`) instead of rejecting with `game_in_progress`.
An RPS round is cancelled (`game:rps:cancelled`, reason `player_disconnected`)
only when a participant has no remaining socket in the room.

### Turn timeout (AFK) for turn-based games

For `yut`, `uno`, `gostop`, `marble`, `blackjack`, `oldmaid`, `bowling`,
`penalty`, `pirate` and `rps` the server watches the player it is waiting for.
After 60 s without a state-changing action it emits
`game:afk:warning { gameType, player, secondsLeft }`; after 90 s it emits
`game:afk:forfeit { gameType, loser, winner }` and ends the game through that
game's normal end event with reason `forfeit` (stakes settle, results are
recorded; RPS is cancelled with reason `afk`). Simultaneous-choice games only
time out when exactly one player has answered. The resumable-game cleanup grace
(150 s) is longer than the AFK limit so an abandoned game is forfeited, not
silently deleted.

### Tank Battle 2.0 (`game:tank:*`)

```text
client → server
  game:tank:new                                  (stake from the lobby only)
  game:tank:select  { tankClass: rhino|falcon|mole|turtle }
  game:tank:move    { delta: -10..10 }
  game:tank:weapon  { weapon }
  game:tank:fire    { angle?, power?, weapon? }  (aim is sent only when firing)
  game:tank:aim     { angle, power }             (legacy; never broadcast)
server → client (per-viewer masked: opponent angle/power hidden, class hidden while selecting)
  game:tank:started / updated   full state
  game:tank:shot                { shooter, weapon, angle, power, events[], paths, impact, blastR, damage }
  game:tank:moved               { by, events[] }          (crate pickups, blocked)
  game:tank:timeout             { player, count, forfeited, events }
  game:tank:ended               { winner|'draw', reason: ko|mutual_ko|afk|time|time_draw, summary, series, state }
```

Phases: `select` → `aiming` → `result`. Turns last 30 s (server timer,
`turnDeadline`); three consecutive timeouts forfeit. Sudden death starts at turn
20 (damage ×1.5), turn 30 decides by HP ratio. `events[]` entries carry `stage`
(cluster bomblets use stage 1) and types `shell`, `blast`, `mound`, `damage`,
`shield`, `crate`, `crate_drop`, `fall`, `teleport`, `split`, `heal`,
`buff_used`, `sudden_death`. Rematches go through the restart protocol and keep
the series score and stake.

If a partner deletes their account (via `DELETE /user`), the remaining partner's socket receives `partner:disconnected` (reason: `partner_deleted_account`) and is disconnected from the room.

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
