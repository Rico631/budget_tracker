import 'package:budget_tracker/data/local/seed/seed_records.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';

/// Стартовый набор категорий из раздела «Категории» ADR-0001:
/// 11 доходных и 26 расходных категорий.
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
  ),
  CategorySeed(nameRu: 'Подарок', nameEn: 'Gift', kind: TransactionKind.income),
  CategorySeed(
    nameRu: 'Кэшбэк',
    nameEn: 'Cashback',
    kind: TransactionKind.income,
  ),
  CategorySeed(
    nameRu: 'Прочий доход',
    nameEn: 'Other Income',
    kind: TransactionKind.income,
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
    nameRu: 'Прочие расходы',
    nameEn: 'Other Expenses',
    kind: TransactionKind.expense,
  ),
];
