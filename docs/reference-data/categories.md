# Стартовый набор категорий

Справочные данные, вынесенные из ADR-0001 (`docs/adr/0001-budget-tracker-concept-and-ux.md`): 12 категорий доходов и 28 категорий расходов, создаваемых при первом запуске. Документ — источник истины для `lib/data/local/seed/category_seed_catalog.dart`; правила набора остаются в ADR-0001 (решение 4.1), а долговые категории и признак долговой роли описаны в ADR-0009.

## Категории

Колонка «Долговая роль» задает сохраненный признак `Categories.debtRole` (ADR-0009, решение 9.5). Признак не зависит от наименования категории: долговую категорию можно переименовать, но нельзя удалить. Роль различает и тип операции, и событие долга, поэтому у каждой долговой категории своя роль: `loanOutflow` — выдача займа, `loanInflow` — получение займа, `refundOutflow` — возврат своего долга, `refundInflow` — возврат выданного займа.

| Русское название     | Английское название | Тип категории | Долговая роль |
| -------------------- | ------------------- | ------------- | ------------- |
| Зарплата             | Salary              | income        | —             |
| Премия               | Bonus               | income        | —             |
| Подработка           | Freelance Work      | income        | —             |
| Предпринимательство  | Business Income     | income        | —             |
| Инвестиционный доход | Investment Income   | income        | —             |
| Проценты по вкладам  | Interest Income     | income        | —             |
| Дивиденды            | Dividends           | income        | —             |
| Возврат денег        | Refund              | income        | refundInflow  |
| Подарок              | Gift                | income        | —             |
| Кэшбэк               | Cashback            | income        | —             |
| Заём                 | Loan                | income        | loanInflow    |
| Прочий доход         | Other Income        | income        | —             |
| Продукты             | Groceries           | expense       | —             |
| Рестораны и кафе     | Restaurants & Cafés | expense       | —             |
| Доставка еды         | Food Delivery       | expense       | —             |
| Транспорт            | Transportation      | expense       | —             |
| Такси                | Taxi                | expense       | —             |
| Автомобиль           | Car                 | expense       | —             |
| Топливо              | Fuel                | expense       | —             |
| Жильё                | Housing             | expense       | —             |
| Коммунальные услуги  | Utilities           | expense       | —             |
| Интернет             | Internet            | expense       | —             |
| Мобильная связь      | Mobile Phone        | expense       | —             |
| Одежда               | Clothing            | expense       | —             |
| Здоровье             | Healthcare          | expense       | —             |
| Спорт                | Sports              | expense       | —             |
| Красота              | Beauty              | expense       | —             |
| Образование          | Education           | expense       | —             |
| Развлечения          | Entertainment       | expense       | —             |
| Путешествия          | Travel              | expense       | —             |
| Подписки             | Subscriptions       | expense       | —             |
| Страхование          | Insurance           | expense       | —             |
| Подарки              | Gifts               | expense       | —             |
| Дом и быт            | Household           | expense       | —             |
| Электроника          | Electronics         | expense       | —             |
| Хобби                | Hobbies             | expense       | —             |
| Домашние животные    | Pets                | expense       | —             |
| Заём                 | Loan                | expense       | loanOutflow   |
| Возврат денег        | Refund              | expense       | refundOutflow |
| Прочие расходы       | Other Expenses      | expense       | —             |
