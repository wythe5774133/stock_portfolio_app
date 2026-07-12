// Yahoo Finance CORS 代理（Cloudflare Worker）
// 路徑格式：/{yahoo主機}/{原始路徑}?原始查詢參數
// 僅允許轉發到 Yahoo 的報價相關主機，避免被當成開放代理濫用。

const ALLOWED_HOSTS = new Set([
  'query1.finance.yahoo.com',
  'query2.finance.yahoo.com',
]);

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const segments = url.pathname.split('/').filter(Boolean);
    const target_host = segments[0];

    if (!target_host || !ALLOWED_HOSTS.has(target_host)) {
      return new Response('Not found', { status: 404 });
    }

    const target_url =
      'https://' + target_host + '/' + segments.slice(1).join('/') + url.search;

    const upstream = await fetch(target_url, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
          '(KHTML, like Gecko) Chrome/126.0 Safari/537.36',
      },
      cf: { cacheTtl: 15, cacheEverything: true }, // 15 秒快取，減少對 Yahoo 的請求量
    });

    const response = new Response(upstream.body, upstream);
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET');
    return response;
  },
};
