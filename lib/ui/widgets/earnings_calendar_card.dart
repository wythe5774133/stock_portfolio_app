// 財報行事曆元件：總覽的「近期財報」卡片、當天／隔天財報提醒橫幅、
// 列表代號旁的財報標籤，以及匯出 .ics 行事曆的流程。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../database/app_database.dart' show WatchlistSymbol;
import '../../models/earnings_event.dart';
import '../../services/earnings_calendar_service.dart';
import '../../services/platform_io/backup_saver_io.dart'
    if (dart.library.js_interop) '../../services/platform_io/backup_saver_web.dart';
import '../dashboard_controller.dart';
import '../stock_detail_page.dart';
import '../theme/app_theme.dart';
import 'section_card.dart';

/// 財報標籤一般色（藍）
const Color EARNINGS_ACCENT_COLOR = Color(0xFF4F6DF5);

/// 今天／明天的財報標籤色（琥珀）
const Color EARNINGS_URGENT_COLOR = Color(0xFFF59E0B);

/*
 * @author  Toby
 *
 * @date    2026/09/30
 *
 * @class   EarningsCalendarCard
 *
 * @brief   總覽「近期財報」卡片：列出持股與自選股 14 天內的財報事件，
 *          右上角可匯出 90 天內的事件為 .ics 行事曆檔。
 *
 * @note    沒有持股也沒有自選時不顯示（回傳空元件）。
 */
class EarningsCalendarCard extends StatelessWidget {
  final DashboardController controller;

  const EarningsCalendarCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.GetEarningsTrackedSymbols().isEmpty) {
      return const SizedBox.shrink();
    }
    final AppColors colors = AppColors.Of(context);
    final List<EarningsEvent> events = controller.GetUpcomingEarningsEvents();
    final int today_date = controller.GetTodayTaipeiDate();

    return SectionCard(
      title: '近期財報',
      subtitle: '持股與自選・${DashboardController.EARNINGS_HORIZON_DAYS} 天內',
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      title_padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      trailing: TextButton.icon(
        onPressed: () => ExportEarningsCalendar(context, controller),
        icon: const Icon(Icons.event_available, size: 16),
        label: const Text('加入行事曆', style: TextStyle(fontSize: 13)),
      ),
      child: events.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text(
                '未來 ${DashboardController.EARNINGS_HORIZON_DAYS} 天沒有財報',
                style: TextStyle(fontSize: 13, color: colors.text_muted),
              ),
            )
          : Column(
              children: <Widget>[
                for (final EarningsEvent event in events)
                  _BuildEventRow(context, colors, event, today_date),
              ],
            ),
    );
  }

  /// 單一事件列：代號＋事件名稱／時間說明，右側為倒數標籤；點擊進入個股詳情。
  Widget _BuildEventRow(
    BuildContext context,
    AppColors colors,
    EarningsEvent event,
    int today_date,
  ) {
    final int days =
        EarningsCalendarService.CalculateDaysUntil(event, today_date);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => StockDetailPage.Open(
        context,
        controller,
        event.symbol,
        ResolveDisplayName(controller, event.symbol),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${event.symbol}　${event.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    EarningsCalendarService.FormatEventWhenText(event),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.text_muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            EarningsCountdownChip(days: days),
          ],
        ),
      ),
    );
  }

  /// 代號的顯示名稱：優先取自選清單的名稱，否則用代號本身。
  static String ResolveDisplayName(
    DashboardController controller,
    String symbol,
  ) {
    for (final WatchlistSymbol entry in controller.watchlist) {
      if (entry.symbol == symbol) {
        return entry.name;
      }
    }
    return symbol;
  }
}

/*
 *  @fn      Future<void> ExportEarningsCalendar(BuildContext context, DashboardController controller)
 *
 *  @brief   ( 匯出 90 天內的財報事件為 .ics：手機開分享面板、桌面存檔、網頁下載 )
 *
 *  @param   context - 顯示結果提示用
 *  @param   controller - 儀表板控制器
 *
 *  @return  None
 */
Future<void> ExportEarningsCalendar(
  BuildContext context,
  DashboardController controller,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  if (controller
      .GetUpcomingEarningsEvents(days: DashboardController.EARNINGS_EXPORT_DAYS)
      .isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('未來 90 天沒有可匯出的財報事件')),
    );
    return;
  }
  try {
    final String file_name = 'earnings_'
        '${DateFormat('yyyyMMdd').format(DateTime.now())}.ics';
    final bool completed = await SaveCalendarToDevice(
      controller.BuildEarningsCalendarIcs(),
      file_name,
    );
    if (completed) {
      messenger.showSnackBar(
        const SnackBar(content: Text('已匯出行事曆檔，開啟後即可加入行事曆')),
      );
    }
  } catch (error) {
    messenger.showSnackBar(SnackBar(
      content: Text('匯出失敗：$error'),
      backgroundColor: const Color(0xFFDC2626),
    ));
  }
}

/*
 * @author  Toby
 *
 * @date    2026/09/30
 *
 * @class   EarningsReminderBanner
 *
 * @brief   總覽頂端提醒：今天或明天（台灣時間）有財報時顯示，列出代號與時間。
 *
 * @note    沒有符合的事件時回傳空元件；台股月營收不列入提醒。
 */
class EarningsReminderBanner extends StatelessWidget {
  final DashboardController controller;

  const EarningsReminderBanner({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final int today_date = controller.GetTodayTaipeiDate();
    final List<EarningsEvent> events = controller
        .GetUpcomingEarningsEvents(days: 1)
        .where((EarningsEvent e) =>
            e.kind != EarningsEventKind.tw_monthly_revenue &&
            EarningsCalendarService.CalculateDaysUntil(e, today_date) <= 1)
        .toList();
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }
    final AppColors colors = AppColors.Of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: EARNINGS_URGENT_COLOR.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: EARNINGS_URGENT_COLOR.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.campaign_outlined,
                  size: 18, color: EARNINGS_URGENT_COLOR),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final EarningsEvent event in events)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        '${EarningsCalendarService.FormatDaysUntilText(EarningsCalendarService.CalculateDaysUntil(event, today_date))}'
                        '　${event.symbol} ${event.label}　'
                        '${EarningsCalendarService.FormatEventWhenText(event)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.text_primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/*
 * @author  Toby
 *
 * @date    2026/09/30
 *
 * @class   EarningsCountdownChip
 *
 * @brief   倒數標籤：今天／明天／N 天後，今天與明天用琥珀色。
 */
class EarningsCountdownChip extends StatelessWidget {
  final int days; // 距今天數
  final String? prefix; // 前綴文字（例：「財報」）

  const EarningsCountdownChip({super.key, required this.days, this.prefix});

  @override
  Widget build(BuildContext context) {
    final Color color =
        days <= 1 ? EARNINGS_URGENT_COLOR : EARNINGS_ACCENT_COLOR;
    final String text = EarningsCalendarService.FormatDaysUntilText(days);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        prefix == null ? text : '$prefix $text',
        maxLines: 1,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/*
 *  @fn      Widget? BuildEarningsBadge(DashboardController controller, String symbol)
 *
 *  @brief   ( 列表代號旁的財報標籤：7 天內有財報才回傳 )
 *
 *  @param   controller - 儀表板控制器
 *  @param   symbol - 股票代號
 *
 *  @return  標籤元件；沒有近期財報回傳 null
 */
Widget? BuildEarningsBadge(DashboardController controller, String symbol) {
  final EarningsEvent? event = controller.GetEarningsBadgeEvent(symbol);
  if (event == null) {
    return null;
  }
  return EarningsCountdownChip(
    days: EarningsCalendarService.CalculateDaysUntil(
      event,
      controller.GetTodayTaipeiDate(),
    ),
    prefix: '財報',
  );
}
