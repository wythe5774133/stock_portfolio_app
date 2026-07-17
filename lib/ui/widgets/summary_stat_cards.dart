// 儀表板統計卡片：桌面單列等高卡片；手機為「總資產 hero 卡＋2 欄等高小卡」。
// 所有卡片保留副標列（無副標補空白），確保高度一致不參差。

import 'package:flutter/material.dart';

import '../money_format.dart';
import '../theme/app_theme.dart';
import '../theme/profit_color_scheme.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   SummaryStatCards
 *
 * @brief   總資產（含今日損益）、總成本、未實現/已實現損益、
 *          累計股息（可隱藏）、XIRR。窄螢幕採 hero＋格狀排版。
 */
class SummaryStatCards extends StatelessWidget {
  static const double MOBILE_BREAKPOINT = 700;

  final double total_market_value;
  final double total_cost_basis;
  final double total_unrealized_pnl;
  final double total_unrealized_pnl_percent;
  final double total_realized_pnl;
  final double total_day_pnl;
  final double total_day_change_percent;
  final double total_dividend_income;
  final double? portfolio_xirr; // null = 資料不足
  final bool show_dividend_card; // 股息追蹤關閉時隱藏股息卡片
  final String display_currency; // 聚合金額的顯示幣別（display_currency_effective）
  final ProfitColorScheme profit_colors;

  const SummaryStatCards({
    super.key,
    required this.total_market_value,
    required this.total_cost_basis,
    required this.total_unrealized_pnl,
    required this.total_unrealized_pnl_percent,
    required this.total_realized_pnl,
    required this.total_day_pnl,
    required this.total_day_change_percent,
    required this.total_dividend_income,
    required this.portfolio_xirr,
    required this.show_dividend_card,
    required this.display_currency,
    required this.profit_colors,
  });

  /// 浮點殘值歸零：|值| < 0.005 視為 0，避免顯示「−$0.00」這種負零。
  static double NormalizeTinyValue(double value) {
    return value.abs() < 0.005 ? 0.0 : value;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.Of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool is_mobile = constraints.maxWidth < MOBILE_BREAKPOINT;
        return is_mobile
            ? _BuildMobileLayout(colors, constraints.maxWidth)
            : _BuildDesktopLayout(colors, constraints.maxWidth);
      },
    );
  }

  /// 手機版面：總資產 hero 卡置頂，其餘 2 欄等高小卡。
  Widget _BuildMobileLayout(AppColors colors, double max_width) {
    final double small_width = (max_width - 10) / 2;
    final List<Widget> small_cards = _BuildSmallCards(
      colors: colors,
      width: small_width,
      height: 92,
      value_font_size: 18,
    );
    return Column(
      children: <Widget>[
        _BuildHeroCard(colors),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: small_cards),
      ],
    );
  }

  /// 桌面版面：單列等高卡片（含總資產）。
  Widget _BuildDesktopLayout(AppColors colors, double max_width) {
    final int card_count = show_dividend_card ? 6 : 5;
    final double card_width = max_width >= 1080
        ? (max_width - (card_count - 1) * 12) / card_count
        : (max_width - 2 * 12) / 3;
    final double day_pnl = NormalizeTinyValue(total_day_pnl);
    final double day_percent = NormalizeTinyValue(total_day_change_percent);
    final String day_sign = day_pnl >= 0 ? '+' : '';

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _BuildStatCard(
          colors: colors,
          width: card_width,
          height: 104,
          value_font_size: 21,
          title: '總資產',
          value: FormatMoney(total_market_value, display_currency),
          subtitle: '今日 $day_sign${FormatMoney(day_pnl, display_currency)}'
              '（$day_sign${day_percent.toStringAsFixed(2)}%）',
          subtitle_color: profit_colors.ResolveColorForValue(day_pnl),
        ),
        ..._BuildSmallCards(
          colors: colors,
          width: card_width,
          height: 104,
          value_font_size: 21,
        ),
      ],
    );
  }

  /// 手機置頂 hero 卡：大字總資產＋今日損益。
  Widget _BuildHeroCard(AppColors colors) {
    final double day_pnl = NormalizeTinyValue(total_day_pnl);
    final double day_percent = NormalizeTinyValue(total_day_change_percent);
    final String day_sign = day_pnl >= 0 ? '+' : '';
    final Color day_color = profit_colors.ResolveColorForValue(day_pnl);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: colors.card_background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.card_border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('總資產',
              style: TextStyle(fontSize: 13, color: colors.text_secondary)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              FormatMoney(total_market_value, display_currency),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: colors.text_primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: day_color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '今日 $day_sign${FormatMoney(day_pnl, display_currency)}　'
                  '$day_sign${day_percent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: day_color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 總成本/未實現/已實現/(股息)/XIRR 小卡清單。
  List<Widget> _BuildSmallCards({
    required AppColors colors,
    required double width,
    required double height,
    required double value_font_size,
  }) {
    final double unrealized = NormalizeTinyValue(total_unrealized_pnl);
    final double unrealized_percent =
        NormalizeTinyValue(total_unrealized_pnl_percent);
    final double realized = NormalizeTinyValue(total_realized_pnl);
    final String unrealized_sign = unrealized >= 0 ? '+' : '';
    final String realized_sign = realized >= 0 ? '+' : '';

    return <Widget>[
      _BuildStatCard(
        colors: colors,
        width: width,
        height: height,
        value_font_size: value_font_size,
        title: '總成本',
        value: FormatMoney(total_cost_basis, display_currency),
        subtitle: '投入本金',
      ),
      _BuildStatCard(
        colors: colors,
        width: width,
        height: height,
        value_font_size: value_font_size,
        title: '未實現損益',
        value: '$unrealized_sign${FormatMoney(unrealized, display_currency)}',
        subtitle: '$unrealized_sign${unrealized_percent.toStringAsFixed(2)}%',
        value_color: profit_colors.ResolveColorForValue(unrealized),
        subtitle_color: profit_colors.ResolveColorForValue(unrealized),
      ),
      _BuildStatCard(
        colors: colors,
        width: width,
        height: height,
        value_font_size: value_font_size,
        title: '已實現損益',
        value: '$realized_sign${FormatMoney(realized, display_currency)}',
        subtitle: '含已清倉',
        value_color: profit_colors.ResolveColorForValue(realized),
      ),
      if (show_dividend_card)
        _BuildStatCard(
          colors: colors,
          width: width,
          height: height,
          value_font_size: value_font_size,
          title: '累計股息',
          value: FormatMoney(total_dividend_income, display_currency),
          subtitle: '依除息日持股計算',
        ),
      _BuildStatCard(
        colors: colors,
        width: width,
        height: height,
        value_font_size: value_font_size,
        title: '年化報酬率 XIRR',
        value: portfolio_xirr != null
            ? '${portfolio_xirr! >= 0 ? '+' : ''}'
                '${(portfolio_xirr! * 100).toStringAsFixed(2)}%'
            : '—',
        subtitle: show_dividend_card ? '資金加權・含股息' : '資金加權',
        value_color: portfolio_xirr != null
            ? profit_colors.ResolveColorForValue(portfolio_xirr!)
            : null,
      ),
    ];
  }

  /// 單張統計卡片（固定高度，副標永遠佔位，確保整排等高對齊）。
  Widget _BuildStatCard({
    required AppColors colors,
    required double width,
    required double height,
    required double value_font_size,
    required String title,
    required String value,
    required String subtitle,
    Color? value_color,
    Color? subtitle_color,
  }) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: colors.card_background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.card_border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: colors.text_secondary),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: value_font_size,
                fontWeight: FontWeight.w700,
                color: value_color ?? colors.text_primary,
                letterSpacing: -0.4,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: subtitle_color ?? colors.text_muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
