class QueueMessage<T> {
  final String? id;
  final T payload;
  final DateTime createdAt;
  final DateTime? processedAt;
  final DateTime? acknowledgedAt;

  QueueMessage({
    this.id,
    required this.payload,
    DateTime? createdAt,
    this.processedAt,
    this.acknowledgedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convenience constructor for the most common use case - just provide the payload
  ///
  /// [idGenerator] - Optional function to generate custom IDs. If not provided, uses UUID v4.
  QueueMessage.create(
    this.payload, {
    this.id,
    this.processedAt,
    this.acknowledgedAt,
  }) : createdAt = DateTime.now();

  /// Constructor with explicit ID (useful for testing or when you have specific ID requirements)
  QueueMessage.withId({
    required this.id,
    required this.payload,
    DateTime? createdAt,
    this.processedAt,
    this.acknowledgedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  QueueMessage<T> copyWith({DateTime? processedAt, DateTime? acknowledgedAt}) {
    return QueueMessage<T>(
      id: id,
      payload: payload,
      createdAt: createdAt,
      processedAt: processedAt ?? this.processedAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    );
  }

  @override
  String toString() {
    return 'QueueMessage(id: $id, payload: $payload, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueueMessage<T> &&
        other.id == id &&
        other.payload == payload &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, payload, createdAt);
}

/// Configuration for queue reliability and message handling behavior
class QueueConfiguration {
  /// Maximum number of times a message can be received before being moved to dead letter queue
  final int maxReceiveCount;

  /// Duration a message remains invisible after being dequeued
  final Duration visibilityTimeout;

  /// Optional message retention period (TTL)
  final Duration? messageRetentionPeriod;

  const QueueConfiguration({
    this.maxReceiveCount = 3,
    this.visibilityTimeout = const Duration(seconds: 30),
    this.messageRetentionPeriod,
  });

  /// Default configuration suitable for most use cases
  static const defaultConfig = QueueConfiguration();

  /// Configuration optimized for high-throughput scenarios
  static const highThroughput = QueueConfiguration(
    maxReceiveCount: 5,
    visibilityTimeout: Duration(minutes: 2),
  );

  /// Configuration for testing with shorter timeouts
  static const testing = QueueConfiguration(
    maxReceiveCount: 2,
    visibilityTimeout: Duration(milliseconds: 100),
    messageRetentionPeriod: Duration(minutes: 5),
  );
}

/// Queue interface with SQS-like reliability features built-in
abstract class Queue<T, S> {
  /// Queue configuration (visibility timeout, max retries, etc.)
  QueueConfiguration get configuration;

  /// Optional dead letter queue for poison messages
  Queue<T, S>? get deadLetterQueue;

  /// Optional custom ID generator function
  String Function()? get idGenerator;

  /// Serializer for converting payload objects to/from storage format
  MessageSerializer<T, S>? get serializer;

  /// Enqueue a message
  Future<void> enqueue(QueueMessage<T> message);

  /// Enqueue a payload with auto-generated ID using the queue's configured idGenerator
  Future<void> enqueuePayload(T payload) async {
    await enqueue(QueueMessage.create(payload));
  }

  /// Dequeue a message (makes it invisible for processing)
  Future<QueueMessage<T>?> dequeue();

  /// Acknowledge successful processing of a message
  Future<void> acknowledge(String messageId);

  /// Reject a message (optionally requeue for retry)
  Future<QueueMessage<T>?> reject(String messageId, {bool requeue = true});

  /// Dispose of resources (timers, connections, etc.)
  void dispose();
}

/// Interface for serializing and deserializing payload objects
///
/// `T` is the payload type
/// `S` is the serialized format (String, Map<String, dynamic>, List<int>, etc.)
abstract class MessageSerializer<T, S> {
  /// Serialize payload to the specified format
  S serialize(T payload);

  /// Deserialize from the specified format back to payload object
  T deserialize(S data);
}

/// Exception thrown when serialization fails
class SerializationError extends Error {
  final String message;
  final Object? cause;
  SerializationError(this.message, [this.cause]);
}

/// Exception thrown when deserialization fails
class DeserializationError extends Error {
  final String message;
  final Object? data;
  final Object? cause;
  DeserializationError(this.message, this.data, [this.cause]);
}

class MessageNotFoundError extends Error {
  final String messageId;
  MessageNotFoundError(this.messageId);
}

class QueueAlreadyExistsError extends Error {
  final String queueName;
  QueueAlreadyExistsError(this.queueName);
}

class QueueDoesNotExistError extends Error {
  final String queueName;
  QueueDoesNotExistError(this.queueName);
}

abstract class QueueFactory<T, S> {
  Future<Queue<T, S>> createQueue(
    String queueName, {
    QueueConfiguration? configuration,
    Queue<T, S>? deadLetterQueue,
  });

  Future<void> deleteQueue(String queueName);

  Future<Queue<T, S>> getQueue(String queueName);

  Future<void> dispose();
}
