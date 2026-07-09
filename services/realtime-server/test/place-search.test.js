import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildNaverQueries,
  distanceMetersBetween,
  mergePlaces,
  normalizeKakaoPlace,
  normalizeNaverPlace,
  normalizeNaverReverseGeocodeRegion,
  normalizeNominatimRegionHints,
  rankPlacesByDistance,
  searchPlaces,
  stripHtml,
} from '../src/place-search.js';

test('stripHtml removes API highlight markup and entities', () => {
  assert.equal(stripHtml('<b>성수</b> 카페 &amp; 바'), '성수 카페 & 바');
});

test('normalizeKakaoPlace maps Kakao Local fields to app place shape', () => {
  const place = normalizeKakaoPlace({
    id: '123',
    place_name: '성수 카페',
    category_group_name: '카페',
    category_group_code: 'CE7',
    address_name: '서울 성동구 성수동',
    road_address_name: '서울 성동구 성수이로',
    phone: '02-123-4567',
    place_url: 'https://place.map.kakao.com/123',
    x: '127.055',
    y: '37.544',
    distance: '140',
  });

  assert.deepEqual(place, {
    provider: 'kakao',
    providerPlaceId: '123',
    name: '성수 카페',
    category: '카페',
    categoryCode: 'CE7',
    address: '서울 성동구 성수동',
    roadAddress: '서울 성동구 성수이로',
    phone: '02-123-4567',
    placeUrl: 'https://place.map.kakao.com/123',
    latitude: 37.544,
    longitude: 127.055,
    distanceMeters: 140,
  });
});

test('normalizeNaverPlace strips markup and converts map coordinates', () => {
  const place = normalizeNaverPlace({
    title: '<b>성수</b> 맛집',
    category: '음식점&gt;한식',
    address: '서울 성동구 성수동',
    roadAddress: '서울 성동구 성수이로',
    telephone: '02-111-2222',
    link: 'https://map.naver.com/p/entry/place/abc',
    mapx: '1270550000',
    mapy: '375440000',
  });

  assert.equal(place.name, '성수 맛집');
  assert.equal(place.category, '음식점>한식');
  assert.equal(place.latitude, 37.544);
  assert.equal(place.longitude, 127.055);
});

test('normalizeNaverGeocodeAddress maps Naver Maps geocode result', async () => {
  const { normalizeNaverGeocodeAddress } = await import('../src/place-search.js');
  const place = normalizeNaverGeocodeAddress({
    roadAddress: '서울특별시 성동구 성수이로 1',
    jibunAddress: '서울특별시 성동구 성수동2가 1',
    englishAddress: '1, Seongsui-ro, Seongdong-gu, Seoul',
    x: '127.055',
    y: '37.544',
  });

  assert.equal(place.provider, 'naver_maps');
  assert.equal(place.name, '서울특별시 성동구 성수이로 1');
  assert.equal(place.categoryCode, 'ADDRESS');
  assert.equal(place.latitude, 37.544);
  assert.equal(place.longitude, 127.055);
});

test('mergePlaces deduplicates nearby same-name providers', () => {
  const places = mergePlaces(
    [
      { name: '성수 카페', latitude: 37.5441, longitude: 127.0551 },
      { name: '성수카페', latitude: 37.5442, longitude: 127.0552 },
      { name: '다른 카페', latitude: 37.545, longitude: 127.056 },
    ],
    10,
  );

  assert.equal(places.length, 2);
  assert.equal(places[0].name, '성수 카페');
  assert.equal(places[1].name, '다른 카페');
});

test('rankPlacesByDistance calculates distance and sorts nearby places first', () => {
  const places = rankPlacesByDistance(
    [
      { name: '혜화점', latitude: 37.5822, longitude: 127.0019 },
      { name: '발산점', latitude: 37.5594, longitude: 126.8393 },
      { name: '마곡나루점', latitude: 37.5656, longitude: 126.8271 },
    ],
    37.5668,
    126.8279,
  );

  assert.equal(places[0].name, '마곡나루점');
  assert.equal(places[1].name, '발산점');
  assert.ok(places[0].distanceMeters < 1000);
  assert.ok(places[2].distanceMeters > 10000);
});

test('distanceMetersBetween returns null without usable coordinates', () => {
  assert.equal(
    distanceMetersBetween({ latitude: 37.5, longitude: 126.9 }, { latitude: null, longitude: 127 }),
    null,
  );
});

test('buildNaverQueries adds nearby region hints without duplicating the query', () => {
  assert.deepEqual(buildNaverQueries('철길부산집', ['마곡동', '강서구']), [
    '철길부산집',
    '마곡동 철길부산집',
    '강서구 철길부산집',
  ]);
  assert.deepEqual(buildNaverQueries('마곡 철길부산집', ['마곡']), ['마곡 철길부산집']);
});

test('normalizes reverse geocode responses into region hints', () => {
  assert.deepEqual(
    normalizeNaverReverseGeocodeRegion({
      results: [
        {
          region: {
            area1: { name: '서울특별시' },
            area2: { name: '강서구' },
            area3: { name: '마곡동' },
            area4: { name: '' },
          },
        },
      ],
    }),
    ['마곡동', '강서구', '서울특별시'],
  );
  assert.deepEqual(
    normalizeNominatimRegionHints({
      address: {
        quarter: '마곡지구도시개발지구',
        suburb: '가양1동',
        borough: '강서구',
        city: '서울특별시',
      },
    }),
    ['마곡지구도시개발지구', '가양1동', '강서구', '서울특별시'],
  );
});

test('searchPlaces queries Kakao first and fills remaining results from Naver', async () => {
  const seenUrls = [];
  const fetchImpl = async (url) => {
    seenUrls.push(String(url));
    if (String(url).startsWith('https://dapi.kakao.com')) {
      return {
        ok: true,
        async json() {
          return {
            documents: [
              {
                id: 'k1',
                place_name: '성수 카페',
                x: '127.055',
                y: '37.544',
              },
            ],
          };
        },
      };
    }

    return {
      ok: true,
      async json() {
        return {
          items: [
            {
              title: '성수 맛집',
              mapx: '1270560000',
              mapy: '375450000',
            },
          ],
        };
      },
    };
  };

  const result = await searchPlaces({
    query: '성수',
    limit: 2,
    config: {
      KAKAO_REST_API_KEY: 'kakao-key',
      NAVER_SEARCH_CLIENT_ID: 'naver-id',
      NAVER_SEARCH_CLIENT_SECRET: 'naver-secret',
    },
    fetchImpl,
  });

  assert.equal(result.places.length, 2);
  assert.equal(result.places[0].provider, 'kakao');
  assert.equal(result.places[1].provider, 'naver');
  assert.equal(seenUrls.length, 2);
});

test('searchPlaces works with Naver only when Kakao key is not configured', async () => {
  const seenUrls = [];
  const fetchImpl = async (url) => {
    seenUrls.push(String(url));
    return {
      ok: true,
      async json() {
        return {
          items: [
            {
              title: '<b>홍대</b> 파스타',
              category: '음식점&gt;이탈리아음식',
              address: '서울 마포구 서교동',
              roadAddress: '서울 마포구 와우산로',
              mapx: '1269220000',
              mapy: '375560000',
            },
          ],
        };
      },
    };
  };

  const result = await searchPlaces({
    query: '홍대 파스타',
    limit: 5,
    config: {
      KAKAO_REST_API_KEY: '',
      NAVER_SEARCH_CLIENT_ID: 'naver-id',
      NAVER_SEARCH_CLIENT_SECRET: 'naver-secret',
    },
    fetchImpl,
  });

  assert.equal(result.providers.kakao.enabled, false);
  assert.equal(result.providers.naver.enabled, true);
  assert.equal(result.places.length, 1);
  assert.equal(result.places[0].provider, 'naver');
  assert.equal(result.places[0].name, '홍대 파스타');
  assert.equal(seenUrls.length, 1);
  assert.ok(seenUrls[0].startsWith('https://naverapihub.apigw.ntruss.com/search/v1/local'));
});

test('searchPlaces augments Naver search with region hints and returns nearest first', async () => {
  const seenUrls = [];
  const fetchImpl = async (url) => {
    seenUrls.push(String(url));
    const parsedUrl = new URL(String(url));
    const query = parsedUrl.searchParams.get('query');

    if (String(url).startsWith('https://nominatim.openstreetmap.org')) {
      return {
        ok: true,
        async json() {
          return {
            address: {
              borough: '강서구',
              city: '서울특별시',
            },
          };
        },
      };
    }

    return {
      ok: true,
      async json() {
        if (query === '철길부산집') {
          return {
            items: [
              {
                title: '철길부산집 대학로혜화점',
                mapx: '1270019000',
                mapy: '375822000',
              },
            ],
          };
        }
        if (query === '강서구 철길부산집') {
          return {
            items: [
              {
                title: '철길부산집 마곡나루점',
                mapx: '1268271000',
                mapy: '375656000',
              },
              {
                title: '철길부산집 발산점',
                mapx: '1268393000',
                mapy: '375594000',
              },
            ],
          };
        }
        return { items: [] };
      },
    };
  };

  const result = await searchPlaces({
    query: '철길부산집',
    latitude: 37.5668,
    longitude: 126.8279,
    limit: 3,
    config: {
      KAKAO_REST_API_KEY: '',
      NAVER_SEARCH_CLIENT_ID: 'naver-id',
      NAVER_SEARCH_CLIENT_SECRET: 'naver-secret',
    },
    fetchImpl,
  });

  assert.ok(seenUrls.some((url) => url.includes('nominatim.openstreetmap.org')));
  assert.ok(
    seenUrls.some((url) => new URL(url).searchParams.get('query') === '강서구 철길부산집'),
  );
  assert.equal(result.places[0].name, '철길부산집 마곡나루점');
  assert.equal(result.places[1].name, '철길부산집 발산점');
  assert.equal(result.places[2].name, '철길부산집 대학로혜화점');
  assert.deepEqual(result.regionHints, ['강서구', '서울특별시']);
});

test('searchPlaces returns no places when providers are not configured', async () => {
  const result = await searchPlaces({
    query: '성수',
    config: {
      KAKAO_REST_API_KEY: '',
      NAVER_SEARCH_CLIENT_ID: '',
      NAVER_SEARCH_CLIENT_SECRET: '',
    },
    fetchImpl: async () => {
      throw new Error('fetch should not be called');
    },
  });

  assert.deepEqual(result.places, []);
  assert.equal(result.providers.kakao.enabled, false);
  assert.equal(result.providers.naver.enabled, false);
});

test('searchPlaces uses Naver Maps geocode when only Maps keys are configured', async () => {
  const seenUrls = [];
  const fetchImpl = async (url) => {
    seenUrls.push(String(url));
    return {
      ok: true,
      async json() {
        return {
          addresses: [
            {
              roadAddress: '서울특별시 성동구 성수이로 1',
              jibunAddress: '서울특별시 성동구 성수동2가 1',
              x: '127.055',
              y: '37.544',
            },
          ],
        };
      },
    };
  };

  const result = await searchPlaces({
    query: '서울특별시 성동구 성수이로 1',
    limit: 3,
    config: {
      KAKAO_REST_API_KEY: '',
      NAVER_SEARCH_CLIENT_ID: '',
      NAVER_SEARCH_CLIENT_SECRET: '',
      NAVER_MAPS_CLIENT_ID: 'maps-id',
      NAVER_MAPS_CLIENT_SECRET: 'maps-secret',
    },
    fetchImpl,
  });

  assert.equal(result.providers.naverMaps.enabled, true);
  assert.equal(result.places.length, 1);
  assert.equal(result.places[0].provider, 'naver_maps');
  assert.ok(seenUrls[0].startsWith('https://naveropenapi.apigw.ntruss.com/map-geocode'));
});
