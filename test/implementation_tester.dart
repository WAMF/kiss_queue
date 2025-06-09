import 'package:kiss_queue/kiss_queue.dart';

import 'benchmark_models.dart';
import 'performance_test_suite.dart';
import 'queue_test_suite.dart';

class ImplementationTester {
  final String implementationName;
  final QueueFactory factory;
  final Function() tearDown;

  ImplementationTester(this.implementationName, this.factory, this.tearDown);

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

  void run() {
    runQueueTests<Queue<Order>>(
      implementationName: implementationName,
      createQueue: createInMemoryQueue<Order>,
      cleanup: tearDown,
      config: QueueTestConfig.inMemory,
      factoryProvider: () =>
          factory, // Factory provider for generic factory tests
    );

    runPerformanceTests(
      implementationName: implementationName,
      createOrderQueue: createInMemoryQueue<Order>,
      createBenchmarkQueue: createInMemoryQueue<BenchmarkMessage>,
      cleanup: tearDown,
      config: QueueTestConfig.inMemory,
    );
  }
}
