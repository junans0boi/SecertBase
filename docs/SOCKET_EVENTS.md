# Socket Event Contract (v0)

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
