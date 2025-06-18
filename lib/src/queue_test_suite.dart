import 'package:kiss_queue/kiss_queue.dart';
import 'package:test/test.dart';
import 'dart:async';

// Generic cleanup function type
typedef QueueCleanup = void Function();

// Generic factory function type for creating factory instances
typedef QueueFactoryProvider<T, S> = QueueFactory<T, S> Function();

/// Generic test suite that can test any Queue implementation
void runQueueTests<T extends Queue<Order, S>, S>({
  required String implementationName,
  required QueueFactoryProvider<Order, S> factoryProvider,
  required QueueCleanup cleanup,
}) {
  group('$implementationName - Order Processing System', () {
    late QueueFactory<Order, S> factory;

    setUp(() {
      factory = factoryProvider();
    });

    tearDown(() {
      cleanup();
    });

    test('should demonstrate simplified QueueMessage API', () async {
      // Arrange
      final orderQueue = await factory.createQueue('test-simple-api');
      final order = Order(
        orderId: 'ORD-SIMPLE',
        customerId: 'CUST-123',
        amount: 99.99,
        items: ['Widget A'],
      );

      // Act - Use the simplified .create() constructor
      await orderQueue.enqueue(QueueMessage.create(order));
      final dequeuedMessage = await orderQueue.dequeue();

      // Assert
      expect(dequeuedMessage, isNotNull);
      expect(dequeuedMessage!.id, isNotEmpty); // Auto-generated UUID
      expect(dequeuedMessage.payload.orderId, equals('ORD-SIMPLE'));
      expect(dequeuedMessage.createdAt, isA<DateTime>());
      expect(dequeuedMessage.processedAt, isNotNull);

      // Test toString method
      expect(dequeuedMessage.toString(), contains('QueueMessage'));
      expect(dequeuedMessage.toString(), contains(dequeuedMessage.id));
    });

    test('should support custom IDs when needed', () async {
      // Arrange
      final orderQueue = await factory.createQueue('test-custom-id');
      final order = Order(
        orderId: 'ORD-CUSTOM',
        customerId: 'CUST-456',
        amount: 149.99,
        items: ['Premium Widget'],
      );

      // Act - Use withId constructor for deterministic testing
      final message = QueueMessage.withId(
        id: 'custom-test-id-123',
        payload: order,
      );
      await orderQueue.enqueue(message);
      final dequeuedMessage = await orderQueue.dequeue();

      // Assert
      expect(dequeuedMessage, isNotNull);
      expect(dequeuedMessage!.id, equals('custom-test-id-123'));
      expect(dequeuedMessage.payload.orderId, equals('ORD-CUSTOM'));
    });

    test('should enqueuePayload with auto-generated IDs', () async {
      // Arrange
      final orderQueue = await factory.createQueue('test-enqueuePayload');
      final order = Order(
        orderId: 'ORD-PAYLOAD',
        customerId: 'CUST-PAYLOAD',
        amount: 199.99,
        items: ['enqueuePayload Widget'],
      );

      // Act - Use enqueuePayload helper method
      await orderQueue.enqueuePayload(order);
      final dequeuedMessage = await orderQueue.dequeue();

      // Assert
      expect(dequeuedMessage, isNotNull);
      expect(dequeuedMessage!.id, isNotEmpty); // Auto-generated ID
      expect(dequeuedMessage.payload.orderId, equals('ORD-PAYLOAD'));
      expect(dequeuedMessage.payload.customerId, equals('CUST-PAYLOAD'));
      expect(dequeuedMessage.payload.amount, equals(199.99));
      expect(dequeuedMessage.processedAt, isNotNull);

      await orderQueue.acknowledge(dequeuedMessage.id);
    });

    test('enqueue and enqueuePayload should work equivalently', () async {
      // Arrange
      final orderQueue = await factory.createQueue('test-enqueue-equivalence');
      final order1 = Order(
        orderId: 'ORD-EQUIV-1',
        customerId: 'CUST-EQUIV',
        amount: 99.99,
        items: ['Test Item 1'],
      );
      final order2 = Order(
        orderId: 'ORD-EQUIV-2',
        customerId: 'CUST-EQUIV',
        amount: 99.99,
        items: ['Test Item 2'],
      );

      // Act - Test both methods
      await orderQueue.enqueue(QueueMessage.create(order1));
      await orderQueue.enqueuePayload(order2);

      final dequeued1 = await orderQueue.dequeue();
      final dequeued2 = await orderQueue.dequeue();

      // Assert - Both should work identically
      expect(dequeued1, isNotNull);
      expect(dequeued2, isNotNull);
      expect(dequeued1!.payload.orderId, equals('ORD-EQUIV-1'));
      expect(dequeued2!.payload.orderId, equals('ORD-EQUIV-2'));
      expect(dequeued1.id, isNotEmpty);
      expect(dequeued2.id, isNotEmpty);

      await orderQueue.acknowledge(dequeued1.id);
      await orderQueue.acknowledge(dequeued2.id);
    });

    test('should enqueue and dequeue orders successfully', () async {
      // Arrange
      final orderQueue = await factory.createQueue('test-enqueue-dequeue');
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

    test(
      'should implement visibility timeout - message invisible after dequeue',
      () async {
        // Arrange
        final orderQueue = await factory.createQueue('test-visibility-timeout');
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
      },
    );

    test('should restore message visibility after timeout expires', () async {
      // Arrange
      final orderQueue = await factory.createQueue('test-visibility-restore');
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
      await Future.delayed(const Duration(milliseconds: 500));

      final restoredMessage = await orderQueue.dequeue();

      // Assert
      expect(restoredMessage, isNotNull);
      expect(restoredMessage!.id, equals('msg-003'));
      // Message was successfully restored after visibility timeout
    });

    test('should acknowledge order and remove from queue', () async {
      // Arrange
      final orderQueue = await factory.createQueue('test-acknowledge');
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
      // Arrange - Simulating payment failure scenario
      final orderQueue = await factory.createQueue('test-reject-requeue');
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

      // Simulate payment processing failure
      await orderQueue.reject(dequeuedMessage!.id, requeue: true);

      // Message should be immediately available again
      final requeuedMessage = await orderQueue.dequeue();

      // Assert
      expect(requeuedMessage, isNotNull);
      expect(requeuedMessage!.id, equals('msg-005'));
      // Message was successfully requeued after rejection
    });

    test(
      'should move poison messages to dead letter queue after max retries',
      () async {
        // Arrange - Simulating consistently failing order
        final deadLetterQueue = await factory.createQueue('test-dlq');
        final orderQueue = await factory.createQueue(
          'test-poison-messages',
          configuration: QueueConfiguration.testing,
          deadLetterQueue: deadLetterQueue,
        );

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
      final shortRetentionQueue = await factory.createQueue(
        'test-expiration',
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

    test('should handle concurrent order processing simulation', () async {
      // Arrange - Multiple orders for batch processing
      final orderQueue = await factory.createQueue('test-concurrent');
      final orders = List.generate(
        5,
        (i) => Order(
          orderId: 'BATCH-${i + 1}',
          customerId: 'CUST-BATCH-$i',
          amount: (i + 1) * 25.0,
          items: ['Batch Item $i'],
        ),
      );

      // Act - Enqueue all orders using simplified API
      for (final order in orders) {
        await orderQueue.enqueue(QueueMessage.create(order));
      }

      // Simulate processing some orders
      final processed = <QueueMessage<Order>>[];
      for (int i = 0; i < 3; i++) {
        final message = await orderQueue.dequeue();
        if (message != null) {
          processed.add(message);
        }
      }

      // Assert
      expect(processed.length, equals(3));
      // Verify we can still dequeue remaining messages
      final remaining1 = await orderQueue.dequeue();
      final remaining2 = await orderQueue.dequeue();
      expect(remaining1, isNotNull);
      expect(remaining2, isNotNull);
    });

    test('should track order processing statistics', () async {
      // Arrange
      final orderQueue = await factory.createQueue('test-statistics');
      final orders = [
        Order(
          orderId: 'STAT-001',
          customerId: 'CUST-A',
          amount: 50.0,
          items: ['Item A'],
        ),
        Order(
          orderId: 'STAT-002',
          customerId: 'CUST-B',
          amount: 75.0,
          items: ['Item B'],
        ),
        Order(
          orderId: 'STAT-003',
          customerId: 'CUST-C',
          amount: 100.0,
          items: ['Item C'],
        ),
      ];

      // Act - Process orders with different outcomes using simplified API
      for (int i = 0; i < orders.length; i++) {
        await orderQueue.enqueue(QueueMessage.create(orders[i]));
      }

      // Successfully process first order
      var msg = await orderQueue.dequeue();
      await orderQueue.acknowledge(msg!.id);

      // Reject second order permanently
      msg = await orderQueue.dequeue();
      await orderQueue.reject(msg!.id, requeue: false);

      // Leave third order in processing state
      await orderQueue.dequeue();

      // Assert - Verify functional behavior
      // No more visible messages should be available
      final noMoreMessages = await orderQueue.dequeue();
      expect(noMoreMessages, isNull);
    });

    test(
      'should handle edge case - acknowledge non-existent message',
      () async {
        // Arrange
        final orderQueue = await factory.createQueue('test-ack-nonexistent');

        // Act & Assert
        expect(
          () => orderQueue.acknowledge('non-existent-msg'),
          throwsA(isA<MessageNotFoundError>()),
        );
      },
    );

    test('should handle edge case - reject non-existent message', () async {
      // Arrange
      final orderQueue = await factory.createQueue('test-reject-nonexistent');

      // Act & Assert
      expect(
        () => orderQueue.reject('non-existent-msg'),
        throwsA(isA<MessageNotFoundError>()),
      );
    });

    test(
      'should handle queue without dead letter queue configuration',
      () async {
        // Arrange - Queue without dead letter queue
        final noDLQQueue = await factory.createQueue(
          'test-no-dlq',
          configuration: const QueueConfiguration(maxReceiveCount: 2),
        );

        final order = Order(
          orderId: 'NO-DLQ',
          customerId: 'CUST-NO-DLQ',
          amount: 99.99,
          items: ['No DLQ Item'],
        );
        final message = QueueMessage.withId(id: 'no-dlq-msg', payload: order);

        // Act - Exceed max receive count
        await noDLQQueue.enqueue(message);

        for (int i = 0; i < 3; i++) {
          final msg = await noDLQQueue.dequeue();
          if (msg != null) {
            await noDLQQueue.reject(msg.id, requeue: true);
          }
        }

        final finalAttempt = await noDLQQueue.dequeue();

        // Assert - Message should be gone (no dead letter queue to move to)
        expect(finalAttempt, isNull);
      },
    );

    test('should test EventQueueMessage equality and hashCode', () {
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

    // Factory-specific tests
    group('Queue Factory', () {
      test('should create and retrieve queues', () async {
        // Act - Create queue
        final queue1 = await factory.createQueue('factory-test-1');
        final queue2 = await factory.getQueue('factory-test-1');

        // Assert - Should get same queue instance
        expect(queue1, same(queue2));
      });

      test('should prevent duplicate queue creation', () async {
        // Arrange
        await factory.createQueue('duplicate-test');

        // Act & Assert
        expect(
          () => factory.createQueue('duplicate-test'),
          throwsA(isA<QueueAlreadyExistsError>()),
        );
      });

      test('should handle non-existent queue retrieval', () async {
        // Act & Assert
        expect(
          () => factory.getQueue('non-existent-factory-test'),
          throwsA(isA<QueueDoesNotExistError>()),
        );
      });

      test('should delete queues properly', () async {
        // Arrange
        await factory.createQueue('delete-test');

        // Act
        await factory.deleteQueue('delete-test');

        // Assert - Should not be able to retrieve deleted queue
        expect(
          () => factory.getQueue('delete-test'),
          throwsA(isA<QueueDoesNotExistError>()),
        );
      });

      test('should handle deleting non-existent queue', () async {
        // Act & Assert
        expect(
          () => factory.deleteQueue('non-existent-delete-test'),
          throwsA(isA<QueueDoesNotExistError>()),
        );
      });
    });
  });
}
