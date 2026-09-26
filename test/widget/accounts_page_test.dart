import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/presentation/features/accounts/accounts_page.dart';
import 'package:budget_tracker/presentation/features/accounts/widgets/bank_avatar.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late FinanceBook book;

  setUp(() async {
    database = AppDatabase.forTesting();
    await database.batch((batch) {
      batch.insertAll(database.currencies, [
        currencyToCompanion(
          FinanceCurrency(
            code: 'RUB',
            numericCode: '643',
            symbol: '₽',
            nameRu: 'Российский рубль',
            nameEn: 'Russian Ruble',
          ),
        ),
        currencyToCompanion(
          FinanceCurrency(
            code: 'USD',
            numericCode: '840',
            symbol: r'$',
            nameRu: 'Доллар США',
            nameEn: 'US Dollar',
          ),
        ),
      ]);
    });
    book = await DriftBooksRepository(database).create(name: 'Личная книга');
  });

  tearDown(() => database.close());

  Future<FinanceAccount> createAccount({
    required String name,
    String currencyCode = 'RUB',
    int initialBalanceMinor = 0,
    String? bankId,
  }) => DriftAccountsRepository(database).create(
    bookId: book.id,
    name: name,
    currencyCode: currencyCode,
    initialBalanceMinor: initialBalanceMinor,
    bankId: bankId,
  );

  Future<void> pumpAccountsPage(
    WidgetTester tester, {
    Size size = const Size(800, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('ru'), Locale('en')],
          home: const Scaffold(body: AccountsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('показывает раздельные итоги по валютам без общего итога', (
    WidgetTester tester,
  ) async {
    await createAccount(name: 'Рубли', initialBalanceMinor: 100000);
    await createAccount(
      name: 'Доллары',
      currencyCode: 'USD',
      initialBalanceMinor: 20000,
    );

    await pumpAccountsPage(tester);

    expect(find.text('Итого: 1\u00A0000,00 ₽'), findsOneWidget);
    expect(find.text('Итого: 200,00 \$'), findsOneWidget);
    expect(find.text('Рубли'), findsOneWidget);
    expect(find.text('Доллары'), findsOneWidget);
    expect(find.textContaining('1\u00A0200,00'), findsNothing);
  });

  testWidgets('не показывает архивные счета в списке и в итоге', (
    WidgetTester tester,
  ) async {
    final accounts = DriftAccountsRepository(database);
    await createAccount(name: 'Активный', initialBalanceMinor: 100000);
    final archived = await createAccount(
      name: 'Архивный',
      initialBalanceMinor: 50000,
    );
    await accounts.archive(archived.id);

    await pumpAccountsPage(tester);

    expect(find.text('Активный'), findsOneWidget);
    expect(find.text('Архивный'), findsNothing);
    expect(find.text('Итого: 1\u00A0000,00 ₽'), findsOneWidget);
  });

  testWidgets('показывает приглашение добавить счет в пустой книге', (
    WidgetTester tester,
  ) async {
    await pumpAccountsPage(tester);

    expect(find.text('Пока нет счетов'), findsOneWidget);
    expect(find.text('Добавить счет'), findsOneWidget);
  });

  testWidgets('показывает маркер банка для счета с банком', (
    WidgetTester tester,
  ) async {
    const bankId = '00000000-0000-7000-8000-000000000001';
    await database
        .into(database.banks)
        .insert(
          bankToCompanion(
            FinanceBank(
              id: bankId,
              name: 'Банк',
              colorHex: '#1E88E5',
              isPreset: true,
            ),
          ),
        );
    await createAccount(name: 'Основной', bankId: bankId);

    await pumpAccountsPage(tester);

    expect(find.byType(BankAvatar), findsOneWidget);
    expect(find.text('Б'), findsOneWidget);
  });

  testWidgets('не показывает маркер банка и пустую подпись для счета без банка', (
    WidgetTester tester,
  ) async {
    await createAccount(name: 'Без банка', initialBalanceMinor: 100);

    await pumpAccountsPage(tester);

    expect(find.text('Без банка'), findsOneWidget);
    expect(find.byType(BankAvatar), findsNothing);
    expect(find.text(''), findsNothing);
  });

  testWidgets('не переполняет список при длинном названии и крупной сумме', (
    WidgetTester tester,
  ) async {
    const longName = 'Зарплатная карта Сбербанк с очень длинным названием';
    await createAccount(name: longName, initialBalanceMinor: 123456789012);

    await pumpAccountsPage(tester, size: const Size(360, 640));

    expect(tester.takeException(), isNull);
    expect(find.text(longName), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}