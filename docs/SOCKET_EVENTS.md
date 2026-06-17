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
  "users": ["jun", "gf"]
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
