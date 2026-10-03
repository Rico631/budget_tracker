/// Модели аналитики: периоды, фильтры и срезы по потокам операций.
library;

import 'package:budget_tracker/domain/models/finance_category.dart';
import 'package:budget_tracker/domain/models/finance_currency.dart';
import 'package:budget_tracker/domain/models/finance_transaction.dart';

/// Режим периода аналитики: месяц или год.
enum AnalyticsPeriodMode { month, year }

/// Период среза аналитики.
///
/// Период задается полуоткрытым интервалом по локальному календарю устройства:
/// месяц — `[первое число, первое число следующего месяца)`, год —
/// `[1 января, 1 января следующего года)`. Поэтому полночь не попадает сразу в
/// два соседних периода. В режиме [AnalyticsPeriodMode.year] месяц не задан:
/// год описывается только номером.
class AnalyticsPeriod {
  const AnalyticsPeriod({required this.mode, required this.year, this.month});

  /// Период-месяц [month] года [year]; [month] задается от 1 до 12.
  factory AnalyticsPeriod.month({required int year, required int month}) {
    assert(month >= 1 && month <= 12, 'Месяц должен быть в диапазоне 1..12.');
    return AnalyticsPeriod(
      mode: AnalyticsPeriodMode.month,
      year: year,
      month: month,
    );
  }

  /// Период-год [year].
  factory AnalyticsPeriod.year(int year) =>
      AnalyticsPeriod(mode: AnalyticsPeriodMode.year, year: year);

  final AnalyticsPeriodMode mode;
  final int year;

  /// Номер месяца от 1 до 12; `null` в режиме «Год».
  final int? month;

  /// Хронологический порядок периодов: от раннего периода к позднему.
  ///
  /// Периоды разных режимов сравниваются по началу интервала, поэтому год идет
  /// перед своим январем: год начинается в тот же день, но заканчивается позже.
  int compareTo(AnalyticsPeriod other) {
    final byStart = _startSlot.compareTo(other._startSlot);
    if (byStart != 0) {
      return byStart;
    }
    if (mode == other.mode) {
      return 0;
    }
    return mode == AnalyticsPeriodMode.year ? 1 : -1;
  }

  /// Первый месяц периода: январь для года и [month] для месяца.
  int get _startSlot => year * 12 + (month ?? 1);

  @override
  bool operator ==(Object other) =>
      other is AnalyticsPeriod &&
      other.mode == mode &&
      other.year == year &&
      other.month == month;

  @override
  int get hashCode => Object.hash(mode, year, month);

  @override
  String toString() => switch (mode) {
    AnalyticsPeriodMode.month => 'AnalyticsPeriod.month($year, $month)',
    AnalyticsPeriodMode.year => 'AnalyticsPeriod.year($year)',
  };
}

/// Фильтр по счетам аналитики: набор выбранных счетов.
///
/// Пустой набор означает значение «Все счета» и не сужает срез. Набор сравнивается
/// по составу, а не по порядку, поэтому один и тот же фильтр дает одно значение
/// ключа провайдеров: срез не пересчитывается при повторном выборе тех же счетов.
class AnalyticsAccountFilter {
  const AnalyticsAccountFilter(this.accountIds);

  /// Значение фильтра по умолчанию: «Все счета».
  static const AnalyticsAccountFilter all = AnalyticsAccountFilter(<String>{});

  /// Фильтр по набору счетов [accountIds] с независимой копией набора.
  factory AnalyticsAccountFilter.of(Iterable<String> accountIds) =>
      AnalyticsAccountFilter(Set.unmodifiable(accountIds));

  /// Идентификаторы выбранных счетов; пустой набор — «Все счета».
  final Set<String> accountIds;

  /// Фильтр не сужает срез: выбраны все счета книги.
  bool get isEmpty => accountIds.isEmpty;

  /// Фильтр сужает срез до выбранных счетов.
  bool get isNotEmpty => accountIds.isNotEmpty;

  /// Входит ли счет в фильтр; пустой фильтр пропускает все счета книги.
  bool contains(String accountId) =>
      accountIds.isEmpty || accountIds.contains(accountId);

  @override
  bool operator ==(Object other) =>
      other is AnalyticsAccountFilter &&
      other.accountIds.length == accountIds.length &&
      other.accountIds.containsAll(accountIds);

  @override
  int get hashCode => Object.hashAllUnordered(accountIds);

  @override
  String toString() => 'AnalyticsAccountFilter(${accountIds.join(', ')})';
}

/// Сумма одной категории за период в валюте валютного блока.
class AnalyticsCategoryTotal {
  AnalyticsCategoryTotal({required this.category, required this.amountMinor});

  final FinanceCategory category;

  /// Сумма операций категории в минорных единицах валюты блока.
  final int amountMinor;
}

/// Сумма выбранного потока за месяц года в валюте валютного блока.
class AnalyticsMonthTotal {
  AnalyticsMonthTotal({required this.month, required this.amountMinor});

  /// Номер месяца от 1 до 12.
  final int month;

  /// Сумма операций месяца в минорных единицах валюты блока; у месяца без
  /// операций величина нулевая, потому что ось года непрерывна.
  final int amountMinor;
}

/// Валютный блок аналитики: суммы одного потока в одной валюте.
///
/// Суммы разных валют не складываются и не конвертируются (ADR-0001, решение
/// 2.1), поэтому у каждой валюты собственный блок и собственный итог. Форму
/// блока задает режим периода: в месячном срезе заполнены [categories], в
/// годовом тренде — [months]; незаполненный список пуст.
class AnalyticsCurrencyBlock {
  AnalyticsCurrencyBlock({
    required this.currencyCode,
    required this.totalMinor,
    this.currency,
    this.categories = const [],
    this.months = const [],
  });

  /// Валюта блока — валюта счетов, по которым построены суммы.
  final String currencyCode;

  /// Позиция справочника валют; отсутствует, если код не найден в справочнике.
  final FinanceCurrency? currency;

  /// Итог блока: сумма категорийных сумм месяца или сумма месячных величин года.
  final int totalMinor;

  /// Категорийные суммы месячного среза, по убыванию суммы.
  final List<AnalyticsCategoryTotal> categories;

  /// Двенадцать месячных величин года в календарном порядке.
  final List<AnalyticsMonthTotal> months;
}

/// Месячный срез аналитики: выбранный поток, сгруппированный по валютам.
class AnalyticsSlice {
  AnalyticsSlice({
    required this.period,
    required this.stream,
    required this.blocks,
  });

  /// Выбранный период; в месячном срезе его режим — [AnalyticsPeriodMode.month].
  final AnalyticsPeriod period;

  /// Выбранный поток: только `income` или `expense`.
  final TransactionKind stream;

  final List<AnalyticsCurrencyBlock> blocks;

  /// За период нет операций выбранного потока: пустой срез показывается
  /// состоянием отсутствия данных, а не нулевыми полосами и итогами.
  bool get isEmpty => blocks.isEmpty;

  /// За период есть хотя бы одна операция выбранного потока.
  bool get hasData => blocks.isNotEmpty;
}

/// Годовой обзор аналитики: помесячный тренд выбранного потока по валютам.
class AnalyticsYearTrend {
  AnalyticsYearTrend({
    required this.period,
    required this.stream,
    required this.blocks,
  });

  /// Выбранный период; в годовом обзоре его режим — [AnalyticsPeriodMode.year].
  final AnalyticsPeriod period;

  /// Выбранный поток: только `income` или `expense`.
  final TransactionKind stream;

  /// Валютные блоки с двенадцатью месячными величинами в каждом.
  final List<AnalyticsCurrencyBlock> blocks;

  /// За год нет операций выбранного потока.
  bool get isEmpty => blocks.isEmpty;

  /// За год есть хотя бы одна операция выбранного потока.
  bool get hasData => blocks.isNotEmpty;
}
