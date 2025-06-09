import 'dart:async';
import 'package:collection/collection.dart';
import 'package:kiss_queue/kiss_queue.dart';

class InMemoryQueue<T> implements Queue<T> {
  final List<QueueMessage<T>> _queue = [];

  @override
  final QueueConfiguration configuration;

  @override
  final Queue<T>? deadLetterQueue;

  @override
  final String Function()? idGenerator;

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
  }) : configuration = configuration ?? QueueConfiguration.defaultConfig {
    _startVisibilityTimer();
  }

  @override
  Future<void> enqueue(QueueMessage<T> message) async {
    // Check if message has expired (TTL)
    if (_isMessageExpired(message)) {
      return;
    }

    _queue.add(message);
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

    // Find first visible message
    final message = _queue.firstWhereOrNull(_isMessageVisible);
    if (message == null) {
      return null;
    }

    // Increment receive count
    _receiveCount[message.id] = (_receiveCount[message.id] ?? 0) + 1;

    // Check if message should go to dead letter queue
    if (_receiveCount[message.id]! > configuration.maxReceiveCount) {
      if (deadLetterQueue != null) {
        await _moveToDeadLetterQueue(message);
      } else {
        // No dead letter queue - just remove the message permanently
        _queue.removeWhere((element) => element.id == message.id);
        _cleanupMessageTracking(message.id);
      }
      return dequeue(); // Try to get next available message
    }

    // Make message invisible for visibility timeout
    _invisibleUntil[message.id] = DateTime.now().add(
      configuration.visibilityTimeout,
    );

    // Create processed copy with timestamp
    final processedMessage = message.copyWith(processedAt: DateTime.now());

    return processedMessage;
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
    final message = _removeMessage(messageId);

    if (requeue) {
      // Make message immediately visible again
      _invisibleUntil.remove(messageId);
      _queue.add(message);
    } else {
      _cleanupMessageTracking(messageId);
    }

    return message;
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
  }

  // Private helper methods

  bool _isMessageVisible(QueueMessage<T> message) {
    final invisibleUntil = _invisibleUntil[message.id];
    return invisibleUntil == null || DateTime.now().isAfter(invisibleUntil);
  }

  bool _isMessageExpired(QueueMessage<T> message) {
    if (configuration.messageRetentionPeriod == null) return false;
    return DateTime.now().difference(message.createdAt) >
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

    _queue.removeWhere((message) {
      if (_isMessageExpired(message)) {
        _cleanupMessageTracking(message.id);
        return true;
      }
      return false;
    });
  }

  Future<void> _moveToDeadLetterQueue(QueueMessage<T> message) async {
    _queue.removeWhere((element) => element.id == message.id);
    _cleanupMessageTracking(message.id);

    if (deadLetterQueue != null) {
      await deadLetterQueue!.enqueue(message);
    }
  }

  void _cleanupMessageTracking(String messageId) {
    _invisibleUntil.remove(messageId);
    _receiveCount.remove(messageId);
  }

  QueueMessage<T> _removeMessage(String messageId) {
    final message = _getMessage(messageId);
    _queue.removeWhere((element) => element.id == messageId);
    return message;
  }

  QueueMessage<T> _getMessage(String messageId) {
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
class InMemoryEventQueueFactory implements QueueFactory {
  // Track created queues for proper cleanup and retrieval
  final Map<String, Queue> _createdQueues = <String, Queue>{};

  @override
  Future<Queue<T>> createQueue<T>(
    String queueName, {
    QueueConfiguration? configuration,
    Queue<T>? deadLetterQueue,
    String Function()? idGenerator,
  }) async {
    if (_createdQueues.containsKey(queueName)) {
      throw QueueAlreadyExistsError(queueName);
    }

    final queue = InMemoryQueue<T>._(
      configuration: configuration,
      deadLetterQueue: deadLetterQueue,
      idGenerator: idGenerator,
    );

    _createdQueues[queueName] = queue;
    return queue;
  }

  @override
  Future<Queue<T>> getQueue<T>(String queueName) async {
    final queue = _createdQueues[queueName];
    if (queue == null) {
      throw QueueDoesNotExistError(queueName);
    }
    return queue as Queue<T>;
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

  /// Get count of created queues (useful for testing/monitoring)
  int get createdQueueCount => _createdQueues.length;

  /// Get list of queue names (useful for testing/monitoring)
  List<String> get queueNames => _createdQueues.keys.toList();
}
