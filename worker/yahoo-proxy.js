// Yahoo Finance CORS 代理（Cloudflare Worker）
// 路徑格式：/{yahoo主機}/{原始路徑}?原始查詢參數
// 僅允許轉發到 Yahoo 的報價相關主機，避免被當成開放代理濫用。
// 另提供 /earnings?symbols=A,B：由 Worker 取得 cookie＋crumb 後查詢 v7 財報日期欄位，
// 回應格式與 v7/finance/quote 相同。

const ALLOWED_HOSTS = new Set([
  'query1.finance.yahoo.com',
  'query2.finance.yahoo.com',
]);

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/126.0 Safari/537.36';

const EARNINGS_FIELDS =
  'symbol,earningsTimestamp,earningsTimestampStart,earningsTimestampEnd,isEarningsDateEstimate';
const EARNINGS_CACHE_MS = 6 * 60 * 60 * 1000; // 財報日期快取 6 小時
const SESSION_CACHE_MS = 30 * 60 * 1000; // cookie＋crumb 快取 30 分鐘
const MAX_EARNINGS_SYMBOLS = 100;

let yahoo_session = null; // { cookie, crumb, expires_at }
const earnings_cache = new Map(); // 代號組合 → { body, expires_at }

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const segments = url.pathname.split('/').filter(Boolean);

    if (segments[0] === 'earnings') {
      return WithCors(await HandleEarningsRequest(url));
    }

    const target_host = segments[0];
    if (!target_host || !ALLOWED_HOSTS.has(target_host)) {
      return new Response('Not found', { status: 404 });
    }

    const target_url =
      'https://' + target_host + '/' + segments.slice(1).join('/') + url.search;

    const upstream = await fetch(target_url, {
      headers: { 'User-Agent': USER_AGENT },
      cf: { cacheTtl: 15, cacheEverything: true }, // 15 秒快取，減少對 Yahoo 的請求量
    });

    return WithCors(new Response(upstream.body, upstream));
  },
};

/// 查詢財報日期：代號白名單格式檢查 → 記憶體快取 → cookie＋crumb → v7 quote。
async function HandleEarningsRequest(url) {
  const symbols = (url.searchParams.get('symbols') || '')
    .split(',')
    .map((s) => s.trim())
    .filter((s) => /^[A-Za-z0-9.\-]{1,15}$/.test(s))
    .slice(0, MAX_EARNINGS_SYMBOLS);
  if (symbols.length === 0) {
    return new Response('Bad request', { status: 400 });
  }

  const cache_key = [...symbols].sort().join(',');
  const cached = earnings_cache.get(cache_key);
  if (cached && cached.expires_at > Date.now()) {
    return BuildJsonResponse(cached.body);
  }

  const session = await GetYahooSession();
  if (!session) {
    return new Response('Upstream unavailable', { status: 502 });
  }

  const target_url =
    'https://query1.finance.yahoo.com/v7/finance/quote' +
    '?symbols=' + encodeURIComponent(symbols.join(',')) +
    '&fields=' + encodeURIComponent(EARNINGS_FIELDS) +
    '&crumb=' + encodeURIComponent(session.crumb);
  const upstream = await fetch(target_url, {
    headers: { 'User-Agent': USER_AGENT, Cookie: session.cookie },
  });
  if (upstream.status === 401 || upstream.status === 403) {
    yahoo_session = null; // crumb 失效，下次重取
  }
  if (!upstream.ok) {
    return new Response('Upstream error', { status: 502 });
  }

  const body = await upstream.text();
  earnings_cache.set(cache_key, { body, expires_at: Date.now() + EARNINGS_CACHE_MS });
  return BuildJsonResponse(body);
}

/// 取得（並快取）Yahoo 的 cookie 與 crumb；失敗回傳 null。
async function GetYahooSession() {
  if (yahoo_session && yahoo_session.expires_at > Date.now()) {
    return yahoo_session;
  }
  try {
    const cookie_response = await fetch('https://fc.yahoo.com/', {
      headers: { 'User-Agent': USER_AGENT },
      redirect: 'manual',
    });
    const set_cookies =
      typeof cookie_response.headers.getSetCookie === 'function'
        ? cookie_response.headers.getSetCookie()
        : [cookie_response.headers.get('set-cookie')].filter(Boolean);
    const cookie = set_cookies
      .map((c) => c.split(';')[0].trim())
      .filter((pair) => pair.includes('='))
      .join('; ');
    if (!cookie) {
      return null;
    }

    const crumb_response = await fetch(
      'https://query1.finance.yahoo.com/v1/test/getcrumb',
      { headers: { 'User-Agent': USER_AGENT, Cookie: cookie } },
    );
    const crumb = (await crumb_response.text()).trim();
    if (!crumb_response.ok || !crumb || /[\s<]/.test(crumb)) {
      return null;
    }
    yahoo_session = { cookie, crumb, expires_at: Date.now() + SESSION_CACHE_MS };
    return yahoo_session;
  } catch (_) {
    return null;
  }
}

/// JSON 回應（瀏覽器端快取 1 小時）。
function BuildJsonResponse(body) {
  return new Response(body, {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=3600',
    },
  });
}

/// 加上 CORS 標頭。
function WithCors(response) {
  const result = new Response(response.body, response);
  result.headers.set('Access-Control-Allow-Origin', '*');
  result.headers.set('Access-Control-Allow-Methods', 'GET');
  return result;
}
