/// Банк из справочника банков.
library;

class FinanceBank {
  FinanceBank({
    required this.id,
    required this.name,
    this.displayName,
    this.displayDetails,
    this.colorHex,
    this.iconDomain,
    this.isPreset = false,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final String? displayName;
  final String? displayDetails;
  final String? colorHex;
  final String? iconDomain;
  final bool isPreset;
  final bool isArchived;
}
