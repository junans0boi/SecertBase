# Socket Event Contract (v1)

## Client -> Server

### `session:join`

```json
{
  "userId": "jun | gf",
  "roomCode": "secret-room",
  "roomSecret": "secretbase"
}
```

### `sync:ping`

```json
{
  "clientTs": 1730000000000
}
```

### `profile:update`

설정 탭에서 선택한 프로필 이모지를 현재 접속 세션에 반영한다.

```json
{
  "profileEmoji": "🙂"
}
```

### `game:lobby:join`

아케이드 게임별 대기방에 입장한다. 각 게임 대기방에 가장 먼저 들어온 사용자가 방장이 된다.

```json
{
  "gameType": "dice | roulette | rps | telepathy | pirate | yut | uno | bomb"
}
```

### `game:lobby:leave`

현재 게임 대기방에서 나간다.

```json
{
  "gameType": "dice | roulette | rps | telepathy | pirate | yut | uno | bomb"
}
```

### `game:lobby:start`

방장이 게임 시작을 요청한다. 대기방에 2명이 있어야 성공한다.

```json
{
  "gameType": "dice | roulette | rps | telepathy | pirate | yut | uno | bomb"
}
```

### `game:dice:roll`

```json
{}
```

### `game:roulette:spin`

```json
{
  "options": ["야식", "벌칙", "결제자", "면제권"]
}
```

### `game:rps:select`

```json
{
  "choice": "rock | paper | scissors"
}
```

### `game:telepathy:select`

```json
{
  "choice": "치킨",
  "options": ["치킨", "피자", "족발", "회"]
}
```

### `game:pirate:spin`

```json
{
  "slots": 8
}
```

## Server -> Client

### `room:presence`

```json
{
  "roomCode": "secret-room",
  "users": ["jun", "gf"],
  "profileEmojis": {
    "jun": "🙂",
    "gf": "🐰"
  }
}
```

### `game:lobby:updated`

대기방 입장/퇴장/방장 변경 시 방 전체에 전달된다.

```json
{
  "gameType": "dice",
  "host": "jun",
  "players": ["jun", "gf"],
  "profileEmojis": {
    "jun": "🙂",
    "gf": "🐰"
  },
  "updatedAt": 1781760000000
}
```

### `game:lobby:started`

방장이 시작 버튼을 눌러 대기방이 게임 화면으로 전환될 때 방 전체에 전달된다.

```json
{
  "gameType": "dice",
  "host": "jun",
  "players": ["jun", "gf"],
  "profileEmojis": {
    "jun": "🙂",
    "gf": "🐰"
  },
  "at": 1781760000000
}
```

### `game:dice:result`

```json
{
  "value": 4,
  "by": "jun",
  "at": 1730000000000
}
```

### `game:roulette:result`

```json
{
  "index": 2,
  "selected": "결제자",
  "options": ["야식", "벌칙", "결제자", "면제권"],
  "by": "gf",
  "at": 1730000000000
}
```

### `game:rps:result`

```json
{
  "choices": {
    "jun": "rock",
    "gf": "scissors"
  },
  "winner": "jun | gf | draw",
  "at": 1730000000000
}
```

### `game:telepathy:result`

```json
{
  "choices": {
    "jun": "치킨",
    "gf": "치킨"
  },
  "success": true,
  "selected": "치킨",
  "at": 1730000000000
}
```

### `game:pirate:result`

```json
{
  "slots": 8,
  "bombSlot": 3,
  "by": "jun",
  "at": 1730000000000
}
```

### `session:restore`

재접속 시 활성 게임 세션 복원

**Client → Server:**
```json
{}
```

**Server → Client (Ack):**
```json
{
  "ok": true,
  "activeGames": {
    "yut": {
      "gameId": "yut-1730000000000",
      "turn": "p1",
      "p1Pieces": [0, 0, 0, 0],
      "p2Pieces": [0, 0, 0, 0]
    },
    "uno": {
      "gameId": "uno-1730000000000",
      "turn": "p2",
      "topCard": "Red-5",
      "p1Count": 7,
      "p2Count": 5,
      "hand": ["Blue-3", "Green-7", "Wild"]
    },
    "bomb": {
      "gameId": "bomb-1730000000000",
      "holder": "p1",
      "timer": 25,
      "category": "general"
    }
  }
}
```

**Note:** `activeGames` 객체는 현재 진행 중인 게임만 포함. 게임이 없으면 빈 객체 `{}`
