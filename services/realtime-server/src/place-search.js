const KAKAO_SEARCH_URL = 'https://dapi.kakao.com/v2/local/search/keyword.json';
const NAVER_SEARCH_URL = 'https://naverapihub.apigw.ntruss.com/search/v1/local';
const NAVER_GEOCODE_URL = 'https://maps.apigw.ntruss.com/map-geocode/v2/geocode';
const NAVER_REVERSE_GEOCODE_URL =
  'https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc';
const NOMINATIM_REVERSE_URL = 'https://nominatim.openstreetmap.org/reverse';
const regionHintCache = new Map();

export function normalizeKakaoPlace(document) {
  const lat = Number(document.y);
  const lng = Number(document.x);

  return {
    provider: 'kakao',
    providerPlaceId: document.id ? String(document.id) : null,
    name: document.place_name || '',
    category: document.category_group_name || document.category_name || '',
    categoryCode: document.category_group_code || '',
    address: document.address_name || '',
    roadAddress: document.road_address_name || '',
    phone: document.phone || '',
    placeUrl: document.place_url || '',
    latitude: Number.isFinite(lat) ? lat : null,
    longitude: Number.isFinite(lng) ? lng : null,
    distanceMeters: document.distance ? Number(document.distance) : null,
  };
}

export function normalizeNaverPlace(item) {
  const lng = Number(item.mapx) / 10000000;
  const lat = Number(item.mapy) / 10000000;

  return {
    provider: 'naver',
    providerPlaceId: item.link || null,
    name: stripHtml(item.title || ''),
    category: stripHtml(item.category || ''),
    categoryCode: '',
    address: stripHtml(item.address || ''),
    roadAddress: stripHtml(item.roadAddress || ''),
    phone: stripHtml(item.telephone || ''),
    placeUrl: item.link || '',
    latitude: Number.isFinite(lat) ? lat : null,
    longitude: Number.isFinite(lng) ? lng : null,
    distanceMeters: null,
  };
}

export function normalizeNaverGeocodeAddress(item) {
  const lng = Number(item.x);
  const lat = Number(item.y);
  const roadAddress = item.roadAddress || '';
  const jibunAddress = item.jibunAddress || '';
  const englishAddress = item.englishAddress || '';

  return {
    provider: 'naver_maps',
    providerPlaceId: roadAddress || jibunAddress || englishAddress || null,
    name: roadAddress || jibunAddress || englishAddress || '',
    category: '주소',
    categoryCode: 'ADDRESS',
    address: jibunAddress,
    roadAddress,
    phone: '',
    placeUrl: '',
    latitude: Number.isFinite(lat) ? lat : null,
    longitude: Number.isFinite(lng) ? lng : null,
    distanceMeters: null,
  };
}

export function stripHtml(value) {
  return String(value)
    .replace(/<[^>]*>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .trim();
}

export function mergePlaces(places, limit) {
  const seen = new Set();
  const merged = [];

  for (const place of places) {
    if (!place.name || place.latitude == null || place.longitude == null) {
      continue;
    }

    const key = [
      place.name.replace(/\s+/g, '').toLowerCase(),
      Math.round(place.latitude * 1000),
      Math.round(place.longitude * 1000),
    ].join(':');

    if (seen.has(key)) continue;
    seen.add(key);
    merged.push(place);
    if (merged.length >= limit) break;
  }

  return merged;
}

export function distanceMetersBetween(origin, place) {
  if (
    !Number.isFinite(origin?.latitude) ||
    !Number.isFinite(origin?.longitude) ||
    !Number.isFinite(place?.latitude) ||
    !Number.isFinite(place?.longitude)
  ) {
    return null;
  }

  const radiusMeters = 6371000;
  const toRadians = (value) => (value * Math.PI) / 180;
  const dLat = toRadians(place.latitude - origin.latitude);
  const dLng = toRadians(place.longitude - origin.longitude);
  const lat1 = toRadians(origin.latitude);
  const lat2 = toRadians(place.latitude);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(radiusMeters * c);
}

export function rankPlacesByDistance(places, latitude, longitude) {
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return places;
  }

  const origin = { latitude, longitude };
  return places
    .map((place, index) => ({
      ...place,
      distanceMeters:
        Number.isFinite(place.distanceMeters) && place.distanceMeters >= 0
          ? Math.round(place.distanceMeters)
          : distanceMetersBetween(origin, place),
      _index: index,
    }))
    .sort((a, b) => {
      const aDistance = Number.isFinite(a.distanceMeters) ? a.distanceMeters : Infinity;
      const bDistance = Number.isFinite(b.distanceMeters) ? b.distanceMeters : Infinity;
      if (aDistance !== bDistance) return aDistance - bDistance;
      return a._index - b._index;
    })
    .map(({ _index, ...place }) => place);
}

export function buildNaverQueries(query, regionHints = []) {
  const normalizedQuery = String(query || '').trim();
  const cleanedHints = regionHints
    .map((hint) => String(hint || '').trim())
    .filter((hint) => hint.length >= 2 && !normalizedQuery.includes(hint));
  const queries = [normalizedQuery];

  for (const hint of cleanedHints) {
    queries.push(`${hint} ${normalizedQuery}`);
  }

  return [...new Set(queries)].filter(Boolean).slice(0, 4);
}

export function normalizeNaverReverseGeocodeRegion(data) {
  const results = Array.isArray(data?.results) ? data.results : [];
  const hints = [];

  for (const result of results) {
    const region = result.region || {};
    for (const key of ['area4', 'area3', 'area2', 'area1']) {
      const name = region[key]?.name;
      if (name) hints.push(name);
    }
  }

  return uniqueRegionHints(hints);
}

export function normalizeNominatimRegionHints(data) {
  const address = data?.address || {};
  return uniqueRegionHints([
    address.neighbourhood,
    address.quarter,
    address.suburb,
    address.borough,
    address.city,
    address.town,
    address.village,
  ]);
}

export async function searchPlaces({
  query,
  latitude,
  longitude,
  limit = 10,
  config,
  fetchImpl = fetch,
}) {
  const trimmedQuery = String(query || '').trim();
  if (!trimmedQuery) {
    return { places: [], providers: providerState(config) };
  }

  const providers = providerState(config);
  const results = [];
  const errors = {};
  let regionHints = [];

  if (providers.kakao.enabled) {
    try {
      const kakaoPlaces = await searchKakao({
        query: trimmedQuery,
        latitude,
        longitude,
        limit,
        apiKey: config.KAKAO_REST_API_KEY,
        fetchImpl,
      });
      results.push(...kakaoPlaces);
    } catch (err) {
      errors.kakao = err.message;
    }
  }

  if (providers.naver.enabled && results.length < limit) {
    try {
      regionHints = await resolveRegionHints({
        latitude,
        longitude,
        config,
        fetchImpl,
      });
      const naverPlaces = await searchNaver({
        query: trimmedQuery,
        regionHints,
        limit: Math.max(limit - results.length, 1),
        clientId: config.NAVER_SEARCH_CLIENT_ID,
        clientSecret: config.NAVER_SEARCH_CLIENT_SECRET,
        fetchImpl,
      });
      results.push(...naverPlaces);
    } catch (err) {
      errors.naver = err.message;
    }
  }

  if (providers.naverMaps.enabled && results.length < limit) {
    try {
      const geocodePlaces = await searchNaverGeocode({
        query: trimmedQuery,
        limit: Math.max(limit - results.length, 1),
        clientId: config.NAVER_MAPS_CLIENT_ID,
        clientSecret: config.NAVER_MAPS_CLIENT_SECRET,
        fetchImpl,
      });
      results.push(...geocodePlaces);
    } catch (err) {
      errors.naverMaps = err.message;
    }
  }

  return {
    places: mergePlaces(rankPlacesByDistance(results, latitude, longitude), limit),
    providers,
    regionHints,
    errors,
  };
}

export function providerState(config) {
  return {
    kakao: { enabled: Boolean(config.KAKAO_REST_API_KEY) },
    naver: {
      enabled: Boolean(config.NAVER_SEARCH_CLIENT_ID && config.NAVER_SEARCH_CLIENT_SECRET),
    },
    naverMaps: {
      enabled: Boolean(config.NAVER_MAPS_CLIENT_ID && config.NAVER_MAPS_CLIENT_SECRET),
    },
  };
}

async function searchKakao({ query, latitude, longitude, limit, apiKey, fetchImpl }) {
  const url = new URL(KAKAO_SEARCH_URL);
  url.searchParams.set('query', query);
  url.searchParams.set('size', String(Math.min(Math.max(limit, 1), 15)));
  if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
    url.searchParams.set('y', String(latitude));
    url.searchParams.set('x', String(longitude));
    url.searchParams.set('sort', 'distance');
  }

  const res = await fetchImpl(url, {
    headers: { Authorization: `KakaoAK ${apiKey}` },
  });

  if (!res.ok) {
    throw new Error(`kakao_search_failed:${res.status}`);
  }

  const data = await res.json();
  return Array.isArray(data.documents) ? data.documents.map(normalizeKakaoPlace) : [];
}

async function searchNaver({ query, regionHints, limit, clientId, clientSecret, fetchImpl }) {
  const queries = buildNaverQueries(query, regionHints);
  const display = String(Math.min(Math.max(limit, 1), 5));

  const responses = await Promise.all(
    queries.map(async (naverQuery) => {
      const url = new URL(NAVER_SEARCH_URL);
      url.searchParams.set('query', naverQuery);
      url.searchParams.set('display', display);
      url.searchParams.set('sort', 'random');

      const res = await fetchImpl(url, {
        headers: {
          'X-NCP-APIGW-API-KEY-ID': clientId,
          'X-NCP-APIGW-API-KEY': clientSecret,
        },
      });

      if (!res.ok) {
        throw new Error(`naver_search_failed:${res.status}`);
      }

      return res.json();
    }),
  );

  return responses.flatMap((data) =>
    Array.isArray(data.items) ? data.items.map(normalizeNaverPlace) : [],
  );
}

async function resolveRegionHints({ latitude, longitude, config, fetchImpl }) {
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return [];

  const cacheKey = `${latitude.toFixed(2)},${longitude.toFixed(2)}`;
  if (regionHintCache.has(cacheKey)) return regionHintCache.get(cacheKey);

  const hints = config.NAVER_MAPS_CLIENT_ID && config.NAVER_MAPS_CLIENT_SECRET
    ? await reverseGeocodeNaverMaps({ latitude, longitude, config, fetchImpl }).catch(() => [])
    : [];
  const resolvedHints = hints.length > 0
    ? hints
    : await reverseGeocodeNominatim({ latitude, longitude, fetchImpl }).catch(() => []);

  regionHintCache.set(cacheKey, resolvedHints);
  return resolvedHints;
}

async function reverseGeocodeNaverMaps({ latitude, longitude, config, fetchImpl }) {
  const url = new URL(NAVER_REVERSE_GEOCODE_URL);
  url.searchParams.set('coords', `${longitude},${latitude}`);
  url.searchParams.set('orders', 'legalcode,admcode,addr,roadaddr');
  url.searchParams.set('output', 'json');

  const res = await fetchImpl(url, {
    headers: {
      'X-NCP-APIGW-API-KEY-ID': config.NAVER_MAPS_CLIENT_ID,
      'X-NCP-APIGW-API-KEY': config.NAVER_MAPS_CLIENT_SECRET,
    },
  });

  if (!res.ok) {
    throw new Error(`naver_reverse_geocode_failed:${res.status}`);
  }

  return normalizeNaverReverseGeocodeRegion(await res.json());
}

async function reverseGeocodeNominatim({ latitude, longitude, fetchImpl }) {
  const url = new URL(NOMINATIM_REVERSE_URL);
  url.searchParams.set('lat', String(latitude));
  url.searchParams.set('lon', String(longitude));
  url.searchParams.set('format', 'jsonv2');
  url.searchParams.set('accept-language', 'ko');

  const res = await fetchImpl(url, {
    headers: { 'User-Agent': 'SecretBase/1.0 (https://secertbase.kro.kr)' },
  });

  if (!res.ok) {
    throw new Error(`nominatim_reverse_failed:${res.status}`);
  }

  return normalizeNominatimRegionHints(await res.json());
}

function uniqueRegionHints(values) {
  return [...new Set(
    values
      .map((value) => String(value || '').trim())
      .filter((value) => value.length >= 2),
  )].slice(0, 4);
}

async function searchNaverGeocode({ query, limit, clientId, clientSecret, fetchImpl }) {
  const url = new URL(NAVER_GEOCODE_URL);
  url.searchParams.set('query', query);
  url.searchParams.set('count', String(Math.min(Math.max(limit, 1), 10)));

  const res = await fetchImpl(url, {
    headers: {
      'X-NCP-APIGW-API-KEY-ID': clientId,
      'X-NCP-APIGW-API-KEY': clientSecret,
    },
  });

  if (!res.ok) {
    throw new Error(`naver_geocode_failed:${res.status}`);
  }

  const data = await res.json();
  return Array.isArray(data.addresses)
    ? data.addresses.map(normalizeNaverGeocodeAddress)
    : [];
}
