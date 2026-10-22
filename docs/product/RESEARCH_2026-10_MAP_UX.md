# 리서치: 지도 앱의 장소 저장·목록·검색·바텀시트 UX (2026-10)

대상: Naver 지도 / 카카오맵 / Google Maps → Secret Map(`apps/secret_base_app/lib/screens/archive/map_screen.dart`) 재설계 입력.
기존 문서(`docs/SECRET_MAP_PLAN.md`, `docs/product/2026_COUPLE_APP_RETENTION_RESEARCH.md`)의 제품 의미·리텐션 논의는 반복하지 않는다.
방법: 공식 도움말·보도자료·개발자 문서·앱스토어 소개글만 사용. APK 분해나 비공개 API 호출은 하지 않았다.

## 요약 (10줄)

1. 세 앱 모두 "저장"을 **지도 위 레이어 + 별도 목록 화면**의 두 겹으로 둔다. 지도에는 별/아이콘으로 겹쳐 보이고, 목록은 탭/시트에서 관리한다.
2. Naver는 하단 탭에 **저장 탭**을 두고(2022-12), 음식점·카페·숙박·명소 4개 업종으로 걸러 본다. 상한은 5,000곳.
3. Google은 저장 시 **Save → 리스트 선택(또는 New list)** 2단계이며, 리스트는 Private/Shared 두 종류에 기본 리스트 5개가 있다.
4. Google은 리스트별 **"Hide on your map"** 으로 지도에 표시할 레이어를 고른다. Secret Map의 상태/카테고리 칩보다 "레이어 단위 on/off"가 더 직관적이다.
5. 공유는 **링크 공유 + 편집자 초대**가 분리돼 있다(Google). Naver는 공유만 출시, 공동관리는 "예정"으로 발표(2022).
6. 카카오맵 즐겨찾기는 **그룹 + 공유&구독**이고, 새 폴더 기본 공개가 개인정보위 권고로 **기본 비공개 + 저장할 때마다 공개 여부 안내**로 바뀌었다. 커플 앱은 처음부터 비공개 기본값이어야 한다.
7. 바텀시트는 Android Material에서 **collapsed / half-expanded / expanded** 3단과 peek 높이가 표준이다. Secret Map의 142px 캐러셀 + 모달 시트 구성은 이 3단 구조가 아니다.
8. 마커 개수가 늘면 **클러스터링**이 필요하다. 현재 코드는 개별 Marker만 쓰고, 클러스터 패키지는 `flutter_map ^8.2.2`를 요구해 **지금 `^6.1.0`에서 올려야** 한다.
9. Secret Map의 가장 큰 격차: (a) 리스트/폴더 개념 없음, (b) 지도 위 비모달 시트 없음, (c) 클러스터링 없음, (d) 업종 필터가 6개 칩 한 줄뿐.
10. 확인하지 못한 것: Naver·카카오 고객센터의 단계별 절차, Material/Apple 가이드라인 본문(JS 렌더링으로 수집 실패). 해당 항목은 아래에서 "미확인"으로 표시했다.

---

## 1. Google Maps

### 정보 구조
- 도움말이 가리키는 진입점은 **You(내) 탭**이며 "Find your places & lists in the You tab" 문서가 있다. 출처: [Google Maps 도움말 색인](https://support.google.com/maps/answer/7677966?hl=en)
- 기본 리스트는 **Favorites, Want to go, Starred places, Labeled, Travel plans** 5종이고 아이콘은 바꿀 수 없다. 출처: [Create a list of places](https://support.google.com/maps/answer/7280933?hl=en)

### 장소 저장 흐름
1. 장소 검색 또는 지도에서 장소 탭
2. 이름/주소 탭 → **Save**
3. 리스트 선택 또는 **New list**
- 여러 장소 일괄 저장: You > See all > 선택 > Save > 리스트 선택 > Done. 출처: 위와 같음.
- 메모: 도움말은 메모 작성 방법을 설명하지 않고, 리스트 열람자가 "who has added or edited places and notes"를 볼 수 있다는 사실만 적는다.
- 개인 라벨: 도움말 색인에 "Give a place a private label" 문서가 존재한다(본문 미확인). 출처: [도움말 색인](https://support.google.com/maps/answer/7677966?hl=en)

### 리스트·공유 모델
- 리스트 종류: **Private**("Only you can view and edit") / **Shared**("Share a link to view or edit"). 출처: [Create a list of places](https://support.google.com/maps/answer/7280933?hl=en)
- 공동 편집: 리스트에서 **Share** 또는 **Invite collaborators**. 편집 해제는 "Let others edit this list" 끄기. 열람자는 참여자의 이름과 프로필 사진을 볼 수 있다. 출처: 위와 같음.
- 다른 사람의 리스트는 **Save list**로 저장하고, 저장한 리스트는 메인 지도에 표시된다(숨기기 가능). 출처: 위와 같음.

### 지도 표시
- 리스트 단위로 **Hide on your map / Show on your map** 토글. 출처: 위와 같음.

### 마커 클러스터링 (개발자 문서)
- "By clustering your markers, you can put a large number of markers on a map without making the map hard to read." 낮은 줌에서 묶이고 높은 줌에서 개별 마커가 나타난다. 알고리즘·렌더러는 교체 가능. 최소 클러스터 크기·줌 임계값은 문서에 없다. 출처: [Marker clustering (Android)](https://developers.google.com/maps/documentation/android-sdk/utility/marker-clustering)

### 미확인
- Google Maps 앱의 바텀시트 스냅 높이, 검색 필터 칩 구성, 저장 장소 아이콘 모양은 공식 문서에서 본문을 얻지 못했다.

---

## 2. Naver 지도

### 정보 구조 (공식 보도자료, 2022-12-13)
- 첫 화면에 **저장 탭** 신설(2022-12-12부터 순차 적용). 지도 화면에서는 **별 모양 버튼**으로 저장 장소를 지도 위에 표시한다.
- 지도·통합검색·MY플레이스·블로그·카페 등 **여러 서비스에서 저장한 장소를 한 목록**에 모은다.
- 저장 한도 **2,000곳 → 5,000곳**. 출처: [네이버 보도자료 seq=30998](https://navercorp.com/media/pressReleasesDetail?seq=30998)
- 하단 탭 구성 최근 변화: 2025-06 **발견 탭**이 하단 막대 맨 왼쪽에 추가됐다(기존 주변 탭 고도화). 구성은 "지금 많이 찾는 장소 / 내 활동 기반 추천 / **인기 있는 저장리스트** / 주변 혜택 / 전국 핫플레이스". 출처: [뉴데일리 2025-06-19](https://biz.newdaily.co.kr/site/data/html/2025/06/19/2025061900125.html)

### 업종 필터
- 저장 장소를 **음식점 · 카페 · 숙박 · 명소** 4개 업종으로 모아 볼 수 있다. 출처: [네이버 보도자료](https://navercorp.com/media/pressReleasesDetail?seq=30998)

### 공유
- 저장 탭에서 공유 버튼으로 리스트를 공유하면 친구·가족이 **실시간으로 갱신된 내용**을 본다. 출처: 위와 같음.
- **공동관리는 "추후 추가 예정"** 으로 발표됐다(출시 여부는 이번 조사에서 확인하지 못했다). 출처: 위와 같음.

### 인사이트
- Naver가 "인기 있는 저장리스트"를 발견 탭에 올린 이유는 "취향에 맞는 장소를 자신의 리스트에 저장하고 공유하는 사용자가 늘었기 때문"이라고 보도됐다. 저장 리스트가 개인 기능에서 **콘텐츠 단위**로 올라온 사례다. 출처: [뉴데일리](https://biz.newdaily.co.kr/site/data/html/2025/06/19/2025061900125.html)

### 미확인
- 폴더 만들기·이름 변경·삭제의 단계별 절차, 공유 링크 권한 모델, 마커 모양은 고객센터 문서를 찾지 못했다.

---

## 3. 카카오맵

### 정보 구조
- 앱스토어 소개: "그룹 형태로 즐겨찾기를 관리하고, 지도 위 표시는 물론 그룹 공유&구독까지 한번에!", "지도 위에 바로 표시되는 즐겨찾기", "검색창 하나로 버스번호, 정류장, 장소 등 모든 정보를 한 번에". 출처: [App Store 카카오맵](https://apps.apple.com/KR/app/id304608425)
- 6.29.3 업데이트 노트: "탭 메뉴를 개편해 지도와 퀵 탭에 더 많은 공간을 제공". 즉 **지도 면적 확보**가 최근 방향이다. 출처: 위와 같음.
- 공식 서비스 소개는 주변탭(주변 추천)과 테마지도를 언급한다. 출처: [카카오 서비스 소개](https://www.kakaocorp.com/service/KakaoMap)

### 즐겨찾기 폴더의 공개 범위 (개인정보위 조사)
- 기본 폴더는 비공개였으나 **새 폴더 생성 시 공개가 기본값**이었다. 2021-01 기준 약 80만 계정 중 약 68만(85%)이 공개 폴더를 보유했다.
- 개인정보위 권고 후 카카오는 **새 폴더를 모두 비공개로 일괄 전환하고 기본값을 비공개로 변경**, 장소를 폴더에 저장할 때마다 공개/비공개 여부와 공개 시 위험을 안내한다.
- 공개 시 다른 사용자가 구독해 목록을 보거나 카카오톡 등으로 외부 공유할 수 있다. 출처: [아이뉴스24](https://www.inews24.com/view/1454458)

### 미확인
- 즐겨찾기 폴더 생성·저장·공유의 단계별 UI는 고객센터 문서를 찾지 못했다. 카카오 공식 서비스 소개 페이지에는 즐겨찾기/내 장소가 나오지 않는다.

---

## 4. 바텀시트·지도 위 시트 (플랫폼 문서)

- Android Material `BottomSheetBehavior` 상태: **COLLAPSED, HALF_EXPANDED, EXPANDED, HIDDEN**(+DRAGGING/SETTLING). `peekHeight`는 접힌 높이이고 기본 자동값은 "Peek at the 16:9 ratio keyline of its parent". `fitToContents=false`이면 "half the height of the parent container, full height of parent container" 2단 확장이다. `halfExpandedRatio`로 중간 높이를 조절한다. 출처: [BottomSheetBehavior 레퍼런스](https://developer.android.com/reference/com/google/android/material/bottomsheet/BottomSheetBehavior)
- Material Design 3 bottom sheets 가이드라인과 Apple HIG sheets 본문은 JS 렌더링으로 수집하지 못했다. "Apple Maps처럼 시트 뒤 지도를 계속 조작할 수 있는 비모달 시트(`presentationBackgroundInteraction`)와 medium/large detent"는 일반 지식 기반 요약이며 **1차 출처로 검증되지 않았다**. 구현 전 [Apple HIG: Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)와 [Material 3: Bottom sheets](https://m3.material.io/components/bottom-sheets/overview)를 직접 확인해야 한다.

---

## 5. Secret Map 현재 상태와 격차

현재 구현(`map_screen.dart`, 코드 확인):
- 상단: 검색창 + 위치 버튼 + 목록 버튼, 그 아래 **상태 칩 3개**(전체/다녀온 곳/가고 싶은 곳)와 **카테고리 칩**(식당·카페·활동·여행·쇼핑·기타) 두 줄.
- 하단: 142px **PageView 캐러셀 카드**(`_pinCard`) + FAB(장소 추가).
- 목록: `_showListSheet`의 **모달 바텀시트**("장소 모아보기"). 상세·수정·추가도 모두 `showModalBottomSheet`.
- 마커: 개별 `Marker`만 사용. 클러스터링 없음. 의존성은 `flutter_map ^6.1.0`, `latlong2 ^0.9.0`, `geolocator ^14.0.2`.

| 영역 | Naver | Google | 카카오 | Secret Map |
|---|---|---|---|---|
| 저장 단위 | 저장 목록(업종 필터) | 리스트(기본 5 + 사용자) | 즐겨찾기 그룹 | **리스트/폴더 없음**, 상태+카테고리만 |
| 지도 레이어 on/off | 별 버튼 | 리스트별 Hide/Show | 지도 위 표시 | 상태·카테고리 칩으로만 필터 |
| 지도 위 시트 | (미확인) | (미확인) | (미확인) | 캐러셀 + **모달** 시트, 3단 시트 없음 |
| 공유 | 링크 공유(공동관리 예정) | 링크 + 편집자 초대 | 공개 폴더 구독 + 외부 링크 | **커플 둘 다 편집**(서버 스코프됨), 외부 공유 없음 |
| 기본 공개 범위 | (미확인) | Private 기본 | 비공개 기본(권고 후) | 커플 비공개(적합) |
| 마커 관리 | (미확인) | 클러스터링 API 제공 | (미확인) | **클러스터링 없음** |

---

## 6. 우선순위별 제안 (구체 변경)

### P0 — 사용성 핵심
1. **리스트(컬렉션) 도입**: 장소를 "데이트 코스/맛집/가고 싶은 곳" 같은 사용자 리스트에 담는다. 근거: Google은 기본 5개 + 사용자 리스트, 카카오는 그룹, Naver는 저장 목록 중심. Secret Map은 지금 상태+카테고리 2축뿐이다.
2. **장소 저장을 2단계로**: 장소 탭 → Save → 리스트 선택. 근거: [Google 도움말](https://support.google.com/maps/answer/7280933?hl=en)의 Save→리스트 흐름. 현재는 `_showAddDialog` 하나의 긴 시트에서 상태·카테고리·감정·메모를 한 번에 요구한다.
3. **지도 위 비모달 3단 시트**: collapsed(peek) / half / full. 근거: Android `BottomSheetBehavior`의 3단 구조([레퍼런스](https://developer.android.com/reference/com/google/android/material/bottomsheet/BottomSheetBehavior)). 시트 뒤 지도 조작 허용은 미검증(§4 참고). 현재 142px 캐러셀과 모달 목록을 하나로 합친다.
4. **리스트별 지도 표시 토글**: Google의 "Hide/Show on your map"과 같이 레이어 단위 on/off. 근거: [Google 도움말](https://support.google.com/maps/answer/7280933?hl=en).

### P1 — 규모 대응
5. **마커 클러스터링**: 핀이 수십 개를 넘기 전에 도입. 근거: [Google 클러스터링 문서](https://developers.google.com/maps/documentation/android-sdk/utility/marker-clustering). Flutter에서는 `flutter_map_marker_cluster 8.2.2`가 `flutter_map ^8.2.2`를 요구하므로 **현재 `^6.1.0`에서 메이저 업그레이드가 선행 조건**이다. 출처: [pub.dev](https://pub.dev/packages/flutter_map_marker_cluster), [flutter_map 최신 8.3.2](https://pub.dev/packages/flutter_map). 해당 패키지 마지막 게시가 약 12개월 전이라 유지보수 상태도 확인해야 한다.
6. **업종 필터 정리**: Naver는 4개 업종(음식점·카페·숙박·명소)으로 단순화했다. 현재 6개 칩 + 상태 칩 3개 = 두 줄은 지도 면적을 많이 가린다. 카카오도 최근 탭 메뉴를 줄여 지도 면적을 키웠다([App Store 업데이트 노트](https://apps.apple.com/KR/app/id304608425)). 칩 한 줄 + "필터" 시트로 합치는 안을 검토한다.
7. **편집 이력 표시**: Google은 리스트 열람자에게 "누가 장소·메모를 추가·수정했는지"를 보여준다. 커플 공동 편집이므로 "○○가 추가" 정도의 표시를 검토한다.

### P2 — 확장
8. **다른 커플/지인과의 공유(읽기 전용 링크)**: Google·카카오·Naver 모두 공유를 제공하지만, 카카오 사례처럼 기본값은 반드시 비공개여야 하고 저장 시점에 공개 여부를 안내해야 한다(개인정보위 권고). 비밀지도의 제품 철학과 충돌할 수 있어 별도 결정이 필요하다.
9. **추천/발견 영역**: Naver 발견 탭의 "인기 있는 저장리스트"처럼 리스트를 콘텐츠로 올리는 구조. 커플 앱에서는 개인정보 위험이 크므로 후순위.

---

## 7. 열린 질문 (그릴링 후보)

- 리스트는 "상태(다녀온/가고 싶은)"를 대체하는가, 병행하는가?
- 장소 상세는 시트 3단으로 통합할지, 별도 화면으로 둘지.
- `flutter_map` 6→8 업그레이드의 영향 범위(타일 URL, `MapOptions` API 변경)를 먼저 조사할지.
- 외부 공유(P2)를 출시 범위에 넣을지.

## 8. 출처 목록

- [Google Maps 도움말: Create a list of places](https://support.google.com/maps/answer/7280933?hl=en)
- [Google Maps 도움말 색인](https://support.google.com/maps/answer/7677966?hl=en)
- [Google Maps Platform: Marker clustering (Android)](https://developers.google.com/maps/documentation/android-sdk/utility/marker-clustering)
- [네이버 보도자료: 지도 저장 탭(2022-12)](https://navercorp.com/media/pressReleasesDetail?seq=30998)
- [뉴데일리: 네이버 지도 발견 탭(2025-06-19)](https://biz.newdaily.co.kr/site/data/html/2025/06/19/2025061900125.html)
- [아이뉴스24: 카카오 즐겨찾기 공개 범위 개인정보위 권고](https://www.inews24.com/view/1454458)
- [App Store: 카카오맵 소개 및 업데이트 노트](https://apps.apple.com/KR/app/id304608425)
- [카카오 공식: 카카오맵 서비스 소개](https://www.kakaocorp.com/service/KakaoMap)
- [Android 개발자: BottomSheetBehavior](https://developer.android.com/reference/com/google/android/material/bottomsheet/BottomSheetBehavior)
- [pub.dev: flutter_map_marker_cluster](https://pub.dev/packages/flutter_map_marker_cluster)
- [pub.dev: flutter_map](https://pub.dev/packages/flutter_map)

수집하지 못한 1차 자료: Naver 지도 고객센터, 카카오맵 고객센터, Material 3 Bottom sheets, Apple HIG Sheets.
