import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';

/// Локализованное наименование месяца по его номеру: 1 — январь.
///
/// Наименования месяцев берутся из строк приложения, поэтому подпись периода и
/// строки помесячного тренда совпадают в обеих локалях.
String analyticsMonthName(AppLocalizations localizations, int month) =>
    switch (month) {
      1 => localizations.analyticsMonthNameJanuary,
      2 => localizations.analyticsMonthNameFebruary,
      3 => localizations.analyticsMonthNameMarch,
      4 => localizations.analyticsMonthNameApril,
      5 => localizations.analyticsMonthNameMay,
      6 => localizations.analyticsMonthNameJune,
      7 => localizations.analyticsMonthNameJuly,
      8 => localizations.analyticsMonthNameAugust,
      9 => localizations.analyticsMonthNameSeptember,
      10 => localizations.analyticsMonthNameOctober,
      11 => localizations.analyticsMonthNameNovember,
      12 => localizations.analyticsMonthNameDecember,
      _ => throw ArgumentError.value(
        month,
        'month',
        'Месяц должен быть в диапазоне 1..12.',
      ),
    };

/// Локализованная подпись периода: «Сентябрь 2026» или «2026».
String analyticsPeriodLabel(
  AppLocalizations localizations,
  AnalyticsPeriod period,
) => switch (period.mode) {
  AnalyticsPeriodMode.month => localizations.analyticsPeriodMonthLabel(
    analyticsMonthName(localizations, period.month!),
    period.year,
  ),
  AnalyticsPeriodMode.year => localizations.analyticsPeriodYearLabel(
    period.year,
  ),
};
