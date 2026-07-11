// 一筆股票交易紀錄的純資料類別（不依賴任何 Flutter widget）。

/// 交易類型：買入或賣出。
enum TransactionType {
  buy,
  sell,
}

/// 將字串（不分大小寫）解析為 TransactionType，無法解析回傳 null。
TransactionType? ParseTransactionType(String raw) {
  final String normalized = raw.trim().toUpperCase();
  switch (normalized) {
    case 'BUY':
      return TransactionType.buy;
    case 'SELL':
      return TransactionType.sell;
    default:
      return null;
  }
}

/// 將 TransactionType 轉回資料庫儲存字串（BUY/SELL）。
String FormatTransactionType(TransactionType type) {
  return type == TransactionType.buy ? 'BUY' : 'SELL';
}

/*
 * @author Toby
 * @date 2026/07/11
 * @class StockTransaction
 * @brief 單筆股票交易的不可變資料模型。
 * @note trade_date 使用 yyyyMMdd 整數格式（如 20260707），
 *       方便資料庫排序與唯一索引。
 */
class StockTransaction {
  final int? id; // 資料庫主鍵，尚未寫入時為 null
  final String symbol; // 股票代號
  final int trade_date; // 交易日期，yyyyMMdd 整數
  final double purchase_price; // 成交單價
  final double quantity; // 數量（可為碎股小數）
  final TransactionType transaction_type; // 買/賣
  final double? commission; // 手續費（可選）
  final String? comment; // 備註（可選）

  const StockTransaction({
    this.id,
    required this.symbol,
    required this.trade_date,
    required this.purchase_price,
    required this.quantity,
    required this.transaction_type,
    this.commission,
    this.comment,
  });

  @override
  String toString() {
    return 'StockTransaction($symbol, $trade_date, '
        '${FormatTransactionType(transaction_type)}, '
        'price=$purchase_price, qty=$quantity)';
  }
}
