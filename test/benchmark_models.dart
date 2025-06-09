class BenchmarkMessage {
  final String id;
  final String data;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  BenchmarkMessage({
    required this.id,
    required this.data,
    required this.timestamp,
    required this.metadata,
  });

  @override
  String toString() => 'BenchmarkMessage($id, ${data.length} bytes)';
}
