/// Книга учета.
library;

class FinanceBook {
  FinanceBook({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
}
