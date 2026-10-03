import 'package:budget_tracker/domain/services/export_file_name_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('собирает имя выгрузки по маске bt_YYYYMMDDHHmmss', () {
    expect(
      exportFileName(
        timestamp: DateTime(2026, 10, 3, 15, 40, 5),
        extension: 'csv',
      ),
      'bt_20261003154005.csv',
    );
    expect(
      exportFileName(
        timestamp: DateTime(2026, 1, 2, 3, 4, 5),
        extension: 'sqlite',
      ),
      'bt_20260102030405.sqlite',
    );
  });

  test(
    'собирает имя импортированной копии по маске import_YYYYMMDD_HHmmss',
    () {
      expect(
        importedDatabaseFileName(DateTime(2026, 10, 3, 15, 40, 5)),
        'import_20261003_154005.sqlite',
      );
    },
  );
}
