import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/analytics_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime(2026, 10, 1, 12);

  FinanceAccount account({
    required String id,
    String currencyCode = 'RUB',
    int initialBalanceMinor = 0,
    bool isArchived = false,
  }) => FinanceAccount(
    id: id,
    bookId: 'book',
    name: id,
    currencyCode: currencyCode,
    initialBalanceMinor: initialBalanceMinor,
    createdAt: createdAt,
    updatedAt: createdAt,
    isArchived: isArchived,
  );

  FinanceCategory category({
    required String id,
    String? name,
    TransactionKind kind = TransactionKind.expense,
  }) => FinanceCategory(
    id: id,
    bookId: 'book',
    name: name ?? id,
    kind: kind,
    createdAt: createdAt,
    updatedAt: createdAt,
  );

  FinanceTransaction transaction({
    required String id,
    required String accountId,
    required DateTime occurredAt,
    String? categoryId,
    TransactionKind kind = TransactionKind.expense,
    int amountMinor = 100,
    String? toAccountId,
  }) => FinanceTransaction(
    id: id,
    bookId: 'book',
    accountId: accountId,
    toAccountId: toAccountId,
    categoryId: categoryId,
    kind: kind,
    amountMinor: amountMinor,
    occurredAt: occurredAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );

  final september = AnalyticsPeriod.month(year: 2026, month: 9);

  group('Период среза считается по локальному календарю', () {
    test('операция 1-го числа и последнего дня месяца попадает в свой месяц', () {
      expect(analyticsPeriodContains(september, DateTime(2026, 9, 1)), isTrue);
      expect(
        analyticsPeriodContains(september, DateTime(2026, 9, 30, 23, 59)),
        isTrue,
      );
      expect(
        analyticsPeriodContains(september, DateTime(2026, 8, 31, 23, 59)),
        isFalse,
      );
      expect(
        analyticsPeriodContains(september, DateTime(2026, 10, 1)),
        isFalse,
      );
    });

    test('полночь не попадает сразу в два соседних периода', () {
      final october = AnalyticsPeriod.month(year: 2026, month: 10);
      final midnight = DateTime(2026, 10, 1);

      expect(analyticsPeriodContains(september, midnight), isFalse);
      expect(analyticsPeriodContains(october, midnight), isTrue);
    });

    test('период года покрывает весь год и не захватывает соседние', () {
      final year = AnalyticsPeriod.year(2026);

      expect(analyticsPeriodContains(year, DateTime(2026, 1, 1)), isTrue);
      expect(analyticsPeriodContains(year, DateTime(2026, 12, 31, 23)), isTrue);
      expect(analyticsPeriodContains(year, DateTime(2027, 1, 1)), isFalse);
      expect(analyticsPeriodContains(year, DateTime(2025, 12, 31)), isFalse);
    });

    test('смена месяца и года идет по календарю', () {
      expect(
        shiftAnalyticsPeriod(september, 1),
        AnalyticsPeriod.month(year: 2026, month: 10),
      );
      expect(
        shiftAnalyticsPeriod(AnalyticsPeriod.month(year: 2026, month: 1), -1),
        AnalyticsPeriod.month(year: 2025, month: 12),
      );
      expect(
        shiftAnalyticsPeriod(AnalyticsPeriod.year(2026), -1),
        AnalyticsPeriod.year(2025),
      );
    });

    test('период операции и текущий период определяются по времени', () {
      final now = DateTime(2026, 9, 27, 10);

      expect(
        analyticsPeriodOf(DateTime(2026, 9, 24, 21, 30)),
        september,
      );
      expect(
        currentAnalyticsPeriod(AnalyticsPeriodMode.month, now),
        september,
      );
      expect(
        currentAnalyticsPeriod(AnalyticsPeriodMode.year, now),
        AnalyticsPeriod.year(2026),
      );
    });
  });

  group('Доступные периоды и границы переходов', () {
    test('год без операций не попадает в список доступных периодов', () {
      final now = DateTime(2026, 9, 27);
      final transactions = [
        transaction(
          id: 'old',
          accountId: 'account',
          categoryId: 'category',
          occurredAt: DateTime(2024, 5, 10),
        ),
      ];

      final available = availableAnalyticsPeriods(transactions, now);

      expect(available, contains(AnalyticsPeriod.year(2024)));
      expect(available, isNot(contains(AnalyticsPeriod.year(2025))));
    });

    test('текущий месяц и текущий год присутствуют без операций', () {
      final available = availableAnalyticsPeriods(const [], DateTime(2026, 9, 27));

      expect(available, hasLength(2));
      expect(available, contains(september));
      expect(available, contains(AnalyticsPeriod.year(2026)));
    });

    test('доступные периоды упорядочены от нового к старому', () {
      final now = DateTime(2026, 9, 27);
      final transactions = [
        transaction(
          id: 'september',
          accountId: 'account',
          categoryId: 'category',
          occurredAt: DateTime(2026, 9, 10),
        ),
        transaction(
          id: 'july',
          accountId: 'account',
          categoryId: 'category',
          occurredAt: DateTime(2026, 7, 10),
        ),
        transaction(
          id: 'last-year',
          accountId: 'account',
          categoryId: 'category',
          occurredAt: DateTime(2025, 3, 10),
        ),
      ];

      final available = availableAnalyticsPeriods(transactions, now);

      expect(analyticsPeriodsOfMode(available, AnalyticsPeriodMode.month), [
        september,
        AnalyticsPeriod.month(year: 2026, month: 7),
        AnalyticsPeriod.month(year: 2025, month: 3),
      ]);
      expect(analyticsPeriodsOfMode(available, AnalyticsPeriodMode.year), [
        AnalyticsPeriod.year(2026),
        AnalyticsPeriod.year(2025),
      ]);
    });

    test('переход ограничен доступными периодами', () {
      final available = [
        september,
        AnalyticsPeriod.month(year: 2026, month: 7),
        AnalyticsPeriod.month(year: 2025, month: 3),
      ];

      expect(
        previousAvailablePeriod(available, september),
        AnalyticsPeriod.month(year: 2026, month: 7),
      );
      expect(
        nextAvailablePeriod(
          available,
          AnalyticsPeriod.month(year: 2026, month: 7),
        ),
        september,
      );
      // За границей доступных периодов перехода нет: уход в период без операций
      // невозможен.
      expect(
        previousAvailablePeriod(
          available,
          AnalyticsPeriod.month(year: 2025, month: 3),
        ),
        isNull,
      );
      expect(nextAvailablePeriod(available, september), isNull);
    });
  });

  group('Доходы и расходы анализируются отдельно, переводы не участвуют', () {
    test('перевод не участвует ни в одном потоке', () {
      final rubles = account(id: 'rubles');
      final savings = account(id: 'savings');
      final categories = [
        category(id: 'food', name: 'Продукты'),
        category(id: 'salary', name: 'Зарплата', kind: TransactionKind.income),
      ];
      final transactions = [
        transaction(
          id: 'expense',
          accountId: 'rubles',
          categoryId: 'food',
          amountMinor: 1500,
          occurredAt: DateTime(2026, 9, 24),
        ),
        transaction(
          id: 'income',
          accountId: 'rubles',
          categoryId: 'salary',
          kind: TransactionKind.income,
          amountMinor: 5000,
          occurredAt: DateTime(2026, 9, 25),
        ),
        transaction(
          id: 'transfer',
          accountId: 'rubles',
          toAccountId: 'savings',
          kind: TransactionKind.transfer,
          amountMinor: 700,
          occurredAt: DateTime(2026, 9, 26),
        ),
      ];

      final expenses = buildAnalyticsSlice(
        transactions: transactions,
        accounts: [rubles, savings],
        categories: categories,
        period: september,
        stream: TransactionKind.expense,
      );
      final incomes = buildAnalyticsSlice(
        transactions: transactions,
        accounts: [rubles, savings],
        categories: categories,
        period: september,
        stream: TransactionKind.income,
      );

      expect(
        expenses.blocks.single.categories.map((item) => item.category.id),
        ['food'],
      );
      expect(expenses.blocks.single.totalMinor, 1500);
      expect(
        incomes.blocks.single.categories.map((item) => item.category.id),
        ['salary'],
      );
      expect(incomes.blocks.single.totalMinor, 5000);
    });

    test('начальный остаток счета не считается доходом', () {
      final rubles = account(id: 'rubles', initialBalanceMinor: 100000);

      final withoutOperations = buildAnalyticsSlice(
        transactions: const [],
        accounts: [rubles],
        categories: const [],
        period: september,
        stream: TransactionKind.income,
      );
      final withIncome = buildAnalyticsSlice(
        transactions: [
          transaction(
            id: 'salary',
            accountId: 'rubles',
            categoryId: 'salary',
            kind: TransactionKind.income,
            amountMinor: 5000,
            occurredAt: DateTime(2026, 9, 10),
          ),
        ],
        accounts: [rubles],
        categories: [
          category(
            id: 'salary',
            name: 'Зарплата',
            kind: TransactionKind.income,
          ),
        ],
        period: september,
        stream: TransactionKind.income,
      );

      expect(withoutOperations.isEmpty, isTrue);
      expect(withIncome.blocks.single.totalMinor, 5000);
    });

    test('операции другого периода в срез не попадают', () {
      final rubles = account(id: 'rubles');

      final slice = buildAnalyticsSlice(
        transactions: [
          transaction(
            id: 'august',
            accountId: 'rubles',
            categoryId: 'food',
            amountMinor: 1500,
            occurredAt: DateTime(2026, 8, 31, 23, 59),
          ),
          transaction(
            id: 'october',
            accountId: 'rubles',
            categoryId: 'food',
            amountMinor: 2500,
            occurredAt: DateTime(2026, 10, 1),
          ),
        ],
        accounts: [rubles],
        categories: [category(id: 'food', name: 'Продукты')],
        period: september,
        stream: TransactionKind.expense,
      );

      expect(slice.isEmpty, isTrue);
    });
  });

  group('Суммы аналитики группируются по валютам без смешивания', () {
    test('суммы разных валют не складываются', () {
      final rubles = account(id: 'rubles');
      final dollars = account(id: 'dollars', currencyCode: 'USD');

      final slice = buildAnalyticsSlice(
        transactions: [
          transaction(
            id: 'rub',
            accountId: 'rubles',
            categoryId: 'food',
            amountMinor: 1000,
            occurredAt: DateTime(2026, 9, 10),
          ),
          transaction(
            id: 'usd',
            accountId: 'dollars',
            categoryId: 'cafe',
            amountMinor: 2000,
            occurredAt: DateTime(2026, 9, 11),
          ),
        ],
        accounts: [rubles, dollars],
        categories: [
          category(id: 'food', name: 'Продукты'),
          category(id: 'cafe', name: 'Кафе'),
        ],
        period: september,
        stream: TransactionKind.expense,
      );

      expect(slice.blocks.map((block) => block.currencyCode), ['RUB', 'USD']);
      expect(slice.blocks.map((block) => block.totalMinor), [1000, 2000]);
    });

    test('порядок блоков соответствует порядку счетов книги', () {
      final dollars = account(id: 'dollars', currencyCode: 'USD');
      final rubles = account(id: 'rubles');

      final slice = buildAnalyticsSlice(
        transactions: [
          transaction(
            id: 'rub',
            accountId: 'rubles',
            categoryId: 'food',
            amountMinor: 1000,
            occurredAt: DateTime(2026, 9, 10),
          ),
          transaction(
            id: 'usd',
            accountId: 'dollars',
            categoryId: 'cafe',
            amountMinor: 2000,
            occurredAt: DateTime(2026, 9, 11),
          ),
        ],
        accounts: [dollars, rubles],
        categories: [
          category(id: 'food', name: 'Продукты'),
          category(id: 'cafe', name: 'Кафе'),
        ],
        period: september,
        stream: TransactionKind.expense,
      );

      expect(slice.blocks.map((block) => block.currencyCode), ['USD', 'RUB']);
    });

    test('операции архивного счета входят в свою валюту', () {
      final rubles = account(id: 'rubles');
      final archivedDollars = account(
        id: 'archived-dollars',
        currencyCode: 'USD',
        isArchived: true,
      );

      final slice = buildAnalyticsSlice(
        transactions: [
          transaction(
            id: 'rub',
            accountId: 'rubles',
            categoryId: 'food',
            amountMinor: 1500,
            occurredAt: DateTime(2026, 9, 10),
          ),
          transaction(
            id: 'usd',
            accountId: 'archived-dollars',
            categoryId: 'food',
            amountMinor: 2000,
            occurredAt: DateTime(2026, 9, 12),
          ),
        ],
        accounts: [rubles, archivedDollars],
        categories: [category(id: 'food', name: 'Продукты')],
        period: september,
        stream: TransactionKind.expense,
      );

      expect(slice.blocks.map((block) => block.currencyCode), ['RUB', 'USD']);
      expect(slice.blocks, hasLength(2));
      expect(slice.blocks.first.totalMinor, 1500);
      expect(slice.blocks.last.totalMinor, 2000);
    });

    test('фильтр по счету дает один валютный блок этого счета', () {
      final rubles = account(id: 'rubles');
      final dollars = account(id: 'dollars', currencyCode: 'USD');

      final slice = buildAnalyticsSlice(
        transactions: [
          transaction(
            id: 'rub',
            accountId: 'rubles',
            categoryId: 'food',
            amountMinor: 1000,
            occurredAt: DateTime(2026, 9, 10),
          ),
          transaction(
            id: 'usd',
            accountId: 'dollars',
            categoryId: 'cafe',
            amountMinor: 2000,
            occurredAt: DateTime(2026, 9, 11),
          ),
        ],
        accounts: [rubles, dollars],
        categories: [
          category(id: 'food', name: 'Продукты'),
          category(id: 'cafe', name: 'Кафе'),
        ],
        period: september,
        stream: TransactionKind.expense,
        accountFilter: AnalyticsAccountFilter.of(['dollars']),
      );

      expect(slice.blocks, hasLength(1));
      expect(slice.blocks.single.currencyCode, 'USD');
      expect(slice.blocks.single.totalMinor, 2000);
    });

    test('фильтр по нескольким счетам разных валют дает блоки по валютам', () {
      final rubles = account(id: 'rubles');
      final savings = account(id: 'savings');
      final dollars = account(id: 'dollars', currencyCode: 'USD');
      final transactions = [
        transaction(
          id: 'rub',
          accountId: 'rubles',
          categoryId: 'food',
          amountMinor: 1000,
          occurredAt: DateTime(2026, 9, 10),
        ),
        transaction(
          id: 'saving',
          accountId: 'savings',
          categoryId: 'food',
          amountMinor: 500,
          occurredAt: DateTime(2026, 9, 11),
        ),
        transaction(
          id: 'usd',
          accountId: 'dollars',
          categoryId: 'cafe',
          amountMinor: 2000,
          occurredAt: DateTime(2026, 9, 12),
        ),
      ];
      final categories = [
        category(id: 'food', name: 'Продукты'),
        category(id: 'cafe', name: 'Кафе'),
      ];

      final selected = buildAnalyticsSlice(
        transactions: transactions,
        accounts: [rubles, savings, dollars],
        categories: categories,
        period: september,
        stream: TransactionKind.expense,
        accountFilter: AnalyticsAccountFilter.of(['rubles', 'dollars']),
      );
      final sameCurrency = buildAnalyticsSlice(
        transactions: transactions,
        accounts: [rubles, savings, dollars],
        categories: categories,
        period: september,
        stream: TransactionKind.expense,
        accountFilter: AnalyticsAccountFilter.of(['rubles', 'savings']),
      );
      final all = buildAnalyticsSlice(
        transactions: transactions,
        accounts: [rubles, savings, dollars],
        categories: categories,
        period: september,
        stream: TransactionKind.expense,
      );

      // Выбраны счета внутри одной валюты: блок один, сумма общая.
      expect(sameCurrency.blocks, hasLength(1));
      expect(sameCurrency.blocks.single.currencyCode, 'RUB');
      expect(sameCurrency.blocks.single.totalMinor, 1500);

      // Выбраны счета разных валют: у каждой валюты собственный блок и итог.
      expect(selected.blocks.map((block) => block.currencyCode), [
        'RUB',
        'USD',
      ]);
      expect(selected.blocks.map((block) => block.totalMinor), [1000, 2000]);

      // Пустой фильтр означает «Все счета» и не сужает срез.
      expect(all.blocks.map((block) => block.currencyCode), ['RUB', 'USD']);
      expect(all.blocks.map((block) => block.totalMinor), [1500, 2000]);
    });

    test('фильтр сравнивается по составу счетов, а не по порядку', () {
      expect(AnalyticsAccountFilter.all.isEmpty, isTrue);
      expect(AnalyticsAccountFilter.all.contains('any-account'), isTrue);
      expect(
        AnalyticsAccountFilter.of(['dollars', 'rubles']),
        AnalyticsAccountFilter.of(['rubles', 'dollars']),
      );
      expect(
        AnalyticsAccountFilter.of(['dollars', 'rubles']).hashCode,
        AnalyticsAccountFilter.of(['rubles', 'dollars']).hashCode,
      );
      expect(
        AnalyticsAccountFilter.of(['dollars']),
        isNot(AnalyticsAccountFilter.of(['rubles'])),
      );
    });
  });

  group('Диаграмма категорий показывает категории по убыванию суммы', () {
    final rubles = account(id: 'rubles');
    final categories = [
      category(id: 'food', name: 'Продукты'),
      category(id: 'rent', name: 'Аренда'),
      category(id: 'sport', name: 'Спорт'),
    ];

    test('порядок по убыванию суммы, категория без операций отсутствует', () {
      final slice = buildAnalyticsSlice(
        transactions: [
          transaction(
            id: 'food',
            accountId: rubles.id,
            categoryId: 'food',
            amountMinor: 1500,
            occurredAt: DateTime(2026, 9, 10),
          ),
          transaction(
            id: 'rent',
            accountId: rubles.id,
            categoryId: 'rent',
            amountMinor: 40000,
            occurredAt: DateTime(2026, 9, 5),
          ),
        ],
        accounts: [rubles],
        categories: categories,
        period: september,
        stream: TransactionKind.expense,
      );

      expect(
        slice.blocks.single.categories.map((item) => item.category.name),
        ['Аренда', 'Продукты'],
      );
      expect(slice.blocks.single.categories.first.amountMinor, 40000);
      // Нулевая полоса вместо категории без операций не рисуется.
      expect(
        slice.blocks.single.categories.map((item) => item.category.id),
        isNot(contains('sport')),
      );
    });

    test('равные суммы дают устойчивый порядок по наименованию', () {
      final slice = buildAnalyticsSlice(
        transactions: [
          transaction(
            id: 'food',
            accountId: rubles.id,
            categoryId: 'food',
            amountMinor: 1000,
            occurredAt: DateTime(2026, 9, 10),
          ),
          transaction(
            id: 'rent',
            accountId: rubles.id,
            categoryId: 'rent',
            amountMinor: 1000,
            occurredAt: DateTime(2026, 9, 11),
          ),
        ],
        accounts: [rubles],
        categories: categories,
        period: september,
        stream: TransactionKind.expense,
      );

      expect(
        slice.blocks.single.categories.map((item) => item.category.name),
        ['Аренда', 'Продукты'],
      );
    });

    test('операции одной категории складываются в одну полосу', () {
      final slice = buildAnalyticsSlice(
        transactions: [
          transaction(
            id: 'first',
            accountId: rubles.id,
            categoryId: 'food',
            amountMinor: 1000,
            occurredAt: DateTime(2026, 9, 10),
          ),
          transaction(
            id: 'second',
            accountId: rubles.id,
            categoryId: 'food',
            amountMinor: 2500,
            occurredAt: DateTime(2026, 9, 12),
          ),
        ],
        accounts: [rubles],
        categories: categories,
        period: september,
        stream: TransactionKind.expense,
      );

      expect(slice.blocks.single.categories, hasLength(1));
      expect(slice.blocks.single.categories.single.amountMinor, 3500);
    });
  });

  group('Итог периода показывает сумму только выбранного потока', () {
    test('итог блока равен сумме категорийных сумм, валюта берется из справочника', () {
      final rubles = account(id: 'rubles');
      final slice = buildAnalyticsSlice(
        transactions: [
          transaction(
            id: 'food',
            accountId: 'rubles',
            categoryId: 'food',
            amountMinor: 1500,
            occurredAt: DateTime(2026, 9, 10),
          ),
          transaction(
            id: 'rent',
            accountId: 'rubles',
            categoryId: 'rent',
            amountMinor: 40000,
            occurredAt: DateTime(2026, 9, 5),
          ),
        ],
        accounts: [rubles],
        categories: [
          category(id: 'food', name: 'Продукты'),
          category(id: 'rent', name: 'Аренда'),
        ],
        period: september,
        stream: TransactionKind.expense,
        currencyCatalog: {
          'RUB': FinanceCurrency(
            code: 'RUB',
            numericCode: '643',
            symbol: '₽',
            nameRu: 'Российский рубль',
            nameEn: 'Russian Ruble',
          ),
        },
      );

      final block = slice.blocks.single;
      expect(block.currency?.symbol, '₽');
      expect(
        block.totalMinor,
        block.categories.fold<int>(0, (total, item) => total + item.amountMinor),
      );
      expect(block.totalMinor, 41500);
    });

    test('доходы при выбранном расходе в итог не попадают', () {
      final rubles = account(id: 'rubles');
      final slice = buildAnalyticsSlice(
        transactions: [
          transaction(
            id: 'salary',
            accountId: 'rubles',
            categoryId: 'salary',
            kind: TransactionKind.income,
            amountMinor: 50000,
            occurredAt: DateTime(2026, 9, 3),
          ),
          transaction(
            id: 'food',
            accountId: 'rubles',
            categoryId: 'food',
            amountMinor: 1500,
            occurredAt: DateTime(2026, 9, 10),
          ),
        ],
        accounts: [rubles],
        categories: [
          category(id: 'salary', name: 'Зарплата', kind: TransactionKind.income),
          category(id: 'food', name: 'Продукты'),
        ],
        period: september,
        stream: TransactionKind.expense,
      );

      expect(slice.stream, TransactionKind.expense);
      expect(slice.blocks.single.totalMinor, 1500);
    });
  });

  group('Годовой обзор показывает помесячный тренд выбранного потока', () {
    final year2026 = AnalyticsPeriod.year(2026);

    test('месяц без операций нулевой, соседние месяцы на своих местах', () {
      final rubles = account(id: 'rubles');
      final trend = buildAnalyticsYearTrend(
        transactions: [
          transaction(
            id: 'january',
            accountId: 'rubles',
            categoryId: 'food',
            amountMinor: 1000,
            occurredAt: DateTime(2026, 1, 15),
          ),
          transaction(
            id: 'december',
            accountId: 'rubles',
            categoryId: 'food',
            amountMinor: 2000,
            occurredAt: DateTime(2026, 12, 31, 23),
          ),
        ],
        accounts: [rubles],
        period: year2026,
        stream: TransactionKind.expense,
      );

      final block = trend.blocks.single;
      expect(block.months, hasLength(12));
      expect(block.months.map((item) => item.month), [
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
      ]);
      expect(block.months.first.amountMinor, 1000);
      expect(block.months[5].amountMinor, 0);
      expect(block.months.last.amountMinor, 2000);
      // Итог года равен сумме месячных величин.
      expect(
        block.totalMinor,
        block.months.fold<int>(0, (total, item) => total + item.amountMinor),
      );
      expect(block.totalMinor, 3000);
    });

    test('доходы и расходы не смешиваются', () {
      final rubles = account(id: 'rubles');
      final transactions = [
        transaction(
          id: 'salary',
          accountId: 'rubles',
          categoryId: 'salary',
          kind: TransactionKind.income,
          amountMinor: 50000,
          occurredAt: DateTime(2026, 1, 10),
        ),
        transaction(
          id: 'food',
          accountId: 'rubles',
          categoryId: 'food',
          amountMinor: 1500,
          occurredAt: DateTime(2026, 2, 10),
        ),
      ];

      final expenses = buildAnalyticsYearTrend(
        transactions: transactions,
        accounts: [rubles],
        period: year2026,
        stream: TransactionKind.expense,
      );
      final incomes = buildAnalyticsYearTrend(
        transactions: transactions,
        accounts: [rubles],
        period: year2026,
        stream: TransactionKind.income,
      );

      expect(expenses.blocks.single.months.first.amountMinor, 0);
      expect(expenses.blocks.single.months[1].amountMinor, 1500);
      expect(expenses.blocks.single.totalMinor, 1500);
      expect(incomes.blocks.single.months.first.amountMinor, 50000);
      expect(incomes.blocks.single.totalMinor, 50000);
    });

    test('год без операций выбранного потока дает пустой обзор', () {
      final rubles = account(id: 'rubles');
      final trend = buildAnalyticsYearTrend(
        transactions: [
          transaction(
            id: 'last-year',
            accountId: 'rubles',
            categoryId: 'food',
            amountMinor: 1500,
            occurredAt: DateTime(2025, 5, 10),
          ),
        ],
        accounts: [rubles],
        period: year2026,
        stream: TransactionKind.expense,
      );

      expect(trend.isEmpty, isTrue);
      expect(trend.blocks, isEmpty);
    });

    test('валюта входит в обзор только при наличии операций за год', () {
      final rubles = account(id: 'rubles');
      final dollars = account(id: 'dollars', currencyCode: 'USD');
      final trend = buildAnalyticsYearTrend(
        transactions: [
          transaction(
            id: 'rub',
            accountId: 'rubles',
            categoryId: 'food',
            amountMinor: 1000,
            occurredAt: DateTime(2026, 3, 10),
          ),
          transaction(
            id: 'usd',
            accountId: 'dollars',
            categoryId: 'cafe',
            amountMinor: 2000,
            occurredAt: DateTime(2026, 4, 10),
          ),
        ],
        accounts: [rubles, dollars],
        period: year2026,
        stream: TransactionKind.expense,
      );

      expect(trend.blocks.map((block) => block.currencyCode), ['RUB', 'USD']);
      expect(trend.blocks.map((block) => block.totalMinor), [1000, 2000]);
    });
  });

  group('Операции категории за период', () {
    final rubles = account(id: 'rubles');
    final dollars = account(id: 'dollars', currencyCode: 'USD');
    final categories = [
      category(id: 'food', name: 'Продукты'),
      category(id: 'cafe', name: 'Кафе'),
    ];
    final transactions = [
      transaction(
        id: 'first',
        accountId: 'rubles',
        categoryId: 'food',
        amountMinor: 1500,
        occurredAt: DateTime(2026, 9, 12),
      ),
      transaction(
        id: 'second',
        accountId: 'rubles',
        categoryId: 'food',
        amountMinor: 500,
        occurredAt: DateTime(2026, 9, 10),
      ),
      transaction(
        id: 'another-category',
        accountId: 'rubles',
        categoryId: 'cafe',
        amountMinor: 900,
        occurredAt: DateTime(2026, 9, 11),
      ),
      transaction(
        id: 'another-period',
        accountId: 'rubles',
        categoryId: 'food',
        amountMinor: 300,
        occurredAt: DateTime(2026, 8, 20),
      ),
      transaction(
        id: 'another-currency',
        accountId: 'dollars',
        categoryId: 'food',
        amountMinor: 2000,
        occurredAt: DateTime(2026, 9, 13),
      ),
    ];

    test('операции других категорий, периодов и валют отсутствуют', () {
      final operations = categoryOperations(
        transactions: transactions,
        accounts: [rubles, dollars],
        period: september,
        stream: TransactionKind.expense,
        categoryId: 'food',
        currencyCode: 'RUB',
      );

      expect(operations.map((item) => item.id), ['first', 'second']);
    });

    test('итог подэкрана равен сумме показанных операций и сумме полосы', () {
      final operations = categoryOperations(
        transactions: transactions,
        accounts: [rubles, dollars],
        period: september,
        stream: TransactionKind.expense,
        categoryId: 'food',
        currencyCode: 'RUB',
      );
      final bar = buildAnalyticsSlice(
        transactions: transactions,
        accounts: [rubles, dollars],
        categories: categories,
        period: september,
        stream: TransactionKind.expense,
      ).blocks.singleWhere((block) => block.currencyCode == 'RUB').categories
          .singleWhere((item) => item.category.id == 'food');

      expect(
        operations.fold<int>(0, (total, item) => total + item.amountMinor),
        bar.amountMinor,
      );
      expect(bar.amountMinor, 2000);
    });

    test('фильтр по счетам сужает состав подэкрана', () {
      final operations = categoryOperations(
        transactions: transactions,
        accounts: [rubles, dollars],
        period: september,
        stream: TransactionKind.expense,
        categoryId: 'food',
        currencyCode: 'RUB',
        accountFilter: AnalyticsAccountFilter.of(['dollars']),
      );

      expect(operations, isEmpty);
    });

    test('подэкран учитывает фильтр по нескольким счетам и валюту блока', () {
      final filter = AnalyticsAccountFilter.of([rubles.id, dollars.id]);
      final rubleOperations = categoryOperations(
        transactions: transactions,
        accounts: [rubles, dollars],
        period: september,
        stream: TransactionKind.expense,
        categoryId: 'food',
        currencyCode: 'RUB',
        accountFilter: filter,
      );
      final dollarOperations = categoryOperations(
        transactions: transactions,
        accounts: [rubles, dollars],
        period: september,
        stream: TransactionKind.expense,
        categoryId: 'food',
        currencyCode: 'USD',
        accountFilter: filter,
      );

      // Валюта блока отбирает операции и внутри выбранных счетов.
      expect(rubleOperations.map((item) => item.id), ['first', 'second']);
      expect(dollarOperations.map((item) => item.id), ['another-currency']);
    });
  });
}
