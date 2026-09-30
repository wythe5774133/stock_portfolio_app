// Yahoo 端點組裝：原生平台直連 Yahoo，網頁版改走 CORS 代理
// （瀏覽器的同源政策擋掉直連，由 Cloudflare Worker 轉發）。

import 'package:flutter/foundation.dart' show kIsWeb;

/// 網頁版的代理位址：建置時以 --dart-define=YAHOO_PROXY=... 指定，
/// 開發時可指向本機代理。
const String WEB_PROXY_BASE = String.fromEnvironment(
  'YAHOO_PROXY',
  defaultValue: 'https://stock-yahoo-proxy.toby680528.workers.dev',
);

/// 組出 Yahoo 請求 URI：原生直連、網頁走代理（路徑格式 /{host}{path}?query）。
Uri BuildYahooUri(String host, String path, Map<String, String> params) {
  if (kIsWeb) {
    return Uri.parse('$WEB_PROXY_BASE/$host$path')
        .replace(queryParameters: params);
  }
  return Uri.https(host, path, params);
}

/// 網頁版財報日期端點：由 Worker 代為取得 cookie＋crumb 後查詢 v7 報價。
Uri BuildEarningsProxyUri(List<String> symbols) {
  return Uri.parse('$WEB_PROXY_BASE/earnings')
      .replace(queryParameters: <String, String>{'symbols': symbols.join(',')});
}

/// 請求標頭：瀏覽器禁止自訂 User-Agent（會自帶），原生平台才需要。
Map<String, String> BuildYahooHeaders(String user_agent,
    {String? cookie_header}) {
  if (kIsWeb) {
    return <String, String>{};
  }
  return <String, String>{
    'User-Agent': user_agent,
    'Cookie': ?cookie_header,
  };
}
