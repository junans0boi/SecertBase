# Secret Base Retention Feature Plan

Last updated: 2026-06-21

## Goal

Secret Base should become a private space that couples naturally revisit every day.

The product decision rule is:

```text
Will this feature make at least one partner open the app again tomorrow?
```

If the answer is weak, the feature should be delayed even if it is fun or easy to build.

## Product Direction

Current Secret Base has many useful surfaces:

- realtime games
- archive features
- daily Q&A
- D-day and anniversary
- couple room and partner pairing

The missing layer is a retention loop that connects these surfaces into repeated behavior.

The target product identity is:

```text
A daily private couple ritual, not just a bundle of couple utilities.
```

## Core Retention Loop

The daily loop should be simple:

1. App sends a reason to return.
2. One partner opens the app.
3. The app shows today's shared activity.
4. The other partner gets pulled in.
5. Both complete or react.
6. The result becomes part of the couple history.
7. Streak, report, or reward makes tomorrow feel worth returning.

## Phase 1: Daily Return Loop

Phase 1 is the launch-critical set. These features create the habit.

### 1. Today Hub

Home should become a daily checklist, not just a dashboard.

Home card examples:

- Today's question
- Today's mission
- Couple streak
- Partner activity status
- Pending reward or wish ticket
- Upcoming anniversary

State examples:

```text
오늘의 질문: 내가 답변 완료 / 상대 답변 대기
오늘의 미션: 둘 다 미완료
우리 스트릭: 7일째
```

Primary screen behavior:

- Show one clear primary action.
- Avoid burying the daily action inside Archive.
- If partner has completed an action, show it as a reason to respond.

### 2. Daily Question Upgrade

The current Q&A feature should become one of the main daily rituals.

Required behavior:

- One question per couple per day.
- Each partner answers independently.
- A partner's answer is hidden until both have answered.
- If only one partner answered, the other receives a prompt.
- Past answers become part of the archive.

Question categories:

- light daily mood
- relationship memory
- future planning
- playful confession
- deep talk
- game-like either/or

Important product detail:

```text
The reveal moment matters more than the input form.
```

### 3. Couple Streak

Streak should be couple-based, not individual.

Definition:

```text
A streak day counts only when both partners complete at least one daily ritual.
```

Possible qualifying actions:

- answer today's question
- complete today's mission
- send a daily reaction
- play a game with a result

Data should track:

- current streak
- longest streak
- last completed date
- daily completion by each partner

UX:

- Show current streak on Home.
- Show "almost lost today" state before midnight.
- Avoid harsh punishment. Let users recover with limited restore tickets later.

### 4. Daily Mission

Missions should push couples into small real-world interaction.

Examples:

- Send one compliment.
- Take one photo today.
- Pick tomorrow's snack.
- Ask one question you normally avoid.
- Play one quick game.
- Leave a 10-second voice note.

Mission types:

- text response
- photo upload
- reaction only
- game result
- offline action confirmation

Completion modes:

- both must confirm
- one partner completes for both
- game result completes automatically

### 5. Push Notifications

Without push notifications, the daily loop will be weak.

Required push events:

- partner answered today's question
- partner completed today's mission
- daily question is available
- streak is at risk
- anniversary is near
- time capsule opened
- wish ticket received

Notification style:

```text
상대가 오늘의 질문에 답했어요.
오늘 스트릭이 아직 안 채워졌어요.
새 타임캡슐이 열렸어요.
```

Avoid noisy generic reminders. Notifications should usually reference partner action or deadline.

## Phase 2: Emotional Lock-In

Phase 2 makes users reluctant to delete the app because their history lives inside it.

### 1. Time Capsules

Existing capsule work should be promoted as a core emotional feature.

Required behavior:

- create text/photo/voice capsule
- choose open date
- notify both partners on open day
- show opened capsule in history

Strong variants:

- "30 days later"
- "next anniversary"
- "after our next fight"
- "when we reach 100-day streak"

### 2. Couple History

Create a timeline that automatically records meaningful events.

Event examples:

- partner linked
- first question answered
- first mission completed
- first game played
- first UNO win
- anniversary changed
- time capsule opened
- streak milestone reached

The history should require little manual work.

### 3. On This Day

Revisit old memories.

Examples:

- "1 month ago today"
- "100 days ago today"
- "last anniversary"
- "your first answer"

This creates a reason to open the app even when no new content exists.

### 4. Monthly Couple Report

Generate a shareable and private recap.

Report fields:

- questions answered
- missions completed
- longest streak
- most played game
- UNO wins/losses
- favorite reaction
- most active day
- memorable archive entries

Output:

- in-app report page
- optional share image

## Phase 3: Fun, Rewards, and Virality

Phase 3 makes the app more playful and shareable.

### 1. Wish Tickets

Wish tickets convert in-app actions into real-world couple behavior.

Ticket sources:

- game loser owes winner
- streak milestone
- mission reward
- anniversary event
- random weekly reward

Ticket fields:

- title
- description
- issuer
- owner
- status: available, requested, used, expired, canceled
- created date
- used date

Examples:

- massage ticket
- snack pickup ticket
- date course choice
- one apology pass
- movie choice

### 2. Game Punishments

Games need consequences outside the game.

Examples:

- UNO loser receives a random punishment.
- Pirate loser owes a wish ticket.
- Bomb loser must answer a private question.
- RPS loser gives one compliment.

Implementation principle:

```text
Do not build complex punishment rules first. Start with result -> selectable reward/punishment.
```

### 3. Couple Balance Game

Daily lightweight choice game.

Behavior:

- Both choose one of two options.
- Reveal match/mismatch.
- Store match rate.
- Feed monthly report.

This should be a fast daily action, not a full game lobby.

### 4. Share Images

Viral growth should use images, not long text.

Shareable formats:

- monthly report card
- couple match rate
- UNO loser card
- streak milestone
- anniversary card

Privacy rule:

```text
Never include private answers by default.
```

## Data Model Plan

The retention layer should use shared primitives instead of one-off tables for every feature.

### `daily_engagement_days`

One row per couple per day.

Fields:

```text
id
couple_id
date
question_id
mission_id
streak_count_after
completed_at
created_at
updated_at
```

Purpose:

- powers Home Today Hub
- anchors daily reports
- prevents scattered date logic

### `daily_engagement_actions`

One row per user action.

Fields:

```text
id
couple_id
user_id
date
action_type
target_id
payload_json
created_at
```

Action types:

```text
question_answered
mission_completed
reaction_sent
game_completed
wish_ticket_used
capsule_opened
```

Purpose:

- streak calculation
- timeline generation
- monthly report input

### `daily_missions`

Mission catalog.

Fields:

```text
id
title
description
mission_type
requirement_type
active
created_at
```

### `couple_mission_instances`

Mission assigned to a couple on a date.

Fields:

```text
id
couple_id
mission_id
date
status
completed_by_user1
completed_by_user2
completed_at
payload_json
```

### `couple_streaks`

Current streak state.

Fields:

```text
couple_id
current_count
longest_count
last_completed_date
last_grace_used_date
updated_at
```

### `notification_tokens`

Push token storage.

Fields:

```text
id
user_id
platform
token
device_label
enabled
last_seen_at
created_at
updated_at
```

### `notification_events`

Audit and retry queue for push notifications.

Fields:

```text
id
user_id
couple_id
event_type
title
body
payload_json
status
sent_at
created_at
```

### `wish_tickets`

Reward and punishment item.

Fields:

```text
id
couple_id
owner_user_id
issuer_user_id
source_type
source_id
title
description
status
created_at
used_at
expires_at
```

### `couple_timeline_events`

Persistent history feed.

Fields:

```text
id
couple_id
event_type
actor_user_id
target_user_id
title
body
payload_json
event_date
created_at
```

## API Plan

### Today Hub

```text
GET /api/today?user_id=1
```

Returns:

```json
{
  "ok": true,
  "date": "2026-06-21",
  "streak": {
    "current": 7,
    "longest": 12,
    "completedToday": false
  },
  "question": {
    "id": 10,
    "text": "오늘 상대에게 고마웠던 순간은?",
    "myAnswered": true,
    "partnerAnswered": false,
    "revealAvailable": false
  },
  "mission": {
    "id": 3,
    "title": "칭찬 하나 남기기",
    "myCompleted": false,
    "partnerCompleted": true
  },
  "pending": {
    "wishTickets": 1,
    "capsulesToOpen": 0
  }
}
```

### Questions

Existing endpoints can be extended:

```text
GET /api/qa/today?user_id=1
POST /api/qa/answer
```

Needed changes:

- scope questions by couple/date
- hide answers until both users answered
- emit notification when one partner answers
- write `daily_engagement_actions`

### Missions

```text
GET /api/missions/today?user_id=1
POST /api/missions/:instanceId/complete
```

### Streak

```text
GET /api/streak?user_id=1
POST /api/streak/recalculate
```

The recalculate endpoint should initially be internal/admin only.

### Push

```text
POST /api/push/token
DELETE /api/push/token
```

### Wish Tickets

```text
GET /api/wish-tickets?user_id=1
POST /api/wish-tickets
PATCH /api/wish-tickets/:id/use
PATCH /api/wish-tickets/:id/cancel
```

### Timeline

```text
GET /api/timeline?user_id=1
```

### Reports

```text
GET /api/reports/monthly?user_id=1&month=2026-06
```

## Socket Event Plan

Socket should be used for realtime partner pull-in.

Events:

```text
daily:updated
question:answered
mission:completed
streak:updated
wish_ticket:created
reaction:sent
```

Example:

```json
{
  "date": "2026-06-21",
  "actorUserId": 1,
  "actionType": "question_answered"
}
```

## Frontend Plan

### Home

Home should become the main retention surface.

Sections:

1. Couple summary
2. Today Hub
3. Current streak
4. Pending partner action
5. Quick game or reaction
6. Recent timeline

Priority:

- One primary CTA at a time.
- Avoid showing too many equal cards.
- Make partner status visible.

### Archive

Archive should hold completed memories:

- past questions
- past missions
- timeline
- reports
- capsules
- maps and posts

### Settings

Settings should own configuration:

- profile
- password
- social login status
- anniversary
- notification settings

Settings should not be required for daily engagement.

### Games

Games should feed engagement:

- game result creates timeline event
- game result can create wish ticket
- game result can complete daily mission
- monthly report includes game stats

## Push Notification Plan

### FCM Setup

Likely needed:

- Firebase project only for Cloud Messaging
- Android app registration
- web push certificate/VAPID key
- Flutter Firebase Messaging dependency
- backend service account or HTTP v1 sender

### Token Flow

1. App requests notification permission after login/partner pairing.
2. App receives FCM token.
3. App sends token to backend.
4. Backend stores token by user/device.
5. Backend sends event-triggered notifications.

### Notification Events

High priority:

- partner answered question
- partner completed mission
- streak at risk
- capsule opened

Medium priority:

- daily question available
- daily mission available
- anniversary reminder

Low priority:

- monthly report ready
- game rematch prompt

## Implementation Order

### Milestone 1: Today Hub Foundation

1. Add retention tables.
2. Add `GET /api/today`.
3. Refactor Home to show Today Hub.
4. Connect existing Q&A state to Today Hub.
5. Write daily engagement action when question is answered.

Exit criteria:

- A paired couple sees today's question and completion state on Home.
- Answering a question updates Home without visiting Archive.

### Milestone 2: Couple Streak

1. Add streak calculation.
2. Count a day when both partners complete a qualifying action.
3. Show current streak on Home.
4. Add timeline event on streak milestones.

Exit criteria:

- Streak increments only when both partners participate.
- Home clearly shows whether today's streak is complete.

### Milestone 3: Daily Mission

1. Add mission catalog.
2. Auto-assign one mission per couple/day.
3. Add mission completion endpoint.
4. Show mission in Today Hub.
5. Write engagement action and timeline event.

Exit criteria:

- Every day has one mission.
- Each partner sees their completion state.

### Milestone 4: Push Notifications

1. Add FCM setup.
2. Store device tokens.
3. Send push when partner answers question.
4. Send push when partner completes mission.
5. Add notification settings.

Exit criteria:

- Partner action pulls the other partner back into the app.

### Milestone 5: Wish Tickets and Game Rewards

1. Add `wish_tickets`.
2. Add manual ticket creation.
3. Add game result integration.
4. Show pending tickets on Home.

Exit criteria:

- A game result can create a real-world reward or punishment.

### Milestone 6: Timeline and Monthly Report

1. Add timeline event writer.
2. Backfill from engagement actions where possible.
3. Add monthly report endpoint.
4. Add report screen.
5. Add share image later.

Exit criteria:

- Users can see what happened this month without manual journaling.

## MVP Scope Recommendation

For a first public-ish release, ship only:

- Today Hub
- daily question reveal flow
- couple streak
- daily mission
- basic push notifications

Delay:

- monthly report
- share image
- complex wish ticket rules
- advanced timeline filters
- streak restore tickets

## Risk Notes

### Too Many Features

The app can become noisy if every feature competes for attention.

Mitigation:

- Home shows one primary action.
- Archive stores history.
- Settings stores configuration.
- Games stay optional but feed rewards/history.

### Push Fatigue

Bad notifications will make users disable push.

Mitigation:

- Mostly notify partner actions.
- Avoid repeated generic reminders.
- Add quiet hours later.

### Data Fragmentation

Existing features have separate tables.

Mitigation:

- Add `daily_engagement_actions` as the shared analytics/event layer.
- Do not rewrite all archive tables at once.
- New features should write to the shared layer from day one.

### Privacy

Couple data is sensitive.

Mitigation:

- Share images exclude private text by default.
- Reports should be private unless explicitly exported.
- Push body should avoid sensitive answer contents.

## Immediate Next Step

Start with Milestone 1.

Concrete first implementation task:

```text
Build /api/today and refactor Home into a Today Hub that surfaces today's Q&A state.
```

This gives the app a central daily reason to open before adding more systems.
