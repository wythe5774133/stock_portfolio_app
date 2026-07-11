// 通用區塊卡片：各分頁共用的標題＋內容卡片容器，深淺主題自動適應。

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   SectionCard
 *
 * @brief   標題（可含副標與右側元件）＋內容的圓角卡片。
 */
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets title_padding;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 20),
    this.title_padding = const EdgeInsets.fromLTRB(20, 18, 20, 14),
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.Of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.card_background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.card_border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: title_padding,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                              fontSize: 12, color: colors.text_muted),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
