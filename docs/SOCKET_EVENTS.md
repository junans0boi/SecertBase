# Socket Event Contract

Last updated: 2026-06-20

Socket.IO endpoint:

```text
Production: https://secertbase.kro.kr/socket.io/
Local:      http://localhost:4100/socket.io/
```

All realtime game events require a successful `session:join` first.

## Common Client -> Server

### `session:join`

Joins the couple room. `roomCode`, `roomSecret`, and `userId` normally come from `/api/user/profile/:userId`.

```json
{
  "userId": "USERCODE",
  "roomCode": "room_1_2",
  "roomSecret": "secret",
  "profileEmoji": "🙂"
}
```

Ack:

```json
{ "ok": true, "state": {} }
```

Common failure reasons:

```text
invalid_payload
invalid_room
room_full
user_not_allowed
```

### `session:restore`

Restores active yut/uno/bomb state if present in Redis.

```json
{}
```

### `sync:ping`

```json
{ "clientTs": 1781760000000 }
```

Ack includes server timestamp.

### `profile:update`

```json
{ "profileEmoji": "🐰" }
```

### `heart:send`

Sends a lightweight heart animation to the partner.

```json
{}
```

## Common Server -> Client

### `room:presence`

```json
{
  "roomCode": "room_1_2",
  "users": ["ABC123", "XYZ789"],
  "profileEmojis": {
    "ABC123": "🙂",
    "XYZ789": "🐰"
  }
}
```

### `heart:received`

```json
{ "from": "ABC123" }
```

## Game Lobby

Supported `gameType` values:

```text
dice
roulette
rps
telepathy
pirate
yut
uno
uno_classic
uno_go_wild
bomb
```

`uno_classic` and `uno_go_wild` are lobby-level types. The actual UNO game state uses mode `classic` or `go_wild`.

### `game:lobby:join`

```json
{ "gameType": "uno_go_wild" }
```

### `game:lobby:leave`

```json
{ "gameType": "uno_go_wild" }
```

### `game:lobby:select_character`

Only for yut lobby.

```json
{
  "gameType": "yut",
  "character": "honggilldong"
}
```

Characters:

```text
honggilldong
nolbu
miho
```

### `game:lobby:start`

Host starts the lobby game. Requires 2 players.

```json
{ "gameType": "uno_go_wild" }
```

### `game:lobby:updated`

```json
{
  "gameType": "yut",
  "host": "ABC123",
  "players": ["ABC123", "XYZ789"],
  "profileEmojis": {},
  "characters": {
    "ABC123": "honggilldong",
    "XYZ789": "miho"
  },
  "updatedAt": 1781760000000
}
```

### `game:lobby:started`

```json
{
  "gameType": "uno_go_wild",
  "host": "ABC123",
  "players": ["ABC123", "XYZ789"],
  "profileEmojis": {},
  "at": 1781760000000
}
```

## Lightweight Games

### Dice

Client:

```json
{}
```

Event:

```text
game:dice:roll -> game:dice:result
```

Result:

```json
{
  "value": 4,
  "by": "ABC123",
  "at": 1781760000000
}
```

### Roulette

Client:

```json
{
  "options": ["야식", "벌칙", "결제자"]
}
```

Event:

```text
game:roulette:spin -> game:roulette:result
```

### Rock Paper Scissors

Client:

```json
{ "choice": "rock" }
```

Choices:

```text
rock
paper
scissors
```

When both players choose, server emits `game:rps:result`.

### Telepathy

Client:

```json
{
  "choice": "치킨",
  "options": ["치킨", "피자", "족발"]
}
```

When both players choose, server emits `game:telepathy:result`.

### Pirate

Client:

```json
{ "slots": 8 }
```

`slots` must be 4-12.

Server emits `game:pirate:result`.

## Yut

### `game:yut:new`

Starts yut game. Requires 2 players.

```json
{
  "characters": {
    "ABC123": "honggilldong",
    "XYZ789": "miho"
  },
  "bgm": "yut1.mp3"
}
```

`bgm` can be `yut1.mp3`, `yut2.mp3`, `yut3.mp3`, or null.

Server emits `game:yut:started`.

### `game:yut:roll_start`

Used during the roll-order phase.

```json
{}
```

Server emits `game:yut:start_roll`.

### `game:yut:throw`

Throws 윷 during the active game.

```json
{}
```

Server emits `game:yut:throw_result`.

### `game:yut:move`

```json
{
  "pieceId": 0,
  "moveIndex": 0
}
```

Server emits:

```text
game:yut:move_result
game:yut:ended
```

Yut state payloads include:

```json
{
  "id": "yut-1781760000000",
  "players": ["ABC123", "XYZ789"],
  "phase": "roll_order",
  "currentTurn": "ABC123",
  "characters": {},
  "bgm": "yut1.mp3",
  "startRolls": {},
  "orderCountdownUntil": null,
  "pendingMoves": [],
  "lastThrow": null,
  "winner": null,
  "pieces": {
    "ABC123": [],
    "XYZ789": []
  }
}
```

## UNO

### Modes

```text
classic
go_wild
```

Rules by mode:

- classic: no `discard_all`, no draw-stack defense
- go_wild: includes `discard_all`, allows +2/+4 cross stack defense

### `game:uno:new`

```json
{ "mode": "go_wild" }
```

Server emits `game:uno:started` to the room and `game:uno:hand_update` privately to each player.

### `game:uno:play`

```json
{
  "cardId": "red-5-a",
  "declaredColor": "blue"
}
```

`declaredColor` is required by the client for wild cards and optional otherwise.

Server emits:

```text
game:uno:played
game:uno:hand_update
game:uno:ended
```

### `game:uno:draw`

Draws 1 card, or accepts the pending draw stack.

```json
{}
```

Server emits `game:uno:drawn` and private `game:uno:hand_update`.

### `game:uno:call`

Used by the player who has one card and needs to declare UNO.

```json
{}
```

Server emits `game:uno:called`.

### `game:uno:catch`

Used by the opponent while `unoCallNeeded` points to the target player. The target draws 2.

```json
{}
```

Server emits `game:uno:penalty`.

### `game:uno:challenge`

Challenges a pending wild +4. Only valid when `drawStackType` is `wild_draw4` and it is the challenger's turn.

```json
{}
```

Server emits `game:uno:challenged`.

### `game:uno:reaction`

Gift reaction. Requires an active UNO game.

```json
{ "type": "cake" }
```

Types:

```text
cake
candy
coffee
flyby
pillow
pizza
sportscar
tomato
```

Server emits:

```json
{
  "by": "ABC123",
  "type": "cake",
  "at": 1781760000000
}
```

### UNO Room Events

`game:uno:started`:

```json
{
  "topCard": { "color": "red", "value": "5", "id": "red-5-a" },
  "currentPlayer": "ABC123",
  "mode": "go_wild",
  "declaredColor": null,
  "drawStack": 0,
  "drawStackType": null,
  "handCount": {
    "ABC123": 7,
    "XYZ789": 7
  }
}
```

`game:uno:played` includes:

```json
{
  "by": "ABC123",
  "card": {},
  "cards": [],
  "count": 1,
  "mode": "go_wild",
  "declaredColor": null,
  "nextPlayer": "XYZ789",
  "drawStack": 0,
  "drawStackType": null,
  "handCount": {},
  "winner": null,
  "unoCallNeeded": null,
  "at": 1781760000000
}
```

## Bomb

### `game:bomb:new`

```json
{ "duration": 30 }
```

Duration must be 10-120 seconds.

Server emits `game:bomb:started`:

```json
{
  "currentPlayer": "ABC123",
  "duration": 30,
  "startTime": 1781760000000,
  "quiz": {
    "category": "general",
    "question": "..."
  }
}
```

### `game:bomb:answer`

```json
{ "answer": "정답" }
```

Server emits:

```text
game:bomb:passed
game:bomb:wrong_answer
game:bomb:exploded
```

## Restart

### `game:restart:request`

```json
{}
```

Server emits `game:restart:requested` to the partner.

### `game:restart:respond`

```json
{
  "accept": true,
  "gameType": "uno"
}
```

Supported restart game types:

```text
yut
uno
bomb
```

Server emits one of:

```text
game:restart:declined
game:yut:started
game:uno:started
game:bomb:started
```
