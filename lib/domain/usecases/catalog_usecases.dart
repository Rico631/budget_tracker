import 'package:budget_tracker/domain/common/error_codes.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/bank_color_rule.dart';
import 'package:budget_tracker/domain/services/catalog_name_rule.dart';

/// Код ошибки домена: базовую категорию нельзя удалить.
const String categoryFallbackDeleteRejectedError =
    'a fallback category cannot be deleted.';

/// Код ошибки домена: базовую категорию нельзя переименовать.
const String categoryFallbackRenameRejectedError =
    'a fallback category cannot be renamed.';

/// Код ошибки домена: тип категории не может быть изменен.
const String categoryKindChangeRejectedError =
    'kind cannot be changed for an existing category.';

/// Код ошибки домена: категория может быть только доходом или расходом.
const String categoryKindNotAllowedError = 'kind must be income or expense.';

/// Код ошибки домена: у книги нет базовой категории нужного типа.
const String categoryFallbackMissingError =
    'the book has no fallback category of the requested kind.';

/// Код ошибки домена: категория с таким наименованием уже есть в книге и типе.
const String categoryNameDuplicateError =
    'a category with the same name already exists in the book and kind.';

/// Код ошибки домена: банк с таким наименованием уже есть в справочнике.
const String bankNameDuplicateError =
    'a bank with the same name already exists in the catalog.';

/// Код ошибки домена: значение цвета банка не является HEX-цветом.
const String bankColorInvalidError =
    'colorHex must be a HEX value like #RRGGBB.';

/// Домен: создание, переименование и удаление категорий книги.
///
/// Категории принадлежат книге, а тип категории неизменяем (ADR-0004, решения
/// 4.1-4.5). Уникальность наименований проверяется в домене: репозиторий лишь
/// выбирает запись по правилу `normalizeCatalogName` из
/// `lib/domain/services/catalog_name_rule.dart`, потому что SQLite без ICU не
/// приводит кириллицу к нижнему регистру.
class CategoryUseCases {
  CategoryUseCases({required this.categories, required this.fallbackNameFor});

  final CategoriesRepository categories;

  /// Наименование базовой категории типа [kind] на языке локали.
  ///
  /// Наименование базовой категории является данными (`docs/reference-data/
  /// categories.md`), а не строкой интерфейса, поэтому правило подставляет его
  /// вызывающая сторона: в приложении это стартовый набор категорий.
  final String Function(TransactionKind kind, String languageCode)
  fallbackNameFor;

  /// Создает категорию дохода или расхода.
  Future<ValidationResult<FinanceCategory>> create({
    required String bookId,
    required String name,
    required TransactionKind kind,
  }) async {
    final validation = await _validateNewName(
      bookId: bookId,
      name: name,
      kind: kind,
    );
    if (validation case Invalid(errors: final errors)) {
      return ValidationResult.invalid(errors);
    }

    final created = await categories.create(
      bookId: bookId,
      name: name.trim(),
      kind: kind,
    );
    return ValidationResult.valid(created);
  }

  /// Переименовывает категорию, сохраняя ее тип.
  ///
  /// Базовая категория не переименовывается, а попытка сохранить категорию с
  /// типом, отличным от сохраненного, отклоняется с сообщением причины
  /// (ADR-0004, решения 4.2 и 4.4).
  Future<ValidationResult<FinanceCategory>> update(
    FinanceCategory existing, {
    required String name,
    required TransactionKind kind,
  }) async {
    if (kind != existing.kind) {
      return ValidationResult.invalid([categoryKindChangeRejectedError]);
    }
    if (existing.isFallback) {
      return ValidationResult.invalid([categoryFallbackRenameRejectedError]);
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return ValidationResult.invalid([catalogNameRequiredError]);
    }
    if (!catalogNamesMatch(trimmedName, existing.name)) {
      final duplicate = await categories.findByName(
        bookId: existing.bookId,
        kind: kind,
        name: trimmedName,
      );
      if (duplicate != null && duplicate.id != existing.id) {
        return ValidationResult.invalid([categoryNameDuplicateError]);
      }
    }

    final updated = FinanceCategory(
      id: existing.id,
      bookId: existing.bookId,
      name: trimmedName,
      kind: existing.kind,
      parentId: existing.parentId,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      isArchived: existing.isArchived,
      isFallback: existing.isFallback,
    );
    await categories.update(updated);
    return ValidationResult.valid(updated);
  }

  /// Удаляет небазовую категорию, перенося ее операции в базовую категорию
  /// того же типа одной транзакцией (ADR-0004, решение 4.1).
  ///
  /// Базовая категория не удаляется, а книга без базовой категории нужного
  /// типа не может принять операции: такой запрос отклоняется.
  Future<ValidationResult<void>> delete(FinanceCategory category) async {
    if (category.isFallback) {
      return ValidationResult.invalid([categoryFallbackDeleteRejectedError]);
    }

    final fallback = await categories.findFallback(
      category.bookId,
      category.kind,
    );
    if (fallback == null) {
      return ValidationResult.invalid([categoryFallbackMissingError]);
    }

    await categories.deleteWithReassignment(category.id, fallback.id);
    return ValidationResult.valid(null);
  }

  /// Гарантирует наличие базовой категории каждого типа в книге и возвращает
  /// созданные записи.
  ///
  /// Метод идемпотентен: повторный вызов не создает вторую базовую категорию
  /// того же типа. Наименование создаваемой категории берется на языке
  /// [languageCode] (ADR-0004, решение 4.3).
  Future<List<FinanceCategory>> ensureFallbackCategories({
    required String bookId,
    required String languageCode,
  }) async {
    const fallbackKinds = <TransactionKind>[
      TransactionKind.income,
      TransactionKind.expense,
    ];
    final created = <FinanceCategory>[];

    for (final kind in fallbackKinds) {
      if (await categories.findFallback(bookId, kind) != null) {
        continue;
      }
      created.add(
        await categories.create(
          bookId: bookId,
          name: fallbackNameFor(kind, languageCode),
          kind: kind,
          isFallback: true,
        ),
      );
    }
    return created;
  }

  /// Проверяет наименование и тип создаваемой категории: категория перевода не
  /// создается, потому что перевод не имеет категории (решение 3.3 ADR-0001), а
  /// наименование не должно повторять категорию того же типа в этой книге
  /// (ADR-0004, решение 4.5).
  Future<ValidationResult<void>> _validateNewName({
    required String bookId,
    required String name,
    required TransactionKind kind,
  }) async {
    if (kind == TransactionKind.transfer) {
      return ValidationResult.invalid([categoryKindNotAllowedError]);
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return ValidationResult.invalid([catalogNameRequiredError]);
    }

    final duplicate = await categories.findByName(
      bookId: bookId,
      kind: kind,
      name: trimmedName,
    );
    if (duplicate != null) {
      return ValidationResult.invalid([categoryNameDuplicateError]);
    }
    return ValidationResult.valid(null);
  }
}

/// Домен: создание, переименование и удаление банков общего справочника.
///
/// Справочник банков общий для приложения, поэтому наименование уникально по
/// всему справочнику, включая предустановленные записи (ADR-0004, решение 4.5).
/// Переименование сохраняет признак предустановки, а удаление очищает ссылку
/// счета на банк, не изменяя остатки и операции счетов (ADR-0004, решения 4.7
/// и 4.8).
class BankUseCases {
  BankUseCases({required this.banks});

  final BanksRepository banks;

  /// Создает пользовательский банк без признака предустановки.
  ///
  /// [colorHex] — выбранный пользователем цвет: `#RRGGBB` или `RRGGBB`; `null`
  /// и пустая строка означают «без цвета» (ADR-0004, решение 4.10).
  Future<ValidationResult<FinanceBank>> create({
    required String name,
    String? colorHex,
  }) async {
    final trimmedName = name.trim();
    final errors = <String>[
      if (trimmedName.isEmpty) catalogNameRequiredError,
      if (!isBankColorHexAcceptable(colorHex)) bankColorInvalidError,
    ];

    if (errors.isNotEmpty) {
      return ValidationResult.invalid(errors);
    }
    if (await banks.findByName(trimmedName) != null) {
      return ValidationResult.invalid([bankNameDuplicateError]);
    }

    final created = await banks.create(
      name: trimmedName,
      colorHex: normalizeBankColorHex(colorHex),
    );
    return ValidationResult.valid(created);
  }

  /// Сохраняет наименование и цвет банка, включая предустановленный.
  ///
  /// Признак предустановки, данные отображения и ссылки счетов не изменяются
  /// (ADR-0004, решения 4.7, 4.8 и 4.10).
  Future<ValidationResult<FinanceBank>> update(
    FinanceBank existing, {
    required String name,
    required String? colorHex,
  }) async {
    final trimmedName = name.trim();
    final errors = <String>[
      if (trimmedName.isEmpty) catalogNameRequiredError,
      if (!isBankColorHexAcceptable(colorHex)) bankColorInvalidError,
    ];

    if (errors.isNotEmpty) {
      return ValidationResult.invalid(errors);
    }
    if (!catalogNamesMatch(trimmedName, existing.name)) {
      final duplicate = await banks.findByName(trimmedName);
      if (duplicate != null && duplicate.id != existing.id) {
        return ValidationResult.invalid([bankNameDuplicateError]);
      }
    }

    final updated = FinanceBank(
      id: existing.id,
      name: trimmedName,
      colorHex: normalizeBankColorHex(colorHex),
      displayName: existing.displayName,
      displayDetails: existing.displayDetails,
      iconDomain: existing.iconDomain,
      isPreset: existing.isPreset,
      isArchived: existing.isArchived,
    );
    await banks.update(updated);
    return ValidationResult.valid(updated);
  }

  /// Удаляет банк и очищает ссылку на него у связанных счетов.
  Future<ValidationResult<void>> delete(FinanceBank bank) async {
    await banks.deleteWithAccountDetach(bank.id);
    return ValidationResult.valid(null);
  }
}
