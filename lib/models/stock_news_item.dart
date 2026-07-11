// 個股新聞的單筆資料。

/*
 * @author  Toby
 *
 * @date    2026/07/12
 *
 * @class   StockNewsItem
 *
 * @brief   Yahoo 搜尋端點附帶的新聞：標題、來源、連結與發布時間。
 */
class StockNewsItem {
  final String title;
  final String publisher; // 新聞來源（Reuters、Bloomberg...）
  final String link; // 原文連結
  final DateTime? published_at; // 發布時間（可能缺）

  const StockNewsItem({
    required this.title,
    required this.publisher,
    required this.link,
    this.published_at,
  });

  @override
  String toString() => 'StockNewsItem($title, $publisher)';
}
