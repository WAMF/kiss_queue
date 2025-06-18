import 'dart:async';
import 'package:collection/collection.dart';
import 'package:kiss_queue/kiss_queue.dart';

class InMemoryQueue<T, S> implements Queue<T, S> {
  final List<QueueMessage<S>> _queue = [];

  @override
  final QueueConfiguration configuration;

  @override
  final Queue<T, S>? deadLetterQueue;

  @override
  final String Function()? idGenerator;

  @override
  final MessageSerializer<T, S>? serializer;

  // Track message visibility and receive counts
  final Map<String, DateTime> _invisibleUntil = {};
  final Map<String, int> _receiveCount = {};

  // Timer for automatic message visibility restoration
  Timer? _visibilityTimer;

  // Private constructor - use InMemoryEventQueueFactory instead
  InMemoryQueue._({
    QueueConfiguration? configuration,
    this.deadLetterQueue,
    this.idGenerator,
    this.serializer,
  }) : configuration = configuration ?? QueueConfiguration.defaultConfig {
    _startVisibilityTimer();
  }

  @override
  Future<void> enqueue(QueueMessage<T> message) async {
    // Check if message has expired (TTL)
    if (_isMessageExpired(message)) {
      return;
    }

    final QueueMessage<S> storedMessage;
    if (serializer != null) {
      // Serialize only the payload for storage
      try {
        final serializedPayload = serializer!.serialize(message.payload);
        storedMessage = QueueMessage<S>(
          id: message.id,
          payload: serializedPayload,
          createdAt: message.createdAt,
          processedAt: message.processedAt,
          acknowledgedAt: message.acknowledgedAt,
        );
      } catch (e) {
        throw SerializationError('Failed to serialize message payload', e);
      }
    } else if (message.payload is S) {
      // Store the original payload as-is
      storedMessage = QueueMessage<S>(
        id: message.id,
        payload: message.payload as S,
        createdAt: message.createdAt,
        processedAt: message.processedAt,
        acknowledgedAt: message.acknowledgedAt,
      );
    } else {
      throw SerializationError(
        'Message payload type ${message.payload.runtimeType} does not match expected type $S',
        message.payload,
      );
    }

    _queue.add(storedMessage);
    _receiveCount[message.id] = 0;
  }

  @override
  Future<void> enqueuePayload(T payload) async {
    await enqueue(QueueMessage.create(payload, idGenerator: idGenerator));
  }

  @override
  Future<QueueMessage<T>?> dequeue() async {
    _cleanupExpiredMessages();
    _restoreVisibleMessages();

    while (true) {
      // Find first visible message
      final storedMessage = _queue.firstWhereOrNull(_isMessageVisible);
      if (storedMessage == null) {
        return null;
      }

      // Increment receive count
      _receiveCount[storedMessage.id] =
          (_receiveCount[storedMessage.id] ?? 0) + 1;

      // Check if message should go to dead letter queue
      if (_receiveCount[storedMessage.id]! > configuration.maxReceiveCount) {
        if (deadLetterQueue != null) {
          await _moveToDeadLetterQueue(storedMessage);
        } else {
          // No dead letter queue - just remove the message permanently
          _queue.removeWhere((element) => element.id == storedMessage.id);
          _cleanupMessageTracking(storedMessage.id);
        }
        continue; // Try to get next available message
      }

      // Make message invisible for visibility timeout
      _invisibleUntil[storedMessage.id] = DateTime.now().add(
        configuration.visibilityTimeout,
      );

      // Deserialize payload if needed and create processed message
      final T payload = _deserializePayload(storedMessage);

      final processedMessage = QueueMessage<T>(
        id: storedMessage.id,
        payload: payload,
        createdAt: storedMessage.createdAt,
        processedAt: DateTime.now(),
        acknowledgedAt: storedMessage.acknowledgedAt,
      );

      return processedMessage;
    }
  }

  @override
  Future<void> acknowledge(String messageId) async {
    _removeMessage(messageId);
    _cleanupMessageTracking(messageId);
  }

  @override
  Future<QueueMessage<T>?> reject(
    String messageId, {
    bool requeue = true,
  }) async {
    final storedMessage = _removeMessage(messageId);

    if (requeue) {
      // Make message immediately visible again
      _invisibleUntil.remove(messageId);
      _queue.add(storedMessage);
    } else {
      _cleanupMessageTracking(messageId);
    }

    // Deserialize payload if needed and create processed message
    final T payload = _deserializePayload(storedMessage);

    return QueueMessage<T>(
      id: storedMessage.id,
      payload: payload,
      createdAt: storedMessage.createdAt,
      processedAt: storedMessage.processedAt,
      acknowledgedAt: storedMessage.acknowledgedAt,
    );
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
  }

  // Private helper methods

  T _deserializePayload(QueueMessage<S> storedMessage) {
    if (serializer != null) {
      try {
        return serializer!.deserialize(storedMessage.payload!);
      } catch (e) {
        throw DeserializationError(
          'Failed to deserialize message payload',
          storedMessage.payload,
          e,
        );
      }
    } else {
      if (storedMessage.payload is! T) {
        throw DeserializationError(
          'Stored payload type ${storedMessage.payload.runtimeType} does not match expected type $T',
          storedMessage.payload,
        );
      }
      return storedMessage.payload as T;
    }
  }

  bool _isMessageVisible(QueueMessage<Object?> message) {
    final invisibleUntil = _invisibleUntil[message.id];
    return invisibleUntil == null || DateTime.now().isAfter(invisibleUntil);
  }

  bool _isMessageExpired(QueueMessage<T> message) {
    if (configuration.messageRetentionPeriod == null) return false;
    return DateTime.now().difference(message.createdAt) >
        configuration.messageRetentionPeriod!;
  }

  bool _isStoredMessageExpired(QueueMessage<Object?> storedMessage) {
    if (configuration.messageRetentionPeriod == null) return false;
    return DateTime.now().difference(storedMessage.createdAt) >
        configuration.messageRetentionPeriod!;
  }

  void _startVisibilityTimer() {
    _visibilityTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _restoreVisibleMessages();
      _cleanupExpiredMessages();
    });
  }

  void _restoreVisibleMessages() {
    final now = DateTime.now();
    _invisibleUntil.removeWhere((messageId, invisibleUntil) {
      return now.isAfter(invisibleUntil);
    });
  }

  void _cleanupExpiredMessages() {
    if (configuration.messageRetentionPeriod == null) return;

    _queue.removeWhere((storedMessage) {
      if (_isStoredMessageExpired(storedMessage)) {
        _cleanupMessageTracking(storedMessage.id);
        return true;
      }
      return false;
    });
  }

  Future<void> _moveToDeadLetterQueue(QueueMessage<S> storedMessage) async {
    _queue.removeWhere((element) => element.id == storedMessage.id);
    _cleanupMessageTracking(storedMessage.id);

    if (deadLetterQueue != null) {
      // Deserialize payload if needed and create processed message
      final T payload = _deserializePayload(storedMessage);

      final queueMessage = QueueMessage<T>(
        id: storedMessage.id,
        payload: payload,
        createdAt: storedMessage.createdAt,
        processedAt: storedMessage.processedAt,
        acknowledgedAt: storedMessage.acknowledgedAt,
      );

      await deadLetterQueue!.enqueue(queueMessage);
    }
  }

  void _cleanupMessageTracking(String messageId) {
    _invisibleUntil.remove(messageId);
    _receiveCount.remove(messageId);
  }

  QueueMessage<S> _removeMessage(String messageId) {
    final message = _getMessage(messageId);
    _queue.removeWhere((element) => element.id == messageId);
    return message;
  }

  QueueMessage<S> _getMessage(String messageId) {
    final message = _queue.firstWhereOrNull(
      (element) => element.id == messageId,
    );
    if (message == null) {
      throw MessageNotFoundError(messageId);
    }
    return message;
  }
}

/// Factory for creating in-memory queues with proper lifecycle management
class InMemoryQueueFactory<T, S> implements QueueFactory<T, S> {
  // Track created queues for proper cleanup and retrieval
  final Map<String, Queue> _createdQueues = <String, Queue>{};

  final String Function()? idGenerator;
  final MessageSerializer<T, S>? serializer;

  InMemoryQueueFactory({this.idGenerator, this.serializer});

  @override
  Future<Queue<T, S>> createQueue(
    String queueName, {
    QueueConfiguration? configuration = QueueConfiguration.testing,
    Queue<T, S>? deadLetterQueue,
  }) async {
    if (_createdQueues.containsKey(queueName)) {
      throw QueueAlreadyExistsError(queueName);
    }

    final queue = InMemoryQueue<T, S>._(
      configuration: configuration,
      deadLetterQueue: deadLetterQueue,
      idGenerator: idGenerator,
      serializer: serializer,
    );

    _createdQueues[queueName] = queue;
    return queue;
  }

  @override
  Future<Queue<T, S>> getQueue(String queueName) async {
    final queue = _createdQueues[queueName];
    if (queue == null) {
      throw QueueDoesNotExistError(queueName);
    }
    return queue as Queue<T, S>;
  }

  @override
  Future<void> deleteQueue(String queueName) async {
    final queue = _createdQueues.remove(queueName);
    if (queue == null) {
      throw QueueDoesNotExistError(queueName);
    }
    queue.dispose();
  }

  /// Dispose all created queues (useful for testing cleanup)
  void disposeAll() {
    for (final queue in _createdQueues.values) {
      queue.dispose();
    }
    _createdQueues.clear();
  }
}
