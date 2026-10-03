import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/banks_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/ui/features/accounts/widgets/bank_avatar.dart';
import 'package:budget_tracker/ui/features/settings/views/bank_form_page.dart';
import 'package:budget_tracker/ui/features/settings/views/banks_page.dart';
import 'package:budget_tracker/ui/features/settings/widgets/bank_color_picker.dart';
import 'package:budget_tracker/ui/features/settings/widgets/bank_rgba_color_dialog.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late FinanceBook book;
  late BanksRepository banks;
  late AccountsRepository accounts;

  setUp(() async {
    database = AppDatabase.forTesting();
    book = await DriftBooksRepository(database).create(name: 'Личная книга');
    banks = DriftBanksRepository(database);
    accounts = DriftAccountsRepository(database);
  });

  tearDown(() => database.close());

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
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
          home: const BanksPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Цвет маркера банка; при [within] ищется маркер внутри указанного виджета.
  Color? avatarColor(WidgetTester tester, {Finder? within}) {
    final avatar = within == null
        ? find.byType(BankAvatar)
        : find.descendant(of: within, matching: find.byType(BankAvatar));
    final container = tester.widget<Container>(
      find.descendant(of: avatar, matching: find.byType(Container)),
    );

    return (container.decoration! as BoxDecoration).color;
  }

  testWidgets('создание банка добавляет запись в справочник', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(banksAddActionKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(bankFormNameFieldKey), 'Мой банк');
    await tester.tap(find.byKey(bankFormSaveButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Мой банк'), findsOneWidget);

    final stored = await banks.list();

    expect(stored.single.name, 'Мой банк');
    expect(stored.single.isPreset, isFalse);
  });

  testWidgets('поиск фильтрует список банков', (WidgetTester tester) async {
    await banks.create(name: 'СберБанк');
    await banks.create(name: 'Тинькофф');

    await pumpPage(tester);

    await tester.enterText(find.byKey(banksSearchFieldKey), 'сбер');
    await tester.pumpAndSettle();

    expect(find.text('СберБанк'), findsOneWidget);
    expect(find.text('Тинькофф'), findsNothing);

    await tester.enterText(find.byKey(banksSearchFieldKey), 'нет такого');
    await tester.pumpAndSettle();

    expect(find.text('Нет банков, подходящих под запрос.'), findsOneWidget);
  });
  testWidgets('дубликат наименования отклоняется с сообщением', (
    WidgetTester tester,
  ) async {
    await banks.create(name: 'СберБанк');

    await pumpPage(tester);

    await tester.tap(find.byKey(banksAddActionKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(bankFormNameFieldKey), ' сбербанк ');
    await tester.tap(find.byKey(bankFormSaveButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Банк с таким наименованием уже есть в справочнике.'),
      findsOneWidget,
    );
    expect(await banks.list(), hasLength(1));
  });

  testWidgets('удаление используемого банка снимает признак банка у счета', (
    WidgetTester tester,
  ) async {
    final bank = await banks.create(name: 'СберБанк');
    final account = await accounts.create(
      bookId: book.id,
      name: 'Зарплатный',
      currencyCode: 'RUB',
      initialBalanceMinor: 250000,
      bankId: bank.id,
    );

    await pumpPage(tester);

    await tester.tap(find.text('СберБанк'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(bankFormDeleteButtonKey));
    await tester.pumpAndSettle();

    // Диалог указывает число затронутых счетов.
    expect(find.text('Удалить банк?'), findsOneWidget);
    expect(find.textContaining('Счетов с этим банком: 1'), findsOneWidget);

    await tester.tap(find.byKey(bankFormDeleteConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(await banks.getById(bank.id), isNull);
    expect(find.text('СберБанк'), findsNothing);

    final stored = (await accounts.getById(account.id))!;

    expect(stored.bankId, isNull);
    expect(stored.name, 'Зарплатный');
    expect(stored.initialBalanceMinor, 250000);
  });

  testWidgets('переименование банка обновляет справочник', (
    WidgetTester tester,
  ) async {
    final bank = await banks.create(name: 'СберБанк');

    await pumpPage(tester);

    await tester.tap(find.text('СберБанк'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(bankFormNameFieldKey), 'Сбер');
    await tester.tap(find.byKey(bankFormSaveButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Сбер'), findsOneWidget);
    expect((await banks.getById(bank.id))!.name, 'Сбер');
  });

  testWidgets('создание банка с выбранным цветом сохраняет HEX-цвет', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(banksAddActionKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(bankFormNameFieldKey), 'Мой банк');

    // Набор цветов не занимает место в форме: он открывается нажатием на маркер.
    expect(find.byKey(bankColorOptionKey('#1E88E5')), findsNothing);

    await tester.tap(find.byKey(bankFormColorMarkerKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(bankColorOptionKey('#1E88E5')));
    await tester.pumpAndSettle();

    // Выбранный цвет показан маркером строки формы.
    expect(
      avatarColor(tester, within: find.byKey(bankFormColorMarkerKey)),
      const Color(0xFF1E88E5),
    );

    await tester.tap(find.byKey(bankFormSaveButtonKey));
    await tester.pumpAndSettle();

    final stored = (await banks.list()).single;

    expect(stored.colorHex, '#1E88E5');
    // Маркер банка в списке рисуется сохраненным цветом.
    expect(avatarColor(tester), const Color(0xFF1E88E5));
  });

  testWidgets('смена цвета предустановленного банка сохраняет предустановку', (
    WidgetTester tester,
  ) async {
    const presetId = '00000000-0000-7000-8000-000000000042';
    await database
        .into(database.banks)
        .insert(
          bankToCompanion(
            FinanceBank(
              id: presetId,
              name: 'СберБанк',
              colorHex: '#21A038',
              isPreset: true,
            ),
          ),
        );

    await pumpPage(tester);

    expect(avatarColor(tester), const Color(0xFF21A038));

    await tester.tap(find.text('СберБанк'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(bankFormColorMarkerKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(bankColorOptionKey('#EF3124')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(bankFormSaveButtonKey));
    await tester.pumpAndSettle();

    final stored = (await banks.getById(presetId))!;

    expect(stored.colorHex, '#EF3124');
    expect(stored.name, 'СберБанк');
    expect(stored.isPreset, isTrue);
    expect(avatarColor(tester), const Color(0xFFEF3124));
  });

  testWidgets('выбор «без цвета» очищает сохраненный цвет банка', (
    WidgetTester tester,
  ) async {
    final bank = await banks.create(name: 'Мой банк', colorHex: '#1E88E5');

    await pumpPage(tester);

    expect(avatarColor(tester), const Color(0xFF1E88E5));

    await tester.tap(find.text('Мой банк'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(bankFormColorMarkerKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(bankColorNoneOptionKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(bankFormSaveButtonKey));
    await tester.pumpAndSettle();

    expect((await banks.getById(bank.id))!.colorHex, isNull);
    // Без сохраненного цвета маркер использует нейтральный цвет темы.
    expect(
      avatarColor(tester),
      AppTheme.light.colorScheme.surfaceContainerHighest,
    );
  });

  testWidgets('подбор произвольного цвета сохраняет значение с прозрачностью', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(banksAddActionKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(bankFormNameFieldKey), 'Мой банк');

    // Последний кружок набора открывает подбор произвольного цвета.
    await tester.tap(find.byKey(bankFormColorMarkerKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(bankColorCustomOptionKey));
    await tester.pumpAndSettle();

    expect(find.byKey(bankRgbaPreviewKey), findsOneWidget);

    await tester.enterText(find.byKey(bankRgbaCodeFieldKey), '#8055AAFF');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(bankRgbaApplyButtonKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(bankFormSaveButtonKey));
    await tester.pumpAndSettle();

    final stored = (await banks.list()).single;

    expect(stored.colorHex, '#8055AAFF');
    expect(avatarColor(tester), const Color(0x8055AAFF));
  });

  testWidgets('некорректный код цвета в подборе не сохраняется', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(banksAddActionKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(bankFormNameFieldKey), 'Мой банк');
    await tester.tap(find.byKey(bankFormColorMarkerKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(bankColorCustomOptionKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(bankRgbaCodeFieldKey), 'синий');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(bankRgbaApplyButtonKey));
    await tester.pumpAndSettle();

    // Диалог остается открытым и сообщает причину отказа.
    expect(find.byKey(bankRgbaErrorKey), findsOneWidget);
    expect(
      find.text('Введите код вида #RRGGBB или #AARRGGBB.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(bankRgbaCancelButtonKey));
    await tester.pumpAndSettle();

    final stored = await banks.list();

    expect(stored, isEmpty);
  });
}
