# Retention MVP 2 — Date Afterglow

Status: approved for implementation

## Outcome

Turn a Secret Map wishlist pin into a shared, place-based memory after a real date. Either partner can mark the visit and contribute independently; the other partner never blocks completion.

## User flow

1. On a `wishlist` pin, either active Couple member taps `오늘 다녀왔어요`.
2. The server records one visit for that pin and Business Date and atomically changes the pin to `visited` with that visit date.
3. The app offers the member a lightweight contribution: choose one of their MomentLoop posts from that visit date, add an optional short caption, and choose at most one emotion tag.
4. The partner can add their own contribution later. One contribution is already a valid Afterglow.
5. Place detail displays the visit and both members' contributions together, including a neutral deleted state when a linked MomentLoop is later removed.

## Product rules

- Visit creation is an explicit user action. No GPS/geofence inference.
- Server Business Date (`Asia/Seoul`) is authoritative for `오늘`.
- Only an authenticated member of the pin's active Couple may read or mutate its Afterglow.
- A pin can have one MVP visit. Repeating the visit action is idempotent and returns the same visit.
- Each Couple member can attach at most one MomentLoop to the visit.
- The MomentLoop must be authored by that member, belong to the same active Couple, match the visit date, and be linked to the same map pin.
- Caption is optional and limited to 120 characters. Emotion tag is optional, one value, and limited to 24 characters.
- A contribution never waits for the partner and does not lock future days or other app features.
- MomentLoop media remains the source of truth. Afterglow stores only the link and small reflection metadata; there is no map-specific photo upload.
- Deleting a linked MomentLoop keeps a neutral contribution tombstone. Cross-Couple data, caption, media, and location must never leak.

## Backend contract

### `POST /retention/afterglow/:pinId/visit`

- Requires active Couple membership and a non-archived pin in that Couple.
- Requires the pin to be `wishlist`, unless the same visit already exists.
- Creates the visit and updates `map_pins.status = 'visited'` plus `visit_date` in one transaction.
- Returns `{ ok, visit }` and is idempotent.

### `PUT /retention/afterglow/:visitId/contribution`

Body: `{ post_id, caption?, emotion_tag? }`.

- Validates ownership, Couple, visit date, and direct `map_pin_id` link.
- Creates or replaces only the authenticated member's contribution.
- Returns the updated contribution.

### `GET /retention/afterglow/pin/:pinId`

- Returns the pin's current visit and zero to two member contribution slots.
- Joins MomentLoop media and author display name for rendering.
- A deleted MomentLoop returns author identity plus `deleted: true`, without old content.

## Flutter seam

- Wishlist place detail exposes one primary `오늘 다녀왔어요` action.
- Success opens an Afterglow sheet with a skippable `한 장 남기기` step.
- The picker lists only the current user's MomentLoop posts directly linked to the pin on the visit date.
- Visited place detail renders `우리의 여운` with my and partner cards; empty partner state is calm, not a nag.
- Existing generic map edit and MomentLoop screens remain available.

## Data and lifecycle

- `afterglow_visits`: Couple, pin, visit date, creator, timestamps; unique per pin for MVP.
- `afterglow_contributions`: visit, user, nullable MomentLoop link, caption, emotion tag, deletion timestamp; unique per visit/user.
- MomentLoop deletion nulls its Afterglow link and marks the contribution deleted in the same transaction.
- Pin archival preserves Afterglow rows; archived pins are not available through active map endpoints.

## Acceptance

- Either partner can turn an in-Couple wishlist pin into a visit; retries do not duplicate it.
- Cross-Couple visit, contribution, and detail requests are rejected without content leakage.
- One member can complete a contribution while the other contributes nothing.
- Invalid author/date/pin MomentLoop links are rejected.
- Place detail accurately renders zero, one, two, and deleted contributions.
- Backend unit/integration tests, migration tests, static check, and Flutter tests pass.

## Explicitly out of scope

- GPS visit detection, evening/OS push notifications, ads, streaks, rewards.
- Multiple historical visits to the same pin, ratings redesign, separate map media storage.
- MVP 3 Memory Card and MVP 4 Shared Secret Base/Postcard.
