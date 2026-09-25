class ImportResult {
  final bool success;
  final String sourceName;
  final String? error;
  final int tables;
  final int rows;

  const ImportResult({required this.success, required this.sourceName, this.error, this.tables = 0, this.rows = 0});
}
