import 'package:kiss_queue/kiss_queue.dart';
import 'package:test/test.dart';
import 'queue_test_suite.dart';
import 'performance_test_suite.dart';

void main() {
  late InMemoryEventQueueFactory factory;

  // Factory function for creating InMemory queues
  Future<Queue<T>> createInMemoryQueue<T>(
    String queueName, {
    QueueConfiguration? configuration,
    Queue<T>? deadLetterQueue,
  }) async {
    return factory.createQueue<T>(
      queueName,
      configuration: configuration,
      deadLetterQueue: deadLetterQueue,
    );
  }

  // Cleanup function
  void cleanupInMemory() {
    factory.disposeAll();
  }

  setUp(() {
    factory = InMemoryEventQueueFactory();
  });

  // Run the generic functional tests
  runQueueTests<Queue<Order>>(
    implementationName: 'InMemoryQueue',
    createQueue: createInMemoryQueue<Order>,
    cleanup: cleanupInMemory,
    config: QueueTestConfig.inMemory,
  );

  // Run the generic performance tests
  runPerformanceTests(
    implementationName: 'InMemoryQueue',
    createOrderQueue: createInMemoryQueue<Order>,
    createBenchmarkQueue: createInMemoryQueue<BenchmarkMessage>,
    cleanup: cleanupInMemory,
    config: QueueTestConfig.inMemory,
  );

  // Run factory-specific tests
  group('InMemoryQueue - Factory Management', () {
    tearDown(() {
      cleanupInMemory();
    });

    test('should demonstrate factory functionality', () async {
      // Arrange - Test factory capabilities
      final testFactory = InMemoryEventQueueFactory();

      // Act - Create multiple queues
      final queue1 = await testFactory.createQueue<String>('queue1');
      await testFactory.createQueue<int>('queue2');

      // Assert - Factory tracking
      expect(testFactory.createdQueueCount, equals(2));
      expect(testFactory.queueNames, containsAll(['queue1', 'queue2']));

      // Test getQueue
      final retrievedQueue1 = await testFactory.getQueue<String>('queue1');
      expect(retrievedQueue1, same(queue1));

      // Test deleteQueue
      await testFactory.deleteQueue('queue1');
      expect(testFactory.createdQueueCount, equals(1));
      expect(testFactory.queueNames, equals(['queue2']));

      // Test error cases
      expect(
        () => testFactory.createQueue<String>('queue2'),
        throwsA(isA<QueueAlreadyExistsError>()),
      );

      expect(
        () => testFactory.getQueue<String>('non-existent'),
        throwsA(isA<QueueDoesNotExistError>()),
      );

      expect(
        () => testFactory.deleteQueue('non-existent'),
        throwsA(isA<QueueDoesNotExistError>()),
      );

      // Cleanup
      testFactory.disposeAll();
    });

    test('should demonstrate different queue configurations', () async {
      // Arrange - Test different configurations
      final testFactory = InMemoryEventQueueFactory();
      final defaultQueue = await testFactory.createQueue<Order>('default');
      final highThroughputQueue = await testFactory.createQueue<Order>(
        'high-throughput',
        configuration: QueueConfiguration.highThroughput,
      );
      final customQueue = await testFactory.createQueue<Order>(
        'custom',
        configuration: const QueueConfiguration(
          maxReceiveCount: 10,
          visibilityTimeout: Duration(minutes: 5),
          messageRetentionPeriod: Duration(hours: 24),
        ),
      );

      // Assert - Check configurations are applied correctly
      expect(defaultQueue.configuration.maxReceiveCount, equals(3));
      expect(
        defaultQueue.configuration.visibilityTimeout,
        equals(Duration(seconds: 30)),
      );

      expect(highThroughputQueue.configuration.maxReceiveCount, equals(5));
      expect(
        highThroughputQueue.configuration.visibilityTimeout,
        equals(Duration(minutes: 2)),
      );

      expect(customQueue.configuration.maxReceiveCount, equals(10));
      expect(
        customQueue.configuration.visibilityTimeout,
        equals(Duration(minutes: 5)),
      );
      expect(
        customQueue.configuration.messageRetentionPeriod,
        equals(Duration(hours: 24)),
      );

      // Cleanup
      testFactory.disposeAll();
    });
  });
}
