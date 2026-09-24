import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Finance database schema', () {
    test('creates finance tables and required indexes in memory', () async {
      final database = AppDatabase.forTesting();
      addTearDown(() => database.close());

      final tables = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('books', 'banks', 'accounts', 'categories', 'transactions') ORDER BY name",
          )
          .get();

      final names = tables.map((row) => row.data['name'] as String).toList();

      expect(names, [
        'accounts',
        'banks',
        'books',
        'categories',
        'transactions',
      ]);

      final indexes = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE '%book_id%' OR name LIKE '%occurred_at%' ORDER BY name",
          )
          .get();

      expect(indexes, isNotEmpty);
    });

    test('upgrades an existing version 1 database to version 2', () async {
      final directory = await Directory.systemTemp.createTemp(
        'budget_tracker_',
      );
      final file = File.fromUri(directory.uri.resolve('finance.sqlite'));
      final database = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (connection) {
            connection.execute('PRAGMA user_version = 1');
          },
        ),
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });

      final tables = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('books', 'banks', 'accounts', 'categories', 'transactions')",
          )
          .get();

      expect(tables, hasLength(5));
      expect(database.schemaVersion, 2);
    });
  });

  group('UUIDv7 generation', () {
    test('creates a version 7 UUID string', () {
      final generator = FinanceIdGenerator();
      final value = generator.generateV7();

      expect(value, isNotEmpty);
      expect(value.length, greaterThanOrEqualTo(36));
      expect(value[14], '7');
    });
  });

  group('Transaction validation', () {
    test(
      'accepts valid income and transfer flows and rejects invalid ones',
      () {
        final income = FinanceTransactionInput.tryCreate(
          bookId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8b',
          accountId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8c',
          toAccountId: null,
          categoryId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8d',
          kind: TransactionKind.income,
          amountMinor: 2500,
        );

        switch (income) {
          case Valid(value: final value):
            expect(value.accountId, '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8c');
          case Invalid(errors: final errors):
            fail('Expected valid income, got $errors');
        }

        final transfer = FinanceTransactionInput.tryCreate(
          bookId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8b',
          accountId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8e',
          toAccountId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8f',
          categoryId: null,
          kind: TransactionKind.transfer,
          amountMinor: 750,
        );

        expect(transfer, isA<Valid<FinanceTransactionInput>>());

        final invalidTransfer = FinanceTransactionInput.tryCreate(
          bookId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8b',
          accountId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8e',
          toAccountId: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8e',
          categoryId: null,
          kind: TransactionKind.transfer,
          amountMinor: 750,
        );

        switch (invalidTransfer) {
          case Valid():
            fail('Expected invalid transfer');
          case Invalid(errors: final errors):
            expect(errors, isNotEmpty);
        }
      },
    );

    test('normalizes optional strings and identifiers', () {
      final result = FinanceTransactionInput.tryCreate(
        bookId: ' book-1 ',
        accountId: ' account-1 ',
        toAccountId: '   ',
        categoryId: ' category-1 ',
        note: '   ',
        kind: TransactionKind.income,
        amountMinor: 100,
      );

      switch (result) {
        case Valid(value: final value):
          expect(value.bookId, 'book-1');
          expect(value.accountId, 'account-1');
          expect(value.toAccountId, isNull);
          expect(value.categoryId, 'category-1');
          expect(value.note, isNull);
        case Invalid(errors: final errors):
          fail('Expected normalized input to be valid, got $errors');
      }
    });
  });
}
