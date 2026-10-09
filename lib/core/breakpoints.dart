import 'package:flutter/material.dart';

enum ScreenSize { compact, medium, expanded }

ScreenSize screenSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  // До 900 — карточки (таблица 5–6 колонок туда не влезает).
  if (width < 900) return ScreenSize.compact;
  // 900–1400 — компактная таблица.
  if (width < 1400) return ScreenSize.medium;
  // 1400+ — развёрнутая.
  return ScreenSize.expanded;
}

T byScreen<T>(
  BuildContext context, {
  required T compact,
  T? medium,
  T? expanded,
}) {
  return switch (screenSizeOf(context)) {
    ScreenSize.compact => compact,
    ScreenSize.medium => medium ?? compact,
    ScreenSize.expanded => expanded ?? medium ?? compact,
  };
}
