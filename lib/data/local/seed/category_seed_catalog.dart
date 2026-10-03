import 'package:budget_tracker/data/local/seed/seed_records.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';

/// Стартовый набор категорий из раздела «Категории» документа
/// `docs/reference-data/categories.md`: 12 доходных и 28 расходных категорий.
///
/// Категория типа `transfer` не создается: перевод не имеет
/// категории (решение 3.3 ADR-0001).
const List<CategorySeed> categorySeedCatalog = <CategorySeed>[
  CategorySeed(
    nameRu: 'Зарплата',
    nameEn: 'Salary',
    kind: TransactionKind.income,
  ),
  CategorySeed(nameRu: 'Премия', nameEn: 'Bonus', kind: TransactionKind.income),
  CategorySeed(
    nameRu: 'Подработка',
    nameEn: 'Freelance Work',
    kind: TransactionKind.income,
  ),
  CategorySeed(
    nameRu: 'Предпринимательство',
    nameEn: 'Business Income',
    kind: TransactionKind.income,
  ),
  CategorySeed(
    nameRu: 'Инвестиционный доход',
    nameEn: 'Investment Income',
    kind: TransactionKind.income,
  ),
  CategorySeed(
    nameRu: 'Проценты по вкладам',
    nameEn: 'Interest Income',
    kind: TransactionKind.income,
  ),
  CategorySeed(
    nameRu: 'Дивиденды',
    nameEn: 'Dividends',
    kind: TransactionKind.income,
  ),
  CategorySeed(
    nameRu: 'Возврат денег',
    nameEn: 'Refund',
    kind: TransactionKind.income,
    debtRole: CategoryDebtRole.refundInflow,
  ),
  CategorySeed(nameRu: 'Подарок', nameEn: 'Gift', kind: TransactionKind.income),
  CategorySeed(
    nameRu: 'Кэшбэк',
    nameEn: 'Cashback',
    kind: TransactionKind.income,
  ),
  CategorySeed(
    nameRu: 'Заём',
    nameEn: 'Loan',
    kind: TransactionKind.income,
    debtRole: CategoryDebtRole.loanInflow,
  ),
  CategorySeed(
    nameRu: 'Прочий доход',
    nameEn: 'Other Income',
    kind: TransactionKind.income,
    isFallback: true,
  ),
  CategorySeed(
    nameRu: 'Продукты',
    nameEn: 'Groceries',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Рестораны и кафе',
    nameEn: 'Restaurants & Cafés',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Доставка еды',
    nameEn: 'Food Delivery',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Транспорт',
    nameEn: 'Transportation',
    kind: TransactionKind.expense,
  ),
  CategorySeed(nameRu: 'Такси', nameEn: 'Taxi', kind: TransactionKind.expense),
  CategorySeed(
    nameRu: 'Автомобиль',
    nameEn: 'Car',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Топливо',
    nameEn: 'Fuel',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Жильё',
    nameEn: 'Housing',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Коммунальные услуги',
    nameEn: 'Utilities',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Интернет',
    nameEn: 'Internet',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Мобильная связь',
    nameEn: 'Mobile Phone',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Одежда',
    nameEn: 'Clothing',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Здоровье',
    nameEn: 'Healthcare',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Спорт',
    nameEn: 'Sports',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Красота',
    nameEn: 'Beauty',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Образование',
    nameEn: 'Education',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Развлечения',
    nameEn: 'Entertainment',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Путешествия',
    nameEn: 'Travel',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Подписки',
    nameEn: 'Subscriptions',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Страхование',
    nameEn: 'Insurance',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Подарки',
    nameEn: 'Gifts',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Дом и быт',
    nameEn: 'Household',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Электроника',
    nameEn: 'Electronics',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Хобби',
    nameEn: 'Hobbies',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Домашние животные',
    nameEn: 'Pets',
    kind: TransactionKind.expense,
  ),
  CategorySeed(
    nameRu: 'Заём',
    nameEn: 'Loan',
    kind: TransactionKind.expense,
    debtRole: CategoryDebtRole.loanOutflow,
  ),
  CategorySeed(
    nameRu: 'Возврат денег',
    nameEn: 'Refund',
    kind: TransactionKind.expense,
    debtRole: CategoryDebtRole.refundOutflow,
  ),
  CategorySeed(
    nameRu: 'Прочие расходы',
    nameEn: 'Other Expenses',
    kind: TransactionKind.expense,
    isFallback: true,
  ),
];

/// Запись базовой категории типа [kind] из стартового набора.
///
/// Базовая категория гарантирует, что операции удаляемой категории можно
/// перенести в категорию того же типа (ADR-0004, решения 4.1-4.3).
CategorySeed fallbackCategorySeed(TransactionKind kind) => categorySeedCatalog
    .firstWhere((seed) => seed.isFallback && seed.kind == kind);

/// Наименование базовой категории типа [kind] на языке [languageCode].
///
/// Наименование берется из стартового набора, потому что наименования категорий
/// являются данными (`docs/reference-data/categories.md`), а не строкой
/// интерфейса. Для локали, отличной от `en`, используется русское наименование:
/// так же поступает первый запуск при наполнении стартового набора.
String fallbackCategoryName(TransactionKind kind, String languageCode) {
  final seed = fallbackCategorySeed(kind);
  return languageCode.trim().toLowerCase() == 'en' ? seed.nameEn : seed.nameRu;
}

/// Долговые категории стартового набора типа [kind] (ADR-0009, решение 9.7).
///
/// Миграция доставляет их в каждую существующую книгу: расходные «Заём» с ролью
/// `loanOutflow` и «Возврат денег» с ролью `refundOutflow`, доходные — с ролями
/// `loanInflow` и `refundInflow`. Порядок ролей — заём, затем возврат: по нему
/// миграция разделения ролей подбирает роль переименованной категории.
List<CategorySeed> debtCategorySeedsFor(TransactionKind kind) => [
  for (final role in debtCategoryRolesFor(kind))
    categorySeedCatalog.firstWhere((seed) => seed.debtRole == role),
];

/// Долговые роли стартового набора типа [kind]: заём, затем возврат долга.
List<CategoryDebtRole> debtCategoryRolesFor(TransactionKind kind) =>
    switch (kind) {
      TransactionKind.expense => const [
        CategoryDebtRole.loanOutflow,
        CategoryDebtRole.refundOutflow,
      ],
      TransactionKind.income => const [
        CategoryDebtRole.loanInflow,
        CategoryDebtRole.refundInflow,
      ],
      TransactionKind.transfer => const [],
    };

/// Наименование категории [seed] на языке данных книги [languageCode].
///
/// Миграция определяет язык книги по наименованию базовой категории: локаль
/// интерфейса в момент обновления неизвестна (ADR-0009, решение 9.7).
String categorySeedName(CategorySeed seed, String languageCode) =>
    languageCode.trim().toLowerCase() == 'en' ? seed.nameEn : seed.nameRu;

/// Язык данных книги по наименованию базовой категории дохода [name].
///
/// Значение `en` возвращается только для английского наименования базовой
/// категории дохода: русское наименование и любое другое значение дают `ru`,
/// как и при первом запуске приложения с неанглийской локалью.
String categoryDataLanguage(String? name) {
  final normalized = name?.trim().toLowerCase() ?? '';
  return normalized ==
          fallbackCategorySeed(TransactionKind.income).nameEn.toLowerCase()
      ? 'en'
      : 'ru';
}
