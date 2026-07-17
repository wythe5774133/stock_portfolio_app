// 共用金額格式化：依幣別加上正確符號，全專案金額顯示統一走此 helper。

import 'package:intl/intl.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/17
 *
 * @fn      String ResolveCurrencySymbol(String currency)
 *
 * @brief   ( 由 ISO 幣別碼取得顯示符號：USD → $，TWD → NT$ )
 *
 * @param   currency - 幣別碼（'USD' | 'TWD'）
 *
 * @return  對應的幣別符號；未知幣別退回 '$'
 *
 * @note    與 market_registry 的 currency_symbol 對應一致。
 */
String ResolveCurrencySymbol(String currency) {
  return currency == 'TWD' ? 'NT\$' : '\$';
}

/*
 *  @fn      String FormatMoney(double value, String currency, {bool compact})
 *
 *  @brief   ( 依幣別格式化金額：USD → $1,234.56；TWD → NT$1,234.56 )
 *
 *  @param   value    - 金額數值（已為目標幣別的原生數字）
 *  @param   currency - 幣別碼（'USD' | 'TWD'）
 *  @param   compact  - true 時採縮寫（$1.2K），供圖表軸／圖例節省空間
 *
 *  @return  含幣別符號的格式化字串
 *
 *  @note    內部使用 intl 的 NumberFormat.currency / compactCurrency，
 *           符號依幣別自動切換；不負責換算，換算請先經 controller。
 */
String FormatMoney(double value, String currency, {bool compact = false}) {
  final String symbol = ResolveCurrencySymbol(currency);
  final NumberFormat formatter = compact
      ? NumberFormat.compactCurrency(symbol: symbol)
      : NumberFormat.currency(symbol: symbol);
  return formatter.format(value);
}
