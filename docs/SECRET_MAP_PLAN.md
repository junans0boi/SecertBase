# Secret Map Product Plan

Last updated: 2026-07-09

## Product Meaning

Secret Map is not just a place bookmark screen.

It is a private map where two people can collect the places that shaped their relationship, remember where they have been, and gently imagine where they want to go next. A restaurant, cafe, street, station, hotel, park, or small corner of a neighborhood can become more than a location when it carries a shared memory.

Secret Base should make love feel natural, warm, and worth protecting.

In Korea, public expressions of romance can sometimes be treated as excessive, embarrassing, attention-seeking, or uncomfortable. Secret Base should offer a different mood. It should not force couples to perform affection loudly, and it should not turn love into spectacle. Instead, it should help people record affection with taste, privacy, and sincerity.

The long-term hope is that the app makes healthy love feel visible in a better way:

- not cringe, but beautiful
- not boastful, but warm
- not something to hide, but something to care for
- not a target of jealousy, but a quiet invitation to believe in love again

Secret Map is one of the clearest places to express that idea. It turns dating into a living archive: where we went, what we felt, what we want to revisit, and what we want to recommend when a place is truly good.

## Korean Product Statement

비밀지도는 단순히 장소를 저장하는 기능이 아니다.

두 사람이 함께 지나온 장소, 다시 가고 싶은 장소, 언젠가 함께 가보고 싶은 장소를 조용히 모아두는 관계의 지도다. 어떤 가게나 거리, 카페, 여행지, 작은 골목도 두 사람의 기억이 얹히면 단순한 좌표가 아니라 둘만의 장면이 된다.

Secret Base는 사랑을 과하게 과시하게 만드는 앱이 아니라, 사랑을 자연스럽고 따뜻하게 기록하게 만드는 앱이어야 한다.

지금의 분위기에서는 연애나 커플의 표현이 때로는 부담스럽다, 유난스럽다, 관종 같다, 보기 불편하다는 말로 쉽게 소비된다. 하지만 건강한 애정 표현은 숨기거나 조롱받아야 할 것이 아니라, 잘 다듬어 보여줄 때 누군가에게 좋은 자극이 될 수 있다.

Secret Base가 만들고 싶은 이미지는 이것이다.

- 사랑이 불편한 것이 아니라 보기 좋은 것이 되는 것
- 커플의 기록이 과시가 아니라 따뜻한 아카이브가 되는 것
- 누군가의 행복이 질투의 대상이 아니라 "나도 저런 사랑을 해보고 싶다"는 마음으로 이어지는 것
- 사적인 애정은 안전하게 보호하고, 공유하고 싶은 순간은 취향 있게 꺼낼 수 있게 하는 것

비밀지도는 이 의도를 가장 잘 보여줄 수 있는 기능이다. 둘이 다녀온 곳을 다시 떠올리고, 다음 장소를 함께 고르고, 정말 좋았던 장소는 다른 커플에게도 조심스럽게 추천할 수 있다. 이 기능은 사랑을 크게 외치는 것이 아니라, 사랑이 쌓여가는 방식을 예쁘게 보여주는 지도여야 한다.

## Core Experience

The first screen should be a map.

When a couple enters Secret Map, they should immediately see the places that belong to them: memories they already made and places they want to visit together. The map should feel light and easy to explore, not like a heavy management dashboard.

The list view should exist, but as a supporting action. Users can open it when they want to browse, filter, compare, or revisit older places.

## Place Types

Secret Map should separate a place's status from its category.

Status:

- Visited: a place the couple has already been to
- Wishlist: a place the couple wants to visit

Category:

- Restaurant
- Cafe
- Activity
- Travel
- Shopping
- Other

This lets the product support combinations such as "wishlist cafe", "visited restaurant", or "visited travel spot" without overloading one field.

Korean UI terms:

- Visited: 다녀온 곳
- Wishlist: 가고 싶은 곳
- Restaurant: 식당
- Cafe: 카페
- Activity: 활동
- Travel: 여행
- Shopping: 쇼핑
- Other: 기타

## Place Detail

A place should eventually support:

- place name
- location coordinates
- status: visited or wishlist
- category
- visit date, when visited
- place information, when available
- external review photos or place photos, when available and allowed
- couple memo
- rating
- emotion tags
- connected MomentLoop entries
- author inside the couple
- public sharing settings

For MVP, the product should not try to solve every field at once. It should first create a strong place detail sheet that can grow naturally.

## Rating And Emotion Tags

Secret Map should not feel like a generic review app.

The rating can exist, but it should be expressed through couple-friendly emotion rather than only a cold score. A good direction is to combine a 1-5 rating with optional emotion tags.

Example tags:

- Again
- Special
- Funny
- Our Taste
- Photo Spot
- Good Talk
- Anniversary Candidate
- Revisit Candidate

Korean display text can be warmer:

- 또 가자
- 특별했어
- 웃겼어
- 우리 취향
- 사진 맛집
- 대화가 잘 됐어
- 기념일 후보
- 재방문 후보

The UI should make this feel like "our memory temperature", not a public review score.

## Wishlist To Visited Flow

Wishlist places should have a clear "visited" conversion flow.

When a couple taps "다녀왔어요", the app should ask for:

- visit date
- short memo
- rating
- emotion tags

After completion, the place becomes a visited memory.

This action can grant a small reward, but early rewards should stay inside the product economy. For example:

- couple points
- map completion progress
- badges
- small celebratory animation

Cash-like rewards should be considered later because they introduce abuse prevention, moderation, and operational cost.

## MomentLoop Connection

Secret Map should connect to MomentLoop before building a separate heavy photo system.

The stronger product loop is:

1. A couple visits a place.
2. They add a memory in MomentLoop.
3. That memory can be linked to the place.
4. Later, the place detail shows the memories connected to it.

This answers the real user need: "Where did we go before? I want to go there again."

Direct photo attachment to map pins can come later, especially for public recommendation features.

## Social And Sharing Direction

Secret Map starts private, but it can grow into a tasteful recommendation network.

Inside the couple:

- show who added the place
- allow hearts/likes
- allow comments
- only the author can edit or delete the place

Outside the couple:

- show the place as a shared couple recommendation, not as one person's private record
- expose only fields the couple chooses to share
- let the couple decide whether photos are public or private
- keep private memos private by default

Good public recommendation fields:

- place name
- category
- general area
- rating summary
- emotion tags
- selected public photos, if allowed
- short public recommendation note, if added intentionally

Private by default:

- couple memo
- exact personal story
- private photos
- who added the place
- comments between partners

## Recommendation Mode

Other couples' recommendations should not be mixed into the private map by default.

A better direction is a separate "추천 둘러보기" mode or tab. This can support:

- theme search
- location search
- category filters
- date-course style collections
- popular places among couples
- places similar to the couple's saved places

This keeps Secret Map emotionally private while still allowing discovery.

## Sharing

Place sharing should support two levels.

Private sharing:

- send a place to the partner
- share a place card through KakaoTalk
- copy a link

Public/social sharing:

- export a tasteful place card image
- share to social platforms such as Instagram-style posts or stories
- support "Lovestagram" style sharing without making it feel loud or attention-seeking

The design language should be warm, restrained, and proud in a quiet way. The app should help couples share love without making them feel exposed.

## Map Provider Direction

Current decision:

- Keep map rendering in Flutter. Do not replace the main map with Kakao Maps JavaScript SDK or Naver Maps SDK for now.
- Use Kakao Local REST API as the primary place search provider through the backend `/api/places/search` proxy.
- Use NAVER API HUB Search Local as a fallback or supplemental place search provider when configured.
- Use Naver Maps Geocoding/Reverse Geocoding only for coordinate/address hints when configured.
- Use Kakao/Naver/TMAP URL schemes for external directions, not as the in-app map renderer.

Why:

- Secret Base ships as Flutter Web and Android, so a web-only map SDK would split the map implementation.
- The user-facing value right now is accurate place search, saved couple places, filters, custom pins, and directions.
- Backend proxying keeps provider keys off the Flutter client and lets the app normalize Kakao/NAVER/OSM responses into one place shape.

Provider path:

1. Keep the current Flutter map stack while UX is being shaped.
2. Keep Kakao Local enabled as the first provider in `/api/places/search`.
3. Add NAVER Local keys when needed for fallback/coverage checks.
4. Add Naver Maps geocoding keys only if region-hint quality needs improvement.
5. Keep direct Nominatim usage as a last fallback, not the primary Korean place search path.
6. Revisit Kakao/Naver map SDK rendering only if a review requirement or product quality issue proves that Flutter map rendering is insufficient.

## Pin Design Direction

Pins should be easy for MZ users to understand without reading instructions.

Recommended visual rules:

- visited places: solid, warm, confident pins
- wishlist places: lighter or outlined pins
- active pin: larger with a soft highlight
- category: recognizable icon or emoji inside the pin
- public/recommended places: visually separate from private couple places

The first screen should avoid visual overload. Filtering and bottom sheets should do the heavy lifting.

## Implementation Slices

### Slice 1: UX Prototype In Current Frontend

Goal:

- make the current map feel like the intended Secret Map product

Scope:

- map-first screen polish
- status filter: visited/wishlist
- category filter
- place detail bottom sheet
- add-place flow polish
- wishlist to visited conversion UI
- share action placeholders
- reactions/comments placeholders if backend is not ready

This can use local mock fields or compatibility fields where needed, but should avoid pretending the backend is complete.

### Slice 2: Backend Ownership And Privacy

Goal:

- make Secret Map safe for real couple data

Scope:

- add couple/user ownership fields to `map_pins`
- require authenticated requests for map APIs
- scope `GET /api/map` to the authenticated couple
- validate create/update/delete ownership
- add backend tests
- update REST docs

This should happen before production launch of the feature.

### Slice 3: Real Feature Connection

Goal:

- connect UI to durable product behavior

Scope:

- status field
- emotion tags
- wishlist to visited transition
- comments
- hearts/likes
- MomentLoop place linking
- author-only edit/delete

### Slice 4: Recommendations And Sharing

Goal:

- carefully expand from private memory to public discovery

Scope:

- public/private sharing settings
- public recommendation cards
- recommendation browsing tab
- KakaoTalk/link/card-image sharing
- search provider and backend cache decision

## Near-Term Product Decision

The next engineering step is intentionally UX-first.

Build the frontend shape first so the product can be felt and judged. While building the UI, keep notes on the backend model that naturally emerges. Once the product shape feels right, implement backend ownership, privacy, status, reactions, comments, MomentLoop linkage, and sharing in vertical slices.
