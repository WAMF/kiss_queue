import 'dart:async';
import 'package:test/test.dart';
import 'package:kiss_queue/kiss_queue.dart';

// Test data model
class Order {
  final String orderId;
  final String customerId;
  final double amount;
  final List<String> items;

  Order({
    required this.orderId,
    required this.customerId,
    required this.amount,
    required this.items,
  });

  @override
  String toString() {
    return 'Order(orderId: $orderId, customerId: $customerId, amount: $amount, items: $items)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Order &&
        other.orderId == orderId &&
        other.customerId == customerId &&
        other.amount == amount &&
        other.items.toString() == items.toString();
  }

  @override
  int get hashCode => Object.hash(orderId, customerId, amount, items);
}

void main() {
  group('KISS Queue Tests', () {
    late InMemoryEventQueueFactory factory;
    late Queue<Order> orderQueue;
    late Queue<Order> deadLetterQueue;

    setUp(() async {
      factory = InMemoryEventQueueFactory();

      // Create dead letter queue first
      deadLetterQueue = await factory.createQueue<Order>(
        'dead-letter-queue',
        configuration: QueueConfiguration.testing,
      );

      // Create main queue with dead letter queue
      orderQueue = await factory.createQueue<Order>(
        'test-orders',
        configuration: QueueConfiguration.testing,
        deadLetterQueue: deadLetterQueue,
      );
    });

    tearDown(() {
      factory.disposeAll();
    });

    group('Basic Queue Operations', () {
      test('should enqueue and dequeue orders successfully', () async {
        // Arrange
        final order = Order(
          orderId: 'ORD-001',
          customerId: 'CUST-123',
          amount: 99.99,
          items: ['Widget A', 'Widget B'],
        );
        final message = QueueMessage.withId(id: 'msg-001', payload: order);

        // Act
        await orderQueue.enqueue(message);
        final dequeuedMessage = await orderQueue.dequeue();

        // Assert
        expect(dequeuedMessage, isNotNull);
        expect(dequeuedMessage!.id, equals('msg-001'));
        expect(dequeuedMessage.payload.orderId, equals('ORD-001'));
        expect(dequeuedMessage.payload.amount, equals(99.99));
        expect(dequeuedMessage.processedAt, isNotNull);
      });

      test('should implement visibility timeout', () async {
        // Arrange
        final order = Order(
          orderId: 'ORD-002',
          customerId: 'CUST-456',
          amount: 149.99,
          items: ['Premium Widget'],
        );
        final message = QueueMessage.withId(id: 'msg-002', payload: order);

        // Act
        await orderQueue.enqueue(message);
        final firstDequeue = await orderQueue.dequeue();
        final secondDequeue = await orderQueue
            .dequeue(); // Should be null due to visibility timeout

        // Assert
        expect(firstDequeue, isNotNull);
        expect(
          secondDequeue,
          isNull,
        ); // Message is invisible due to visibility timeout
      });

      test('should restore message visibility after timeout expires', () async {
        // Arrange
        final order = Order(
          orderId: 'ORD-003',
          customerId: 'CUST-789',
          amount: 75.50,
          items: ['Basic Widget'],
        );
        final message = QueueMessage.withId(id: 'msg-003', payload: order);

        // Act
        await orderQueue.enqueue(message);
        await orderQueue.dequeue(); // Make message invisible

        // Wait for visibility timeout to expire
        await Future.delayed(const Duration(milliseconds: 150));

        final restoredMessage = await orderQueue.dequeue();

        // Assert
        expect(restoredMessage, isNotNull);
        expect(restoredMessage!.id, equals('msg-003'));
      });

      test('should acknowledge order and remove from queue', () async {
        // Arrange
        final order = Order(
          orderId: 'ORD-004',
          customerId: 'CUST-101',
          amount: 200.00,
          items: ['Deluxe Package'],
        );
        final message = QueueMessage.withId(id: 'msg-004', payload: order);

        // Act
        await orderQueue.enqueue(message);
        final dequeuedMessage = await orderQueue.dequeue();
        await orderQueue.acknowledge(dequeuedMessage!.id);

        // Try to dequeue again - should be null as message was acknowledged
        final nextMessage = await orderQueue.dequeue();

        // Assert
        expect(nextMessage, isNull); // Message was acknowledged and removed
      });

      test('should reject and requeue failed order processing', () async {
        // Arrange
        final order = Order(
          orderId: 'ORD-005',
          customerId: 'CUST-202',
          amount: 299.99,
          items: ['High-Value Item'],
        );
        final message = QueueMessage.withId(id: 'msg-005', payload: order);

        // Act
        await orderQueue.enqueue(message);
        final dequeuedMessage = await orderQueue.dequeue();
        await orderQueue.reject(dequeuedMessage!.id, requeue: true);

        // Message should be immediately available again
        final requeuedMessage = await orderQueue.dequeue();

        // Assert
        expect(requeuedMessage, isNotNull);
        expect(requeuedMessage!.id, equals('msg-005'));
      });

      test(
        'should move poison messages to dead letter queue after max retries',
        () async {
          // Arrange
          final problematicOrder = Order(
            orderId: 'ORD-666',
            customerId: 'CUST-TROUBLE',
            amount: 13.13,
            items: ['Cursed Widget'],
          );
          final message = QueueMessage.withId(
            id: 'msg-poison',
            payload: problematicOrder,
          );

          // Act - Process and fail multiple times
          await orderQueue.enqueue(message);

          // First attempt
          var dequeuedMessage = await orderQueue.dequeue();
          await orderQueue.reject(dequeuedMessage!.id, requeue: true);

          // Second attempt
          dequeuedMessage = await orderQueue.dequeue();
          await orderQueue.reject(dequeuedMessage!.id, requeue: true);

          // Third attempt should move to dead letter queue (maxReceiveCount = 2)
          final finalAttempt = await orderQueue.dequeue();

          // Assert
          expect(finalAttempt, isNull); // Main queue should be empty

          // Check dead letter queue
          final deadMessage = await deadLetterQueue.dequeue();
          expect(deadMessage, isNotNull);
          expect(deadMessage!.payload.orderId, equals('ORD-666'));
        },
      );

      test('should handle message expiration and cleanup', () async {
        // Arrange - Create queue with very short retention
        final shortRetentionQueue = await factory.createQueue<Order>(
          'short-retention-queue',
          configuration: const QueueConfiguration(
            maxReceiveCount: 3,
            visibilityTimeout: Duration(milliseconds: 100),
            messageRetentionPeriod: Duration(milliseconds: 50),
          ),
        );

        final order = Order(
          orderId: 'ORD-EXPIRED',
          customerId: 'CUST-LATE',
          amount: 99.99,
          items: ['Time-Sensitive Item'],
        );
        final message = QueueMessage.withId(
          id: 'msg-expired',
          payload: order,
          createdAt: DateTime.now().subtract(
            const Duration(seconds: 1),
          ), // Already expired
        );

        // Act
        await shortRetentionQueue.enqueue(
          message,
        ); // Should not enqueue expired message
        final dequeuedMessage = await shortRetentionQueue.dequeue();

        // Assert
        expect(dequeuedMessage, isNull);
      });

      test(
        'should handle edge case - acknowledge non-existent message',
        () async {
          // Act & Assert
          expect(
            () => orderQueue.acknowledge('non-existent-msg'),
            throwsA(isA<MessageNotFoundError>()),
          );
        },
      );

      test('should handle edge case - reject non-existent message', () async {
        // Act & Assert
        expect(
          () => orderQueue.reject('non-existent-msg'),
          throwsA(isA<MessageNotFoundError>()),
        );
      });

      test('should test QueueMessage equality and hashCode', () {
        // Arrange
        final order = Order(
          orderId: 'TEST',
          customerId: 'CUST',
          amount: 100,
          items: [],
        );
        final now = DateTime.now();

        final message1 = QueueMessage.withId(
          id: 'test-id',
          payload: order,
          createdAt: now,
        );
        final message2 = QueueMessage.withId(
          id: 'test-id',
          payload: order,
          createdAt: now,
        );
        final message3 = QueueMessage.withId(
          id: 'different-id',
          payload: order,
          createdAt: now,
        );

        // Assert
        expect(message1, equals(message2));
        expect(message1.hashCode, equals(message2.hashCode));
        expect(message1, isNot(equals(message3)));
        expect(message1.hashCode, isNot(equals(message3.hashCode)));
      });
    });

    group('Factory Tests', () {
      test('should create and retrieve queues using factory', () async {
        // Arrange & Act
        final queue1 = await factory.createQueue<String>('string-queue');
        final queue2 = await factory.getQueue<String>('string-queue');

        // Assert
        expect(queue1, same(queue2));
      });

      test('should prevent duplicate queue creation', () async {
        // Arrange
        await factory.createQueue<String>('duplicate-queue');

        // Act & Assert
        expect(
          () => factory.createQueue<String>('duplicate-queue'),
          throwsA(isA<QueueAlreadyExistsError>()),
        );
      });

      test('should handle non-existent queue retrieval', () async {
        // Act & Assert
        expect(
          () => factory.getQueue<String>('non-existent-queue'),
          throwsA(isA<QueueDoesNotExistError>()),
        );
      });

      test('should delete queues properly', () async {
        // Arrange
        await factory.createQueue<String>('delete-me');

        // Act
        await factory.deleteQueue('delete-me');

        // Assert
        expect(
          () => factory.getQueue<String>('delete-me'),
          throwsA(isA<QueueDoesNotExistError>()),
        );
      });

      test('should dispose all queues', () {
        // Arrange
        expect(factory.createdQueueCount, greaterThan(0));

        // Act
        factory.disposeAll();

        // Assert
        expect(factory.createdQueueCount, equals(0));
        expect(factory.queueNames, isEmpty);
      });
    });
  });
}
