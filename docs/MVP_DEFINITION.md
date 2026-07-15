# Secret Base Couple Core Experience MVP Spec

Status: Approved on 2026-07-15

## Problem Statement

Secret Base has a broad collection of couple features, but the existence of many screens and APIs does not yet mean that two people can safely and reliably use the product. Core flows currently mix client-provided identity with server-derived identity, pairing can become active without the other user's consent, separation deletes the active Couple row, and some archive APIs do not isolate data by Couple. The public surface also exposes features whose privacy and completion levels differ significantly.

The MVP therefore needs a new completion standard. It must preserve the existing product direction and implementation assets while narrowing the public promise to a trustworthy two-person experience: sign up, mutually connect, enter one private space, keep shared memories, manage shared places, play together, separate safely, reunite with restored history, and leave the service with control over personal data.

## Solution

The MVP will be a mobile-web-first private beta for 3-5 real couples. It will expose only the verified couple core: email authentication, a pairing-wait state, consent-based pairing, a focused Couple Home, MomentLoop, Secret Map, Yut, Bomb, and all four Rock-Paper-Scissors modes.

Every public data and realtime operation will derive the user and active Couple from JWT authentication. A Couple will become a persistent relationship with active and inactive states instead of a row deleted on separation. Reuniting the same two users will reactivate the existing Couple and restore its history and D-day.

Features outside the MVP will remain preserved in source but disabled in both UI and backend entry points. Production promotion will happen only after an isolated tester environment passes automated checks, device QA, backup restoration, and a seven-day private beta with no P0 or P1 defects.

## User Stories

1. As a new user, I want to create an account without already having a partner code, so that I can enter Secret Base independently.
2. As a signed-in unpaired user, I want to enter a pairing-wait space, so that being unpaired is a valid product state rather than a blocked login.
3. As an unpaired user, I want to see and edit my profile, so that my partner can recognize me when receiving a request.
4. As an unpaired user, I want to copy my UserCode, so that I can share it outside the app.
5. As an unpaired user, I want to send a Pairing request using a UserCode, so that I can invite the intended person.
6. As a request recipient, I want to see who sent the request, so that I can make an informed decision.
7. As a request recipient, I want to accept or reject a request, so that knowing my UserCode never counts as consent.
8. As a request sender, I want to cancel a pending request, so that I can correct mistakes.
9. As either user, I want stale requests to expire after seven days, so that old invitations cannot be accepted unexpectedly.
10. As a user accepting one request, I want all other pending requests involving me to close, so that I cannot activate two relationships.
11. As a user with an active Couple, I want new Pairing requests to be blocked, so that Secret Base supports only one active relationship at a time.
12. As a newly paired user, I want the Couple Home to open only after both users consent, so that shared access has a clear boundary.
13. As a couple, we want one private Home, so that our records and realtime presence never mix with another Couple.
14. As a couple, we want to see our names and D-day on Home, so that the current relationship is immediately recognizable.
15. As a couple, we want Home shortcuts to recent MomentLoop, Secret Map, and public games, so that core actions are easy to reach.
16. As a MomentLoop author, I want to create a text record, so that I can preserve a small daily moment.
17. As a MomentLoop author, I want to attach photos, so that the record can preserve visual memories.
18. As a MomentLoop author, I want to attach a Moment Clip of at most ten seconds, so that I can preserve a GIF-like moving moment.
19. As a viewer, I want Moment Clips to loop silently by default, so that browsing the feed does not produce unexpected audio.
20. As a viewer, I want to tap a Moment Clip to hear its sound, so that audio remains available by explicit choice.
21. As a MomentLoop author, I want to edit my own record, so that I can correct its text, date, tags, or place.
22. As a MomentLoop author, I want to delete my own record and media, so that I retain control over my expression.
23. As a partner, I want to view but not alter the other person's MomentLoop, so that shared visibility does not remove authorship.
24. As a couple, we want MomentLoop entries to link to Secret Map pins, so that memories and places form one history.
25. As either partner, I want to add a Secret Map pin, so that we can build a shared place collection.
26. As either partner, I want to update a pin's visit state, date, memo, emotion tags, and shared rating, so that the map is collaborative.
27. As a pin creator, I want to delete my pin, so that destructive control remains with its creator.
28. As a couple, we want a pin linked to MomentLoop to be archived instead of hard-deleted, so that historical place links remain valid.
29. As a map user, I want direct map-tap registration when external search fails, so that an external provider outage does not block the core feature.
30. As a couple, we want to play Yut from lobby to result, so that the app provides a substantial shared realtime game.
31. As a couple, we want to play Bomb from lobby to explosion, so that the app provides a short realtime game.
32. As a couple, we want to play single-round Rock-Paper-Scissors, so that we can complete a quick synchronized choice game.
33. As a couple, we want to play best-of-three Rock-Paper-Scissors, so that the public mode set matches the existing experience.
34. As a couple, we want to play Muk-jji-ppa, so that this existing mode remains part of the public MVP.
35. As a couple, we want to play Hanabagi, so that this existing mode remains part of the public MVP.
36. As a disconnected Yut player, I want to rejoin the active match, so that a temporary network failure does not erase a long game.
37. As a disconnected Bomb player, I want to rejoin with the server timer still authoritative, so that reconnecting cannot reset the bomb.
38. As a disconnected Rock-Paper-Scissors player, I want the incomplete round cancelled, so that hidden choices are not restored unfairly.
39. As either partner, I want to separate without requiring the other person's approval, so that leaving a relationship is always possible.
40. As a separating user, I want a two-step explanation and confirmation, so that I understand the immediate consequences.
41. As the other partner, I want to be notified that the Couple became inactive, so that the shared space does not disappear silently.
42. As a separated user, I want the former shared space closed, so that neither person retains access to the other's records.
43. As a separated user, I want private access to only the records and pins I authored, so that I retain control over my own history.
44. As a separated user, I want to export my authored history as a ZIP, so that I can keep an independent copy.
45. As a separated user, I want to delete my authored historical records, so that retention is not forced on me.
46. As a user with multiple past relationships, I want each inactive Couple isolated, so that histories never cross partners.
47. As two users reuniting, we want a new request and acceptance, so that reunion still requires current consent.
48. As two users reuniting, we want the original Couple, D-day, MomentLoop, and Secret Map restored, so that our earlier history continues.
49. As a reunited user, I want to see a one-time supportive reunion screen, so that restoration feels intentional and warm.
50. As a reunited couple, we want to edit the D-day later, so that we may keep the original anniversary or choose a reunion date.
51. As a user, I want a separate account-deletion action, so that logout and separation are not confused with permanent departure.
52. As an email-authenticated user, I want account deletion to require my current password and final confirmation, so that an irreversible action is protected.
53. As a departing user, I want my MomentLoop text, photos, and clips permanently deleted, so that my authored personal content does not remain active.
54. As the remaining user, I want my own authored records preserved, so that another person's departure does not erase my work.
55. As a remaining user, I want linked map places preserved anonymously when required by my records, so that my own history does not break.
56. As a privacy-conscious user, I want unlinked pins created by a deleted account removed, so that unnecessary data is not retained.
57. As a mobile-web user, I want the core journey to work on current iPhone Safari, so that I can use the service without an installed app.
58. As a mobile-web user, I want the core journey to work on current Android Chrome, so that the MVP supports the other primary phone platform.
59. As a beta user, I want Google login hidden until both new and returning account paths are verified, so that an unreliable option does not block entry.
60. As a beta user, I want unfinished features absent from UI and unavailable through direct APIs, so that every visible promise meets the same privacy baseline.
61. As a user, I want my uploaded memories restored after routine deployments, so that deployment does not risk personal history.
62. As an operator, I want daily encrypted database and upload backups with a 30-day retention window, so that recent loss can be recovered.
63. As an operator, I want tester and production data fully isolated, so that beta activity and automated checks never mutate production.
64. As a product owner, I want a measurable seven-day beta gate, so that MVP completion is based on real use rather than screen count.

## Implementation Decisions

- Couple is the durable relationship between the same normalized pair of users. It has active and inactive states, lifecycle timestamps, a stable realtime identity, and a reunion count.
- A user may retain multiple inactive Couples but may belong to at most one active Couple. Activation and request acceptance enforce this invariant transactionally.
- Pairing requests have sender, recipient, pending/accepted/rejected/cancelled/expired status, creation and expiry timestamps, and a seven-day lifetime.
- Accepting a request either creates a new Couple or reactivates the existing Couple for that exact user pair. It rotates realtime credentials and closes all other pending requests involving either user.
- Separation is unilateral. It marks the Couple inactive, records the separation time, clears active-partner compatibility fields, closes active realtime sessions, and preserves relationship-owned history.
- Existing Couple rows migrate as active. Orphan history creates an inactive Couple only when exactly two authors can be proven for the old identifier; ambiguous rows remain author-only personal history.
- All public REST operations authenticate with JWT. User identity and active Couple are derived on the server; client-provided user or Couple identifiers cannot widen access.
- Pairing uses dedicated list, create, accept, reject, and cancel contracts. The legacy immediate-pairing contract is retired after frontend migration.
- Socket.IO authenticates the JWT during connection or join. The server derives the active room and user identity; public RoomSecret and legacy shared-secret bypasses are removed.
- MomentLoop is the public product term. Existing setlog route and storage names may remain internal compatibility names until a later migration.
- MomentLoop supports author-scoped create, read, update, and delete. Couple feed reads include both active members; personal-history reads include only the authenticated author.
- Moment Clip input is limited to 30 MB and ten seconds. Accepted video is normalized to a cross-browser 720p H.264/AAC MP4; invalid, oversized, or overlong input is rejected and partial files are cleaned up.
- Secret Map reads exclude archived pins from the active map. Both active partners may edit shared fields; only the creator may request deletion.
- Deleting a linked pin archives and anonymizes it as needed while retaining the MomentLoop relation. Deleting an unlinked pin removes it.
- Secret Map rating is one shared Couple rating, not a per-user rating.
- Account deletion requires recent JWT authentication, current password verification, and explicit final confirmation.
- Deleted users become non-login tombstones only where referential integrity requires a row. Email, names, UserCode, credentials, OAuth identifiers, and other personal profile fields are erased or replaced with non-reversible internal placeholders.
- Account deletion hard-deletes the author's MomentLoop rows and media. Created map pins are archived/anonymized if linked and deleted if unlinked.
- Personal export streams a ZIP containing authored MomentLoop JSON, original authored media, and authored Secret Map JSON. It never contains the former partner's authored content.
- Public game types are Yut, Bomb, and all four current Rock-Paper-Scissors modes. Server-side allowlists reject disabled game types even if a client sends their event directly.
- Yut and Bomb state restore after reconnection. Bomb uses server time. Incomplete Rock-Paper-Scissors state is cleared when a member disconnects.
- Public feature flags disable UI navigation and backend entry points for UNO, dice, roulette, telepathy, pirate, Q&A, missions, streaks, album, challenges, jukebox, time capsules, shelter, heart exchange, vault, and other non-MVP surfaces.
- UNO source is preserved for later redesign, but public builds do not advertise or route to it. UNO-specific shipped assets are excluded from the MVP production asset manifest.
- MVP Home contains Couple identity and D-day, recent MomentLoop, Secret Map, and public-game navigation. It does not query disabled home modules.
- Pairing notifications are in-app only: request inbox plus realtime notification while open. Email and web push are excluded.
- Tester uses a separate backend process, MariaDB schema, Redis namespace or instance, upload root, secrets, and backup set. It is not only a separate frontend.
- Formal ordered SQL migrations and a migration runner replace route-level schema mutation for the new model. Migrations support dry-run audit and production backup prerequisites.
- Database and upload backups run daily, are encrypted, retain 30 daily generations, and have a documented restore command and periodic restore drill.
- Google login remains implemented but hidden until new-user creation and returning-user login are verified in the target environment.

## Testing Decisions

- Tests assert behavior through REST, authenticated Socket.IO, Flutter navigation, browser user flows, and backup/restore commands. They do not assert private helper calls or duplicate implementation logic.
- Backend integration tests run only against a dedicated disposable MariaDB schema, isolated Redis namespace, and temporary upload root. Configuration rejects known production database hosts in test mode.
- Authentication tests cover missing, expired, forged, and wrong-user JWTs for profile, pairing, Couple, MomentLoop, Map, export, deletion, and Socket.IO.
- Relationship tests cover concurrent requests, mutual crossing requests, acceptance races, active-Couple exclusivity, unilateral separation, same-pair reunion, D-day restoration, and multiple inactive histories.
- Migration tests cover active Couple conversion, provable two-author orphan restoration, ambiguous orphan retention, idempotence, and rollback or safe failure.
- MomentLoop tests cover text/photo/clip creation, ten-second and 30 MB limits, author-only update/delete, partner read-only access, personal-history filtering, media cleanup, and cross-Couple denial.
- Secret Map tests cover shared edits, creator-only deletion, linked-pin archival, unlinked hard deletion, shared rating, external-search failure fallback, and cross-Couple denial.
- Account tests cover password confirmation, active-Couple deactivation, authored content deletion, map anonymization, tombstone privacy, export contents, and exclusion of partner-authored data.
- Socket tests cover JWT join, inactive Couple denial, room spoofing denial, disabled game denial, two-player isolation, Yut restore, Bomb timer restore, and Rock-Paper-Scissors cancellation.
- Game behavior tests cover full completion of Yut, Bomb, single round, best-of-three, Muk-jji-ppa, and Hanabagi.
- Flutter tests cover pairing-wait navigation, request inbox actions, Couple Home composition, disabled feature absence, author controls, separation confirmation, reunion celebration, and account deletion confirmation.
- Browser E2E uses two independent authenticated contexts to run register, request, accept, record, map, games, disconnect/reconnect, separate, reunite, export, and delete journeys.
- Device QA covers current iPhone Safari and Android Chrome, denied permissions, slow networks, refresh, background return, location fallback, photo upload, Moment Clip upload, and clip audio behavior.
- Deployment acceptance includes migration dry-run, pre-deploy backup, isolated tester smoke test, encrypted backup creation, restore into a disposable environment, and production health verification.
- MVP passes only after 3-5 real couples complete the core journey over seven days with zero open P0 or P1 defects.

## Out of Scope

- Native Android APK/AAB packaging, signing, Play Store submission, and iOS native packaging.
- Public self-service signup beyond the controlled private beta cohort.
- Email notifications, web push, and native push notifications.
- Verified Google login exposure before separate operational acceptance.
- UNO under its current name, visual presentation, assets, or rules presentation; legal review and independent card-game redesign are separate work.
- Dice, roulette, telepathy, pirate, Q&A, missions, streaks, album, challenges, jukebox, time capsules, shelter, heart exchange, vault, premium payments, and other non-core surfaces.
- Object storage migration. MVP retains local media storage with encrypted daily backup and tested restore.
- Per-user Secret Map ratings and concurrent collaborative text editing.
- Viewing a former partner's authored records while a Couple is inactive.
- Automatic reconstruction of ambiguous historical relationships.

## Further Notes

- Current production and tester domains share a backend, database, Redis, and uploads; tester isolation is required before the private beta can begin.
- Current core endpoints inconsistently derive identity from JWT, and Socket.IO still supports a shared-secret compatibility path. Security hardening is a release gate, not optional cleanup.
- Current MomentLoop has no author-authorized update contract, and deletion is not author-protected. Current Map creation and reads still accept client identity even though update and delete have partial JWT ownership checks.
- Current separation deletes the Couple row, which prevents reliable reunion restoration. The lifecycle migration must land before the new separation UX is enabled.
- Runtime table creation and ALTER statements exist in request paths. New migrations must not add more request-time schema mutation.
- The source tree contains unrelated user changes and sensitive-looking local backup files. Future ticket implementation must stage only files owned by each ticket and must never commit environment backups.
