import 'package:uuid/uuid.dart';

class FinanceIdGenerator {
  const FinanceIdGenerator();

  String generateV7() => Uuid().v7();

  bool isValidV7(String value) {
    final uuid = Uuid.parse(value);
    return uuid.isNotEmpty && value.length >= 36;
  }
}
