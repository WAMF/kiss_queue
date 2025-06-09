// This is an example of how to test your own EventQueue implementation
// using the generic test suite. Replace MyEventQueue with your actual implementation.

import 'package:kiss_queue/kiss_queue.dart';
import 'package:test/test.dart';
import 'queue_test_suite.dart';
import 'performance_test_suite.dart';

// Example custom implementation placeholder
class MyEventQueue<T> implements Queue<T> {
  @override
  QueueConfiguration get configuration => throw UnimplementedError();

  @override
  Queue<T>? get deadLetterQueue => throw UnimplementedError();

  @override
  String Function()? get idGenerator => throw UnimplementedError();

  @override
  Future<void> acknowledge(String messageId) => throw UnimplementedError();

  @override
  Future<QueueMessage<T>?> dequeue() => throw UnimplementedError();

  @override
  void dispose() => throw UnimplementedError();

  @override
  Future<void> enqueue(QueueMessage<T> message) => throw UnimplementedError();

  @override
  Future<void> enqueuePayload(T payload) => throw UnimplementedError();

  @override
  Future<QueueMessage<T>?> reject(String messageId, {bool requeue = true}) =>
      throw UnimplementedError();
}

class MyEventQueueFactory {
  Future<Queue<T>> createQueue<T>(
    String queueName, {
    QueueConfiguration? configuration,
    Queue<T>? deadLetterQueue,
    String Function()? idGenerator,
  }) async {
    // TODO: Implement your queue creation logic
    // Examples:
    // - Create AWS SQS queue with given name
    // - Create Redis list/stream with configuration
    // - Create database table for queue storage
    // - Create Google Cloud Pub/Sub topic/subscription
    // - Return MyEventQueue instance
    throw UnimplementedError('Replace with your actual queue implementation');
  }

  void cleanup() {
    // TODO: Implement cleanup logic
    // Examples:
    // - Delete all test queues
    // - Close database/Redis/cloud connections
    // - Clean up temporary resources
  }
}

void main() {
  // This test group is currently disabled since it's just an example
  // Remove the 'skip' parameter when you have a real implementation
  group(
    'My Custom EventQueue Implementation',
    () {
      late MyEventQueueFactory factory;

      // Factory function for creating your custom queues
      Future<Queue<T>> createMyQueue<T>(
        String queueName, {
        QueueConfiguration? configuration,
        Queue<T>? deadLetterQueue,
        String Function()? idGenerator,
      }) async {
        return factory.createQueue<T>(
          queueName,
          configuration: configuration,
          deadLetterQueue: deadLetterQueue,
          idGenerator: idGenerator,
        );
      }

      // Cleanup function
      void cleanupMyQueue() {
        factory.cleanup();
      }

      setUp(() {
        factory = MyEventQueueFactory();
      });

      // Run the generic functional tests with appropriate configuration
      runQueueTests<Queue<Order>>(
        implementationName: 'MyQueue',
        createQueue: createMyQueue<Order>,
        cleanup: cleanupMyQueue,
        config: QueueTestConfig
            .cloud, // Choose appropriate config: inMemory, cloud, aws, or custom
      );

      // Run the generic performance tests with appropriate configuration
      runPerformanceTests(
        implementationName: 'MyQueue',
        createOrderQueue: createMyQueue<Order>,
        createBenchmarkQueue: createMyQueue<BenchmarkMessage>,
        cleanup: cleanupMyQueue,
        config: QueueTestConfig
            .cloud, // Adjust based on your implementation's expected performance
      );

      // Add implementation-specific tests
      group('MyQueue - Implementation-Specific Features', () {
        test('should handle custom configuration options', () async {
          // Test your implementation's specific features:
          // - Custom serialization formats
          // - Implementation-specific configuration
          // - Backend-specific optimizations
          // - Protocol-specific behavior
          expect(true, isTrue); // Placeholder
        });

        test('should handle connection management', () async {
          // Test connection-specific scenarios:
          // - Connection pooling
          // - Reconnection logic
          // - Authentication/authorization
          // - Network error handling
          expect(true, isTrue); // Placeholder
        });

        test('should handle backend-specific behavior', () async {
          // Test backend-specific behavior:
          // - Persistence guarantees
          // - Ordering guarantees
          // - Transactional behavior
          // - Clustering/sharding
          expect(true, isTrue); // Placeholder
        });
      });
    },
    skip: 'Example only - implement MyEventQueue first',
  );
}

/* 
Usage Example:

To test your own EventQueue implementation:

1. Replace MyEventQueue with your actual implementation
2. Implement MyEventQueueFactory to create real queues for your backend
3. Remove the 'skip' parameter from the group
4. Choose appropriate QueueTestConfig:
   - QueueTestConfig.inMemory: For fast, local implementations
   - QueueTestConfig.cloud: For general cloud services
   - QueueTestConfig.aws: For AWS SQS specifically
   - Custom config: For specialized requirements

5. Run: dart test test/my_queue_example_test.dart

The generic test suite will automatically:
- Test all EventQueue interface methods
- Validate queue behavior (visibility timeout, DLQ, etc.)
- Run performance tests with appropriate expectations
- Measure latency with implementation-appropriate thresholds

Example implementations this pattern supports:
- AWS SQS: Use QueueTestConfig.aws (high latency tolerance)
- Redis: Use QueueTestConfig.cloud (moderate expectations)
- PostgreSQL: Use QueueTestConfig.cloud (database-backed)
- Google Pub/Sub: Use QueueTestConfig.cloud (cloud service)
- RabbitMQ: Use QueueTestConfig.inMemory or custom (depends on setup)
- Apache Kafka: Use custom config (high throughput expectations)
*/
