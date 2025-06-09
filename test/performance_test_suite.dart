import 'package:kiss_queue/kiss_queue.dart';
import 'package:test/test.dart';
import 'dart:async';
import 'queue_test_suite.dart'; // Import our test config

// Sample data for performance testing
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

/// Generic performance test suite that can benchmark any EventQueue implementation
void runPerformanceTests({
  required String implementationName,
  required QueueFactoryFunction<Order> createOrderQueue,
  required QueueFactoryFunction<BenchmarkMessage> createBenchmarkQueue,
  required QueueCleanup cleanup,
  required QueueTestConfig config,
}) {
  group('$implementationName - Performance and Load Testing', () {
    tearDown(() {
      cleanup();
    });

    test('should measure basic operation performance', () async {
      // Arrange
      final queue = await createOrderQueue(
        'performance-queue',
        configuration: QueueConfiguration.highThroughput,
      );

      final order = Order(
        orderId: 'PERF-001',
        customerId: 'CUST-PERF',
        amount: 100.0,
        items: ['Performance Item'],
      );

      final messageCount = config.performanceTestMessageCount;

      // Test enqueue performance
      final enqueueStart = DateTime.now();
      for (int i = 0; i < messageCount; i++) {
        await queue.enqueue(QueueMessage.create(order));
      }
      final enqueueEnd = DateTime.now();
      final enqueueDuration = enqueueEnd.difference(enqueueStart);

      print(
        'Enqueue Performance: $messageCount messages in ${enqueueDuration.inMilliseconds}ms',
      );
      print(
        'Enqueue Rate: ${(messageCount / enqueueDuration.inMilliseconds * 1000).toStringAsFixed(2)} msg/sec',
      );

      // Test dequeue performance
      final dequeueStart = DateTime.now();
      final dequeuedMessages = <QueueMessage<Order>>[];
      for (int i = 0; i < messageCount; i++) {
        final msg = await queue.dequeue();
        if (msg != null) {
          dequeuedMessages.add(msg);
        }
      }
      final dequeueEnd = DateTime.now();
      final dequeueDuration = dequeueEnd.difference(dequeueStart);

      print(
        'Dequeue Performance: ${dequeuedMessages.length} messages in ${dequeueDuration.inMilliseconds}ms',
      );
      print(
        'Dequeue Rate: ${(dequeuedMessages.length / dequeueDuration.inMilliseconds * 1000).toStringAsFixed(2)} msg/sec',
      );

      // Test acknowledge performance
      final ackStart = DateTime.now();
      for (final msg in dequeuedMessages) {
        await queue.acknowledge(msg.id);
      }
      final ackEnd = DateTime.now();
      final ackDuration = ackEnd.difference(ackStart);

      print(
        'Acknowledge Performance: ${dequeuedMessages.length} messages in ${ackDuration.inMilliseconds}ms',
      );
      print(
        'Acknowledge Rate: ${(dequeuedMessages.length / ackDuration.inMilliseconds * 1000).toStringAsFixed(2)} msg/sec',
      );

      // Assert reasonable performance using config expectations
      expect(
        enqueueDuration.inMilliseconds,
        lessThan(config.performanceTestTimeoutMs),
      );
      expect(
        dequeueDuration.inMilliseconds,
        lessThan(config.performanceTestTimeoutMs),
      );
      expect(
        ackDuration.inMilliseconds,
        lessThan(config.performanceTestTimeoutMs),
      );
      expect(dequeuedMessages.length, equals(messageCount));
    });

    test('should handle high-volume load test', () async {
      // Arrange
      final queue = await createOrderQueue(
        'load-test-queue',
        configuration: QueueConfiguration.highThroughput,
      );

      final messageCount = config.loadTestMessageCount;
      print('\n=== Load Test: Processing $messageCount messages ===');

      // Generate test data
      final orders = List.generate(
        messageCount,
        (i) => Order(
          orderId: 'LOAD-${i.toString().padLeft(5, '0')}',
          customerId: 'CUST-${i % 100}', // 100 different customers
          amount: (i % 1000) / 10.0, // Varying amounts
          items: ['Item-$i'],
        ),
      );

      // Phase 1: Bulk enqueue
      final enqueueStart = DateTime.now();
      for (final order in orders) {
        await queue.enqueue(QueueMessage.create(order));
      }
      final enqueueEnd = DateTime.now();
      final enqueueDuration = enqueueEnd.difference(enqueueStart);

      print(
        'Bulk Enqueue: $messageCount messages in ${enqueueDuration.inMilliseconds}ms',
      );
      print(
        'Enqueue Throughput: ${(messageCount / enqueueDuration.inMilliseconds * 1000).toStringAsFixed(2)} msg/sec',
      );

      // Verify messages were enqueued successfully by dequeuing one
      final testMessage = await queue.dequeue();
      expect(testMessage, isNotNull);
      // Put it back for processing
      await queue.enqueue(testMessage!);

      // Phase 2: Bulk process (dequeue + acknowledge)
      final processStart = DateTime.now();
      int processedCount = 0;

      while (processedCount < messageCount) {
        final msg = await queue.dequeue();
        if (msg != null) {
          await queue.acknowledge(msg.id);
          processedCount++;
        }
      }

      final processEnd = DateTime.now();
      final processDuration = processEnd.difference(processStart);

      print(
        'Bulk Process: $messageCount messages in ${processDuration.inMilliseconds}ms',
      );
      print(
        'Process Throughput: ${(messageCount / processDuration.inMilliseconds * 1000).toStringAsFixed(2)} msg/sec',
      );

      // Final verification - queue should be empty
      final finalMessage = await queue.dequeue();
      expect(finalMessage, isNull);

      // Performance assertions using config expectations
      expect(
        enqueueDuration.inMilliseconds,
        lessThan(config.loadTestTimeoutMs),
      );
      expect(
        processDuration.inMilliseconds,
        lessThan(config.loadTestTimeoutMs),
      );

      print('=== Load Test Complete ===\n');
    });

    test('should handle concurrent processing load', () async {
      // Arrange
      final queue = await createOrderQueue(
        'concurrent-queue',
        configuration: const QueueConfiguration(
          maxReceiveCount: 3,
          visibilityTimeout: Duration(
            seconds: 5,
          ), // Longer timeout for concurrent test
        ),
      );

      final messageCount = config.concurrentMessageCount;
      final workerCount = config.concurrentWorkerCount;
      print(
        '\n=== Concurrent Load Test: $workerCount workers processing $messageCount messages ===',
      );

      // Enqueue test messages
      for (int i = 0; i < messageCount; i++) {
        final order = Order(
          orderId: 'CONCURRENT-${i.toString().padLeft(4, '0')}',
          customerId: 'CUST-${i % 50}',
          amount: (i % 500) / 10.0,
          items: ['Concurrent Item $i'],
        );
        await queue.enqueue(QueueMessage.create(order));
      }

      // Create concurrent workers
      final processStart = DateTime.now();
      final processedOrders = <String>[];
      final completers = <Completer<int>>[];

      for (int workerId = 0; workerId < workerCount; workerId++) {
        final completer = Completer<int>();
        completers.add(completer);

        // Start worker
        _startWorker(workerId, queue, processedOrders, completer);
      }

      // Wait for all workers to complete
      final workerResults = await Future.wait(
        completers.map((c) => c.future),
      ).timeout(Duration(milliseconds: config.concurrentTimeoutMs));
      final processEnd = DateTime.now();
      final processDuration = processEnd.difference(processStart);

      final totalProcessed = workerResults.reduce((a, b) => a + b);

      print(
        'Concurrent Processing: $totalProcessed messages in ${processDuration.inMilliseconds}ms',
      );
      print(
        'Worker Distribution: ${workerResults.join(', ')} messages per worker',
      );
      print(
        'Concurrent Throughput: ${(totalProcessed / processDuration.inMilliseconds * 1000).toStringAsFixed(2)} msg/sec',
      );

      // Verify results
      expect(totalProcessed, equals(messageCount));
      expect(
        processedOrders.toSet().length,
        equals(messageCount),
      ); // No duplicates

      // Verify queue is empty after processing
      final finalCheck = await queue.dequeue();
      expect(finalCheck, isNull);

      print('=== Concurrent Load Test Complete ===\n');
    });

    test('should measure end-to-end latency', () async {
      // Arrange
      final queue = await createOrderQueue(
        'latency-queue',
        configuration: QueueConfiguration.testing,
      );

      const testRuns = 100;
      final latencies = <Duration>[];

      print('\n=== Latency Test: Measuring end-to-end processing time ===');

      // Measure latency for multiple runs
      for (int i = 0; i < testRuns; i++) {
        final order = Order(
          orderId: 'LATENCY-${i.toString().padLeft(3, '0')}',
          customerId: 'CUST-LATENCY',
          amount: 100.0,
          items: ['Latency Test Item'],
        );

        final startTime = DateTime.now();

        // Enqueue
        await queue.enqueue(QueueMessage.create(order));

        // Dequeue
        final msg = await queue.dequeue();
        expect(msg, isNotNull);

        // Acknowledge
        await queue.acknowledge(msg!.id);

        final endTime = DateTime.now();
        latencies.add(endTime.difference(startTime));
      }

      // Calculate statistics
      final avgLatency =
          latencies.map((d) => d.inMicroseconds).reduce((a, b) => a + b) /
          testRuns;
      final minLatency = latencies
          .map((d) => d.inMicroseconds)
          .reduce((a, b) => a < b ? a : b);
      final maxLatency = latencies
          .map((d) => d.inMicroseconds)
          .reduce((a, b) => a > b ? a : b);

      // Sort for percentile calculations
      final sortedLatencies = latencies.map((d) => d.inMicroseconds).toList()
        ..sort();
      final p50 = sortedLatencies[(testRuns * 0.5).floor()];
      final p95 = sortedLatencies[(testRuns * 0.95).floor()];
      final p99 = sortedLatencies[(testRuns * 0.99).floor()];

      print('Latency Statistics (microseconds):');
      print('  Average: ${avgLatency.toStringAsFixed(2)}μs');
      print('  Min: $minLatency μs');
      print('  Max: $maxLatency μs');
      print('  P50: $p50 μs');
      print('  P95: $p95 μs');
      print('  P99: $p99 μs');

      // Assert reasonable latency using config expectations
      expect(avgLatency, lessThan(config.maxAverageLatencyUs));
      expect(p95, lessThan(config.maxP95LatencyUs));

      print('=== Latency Test Complete ===\n');
    });

    test('should handle memory pressure test', () async {
      print('\n=== Memory Pressure Test ===');

      // Create large payload for memory testing
      final largeItems = List.generate(
        100,
        (i) => 'Large Item Data $i with extra padding to increase memory usage',
      );

      const batchSize = 1000;
      const batches = 5;

      for (int batch = 0; batch < batches; batch++) {
        // Create fresh queue for each batch size to avoid accumulation
        final batchQueue = await createOrderQueue(
          'memory-batch-$batch',
          configuration: QueueConfiguration.highThroughput,
        );

        print('Processing batch ${batch + 1}/$batches...');

        // Enqueue batch
        for (int i = 0; i < batchSize; i++) {
          final order = Order(
            orderId:
                'MEMORY-${batch.toString().padLeft(2, '0')}-${i.toString().padLeft(4, '0')}',
            customerId: 'CUST-MEMORY-${i % 10}',
            amount: (i % 1000) / 10.0,
            items: largeItems,
          );
          await batchQueue.enqueue(QueueMessage.create(order));
        }

        // Process batch immediately to test memory cleanup
        for (int i = 0; i < batchSize; i++) {
          final msg = await batchQueue.dequeue();
          expect(msg, isNotNull);
          await batchQueue.acknowledge(msg!.id);
        }

        // Verify cleanup - no more messages
        final noMoreMessages = await batchQueue.dequeue();
        expect(noMoreMessages, isNull);

        // Small delay to allow garbage collection
        await Future.delayed(const Duration(milliseconds: 10));
      }

      print(
        'Memory test completed: ${batchSize * batches} large messages processed',
      );
      print('=== Memory Pressure Test Complete ===\n');
    });
  });
}

// Helper method for concurrent worker
void _startWorker(
  int workerId,
  Queue<Order> queue,
  List<String> processedOrders,
  Completer<int> completer,
) {
  int processedCount = 0;
  int consecutiveEmptyPolls = 0;
  const maxEmptyPolls = 50; // Wait for 50ms of empty polls before giving up

  Timer.periodic(const Duration(milliseconds: 1), (timer) async {
    try {
      final msg = await queue.dequeue();
      if (msg != null) {
        // Reset empty poll counter
        consecutiveEmptyPolls = 0;

        // Simulate some processing time
        await Future.delayed(const Duration(microseconds: 100));

        await queue.acknowledge(msg.id);
        processedOrders.add(msg.payload.orderId);
        processedCount++;
      } else {
        // Increment empty poll counter
        consecutiveEmptyPolls++;

        // Only complete after several consecutive empty polls
        if (consecutiveEmptyPolls >= maxEmptyPolls) {
          timer.cancel();
          completer.complete(processedCount);
        }
      }
    } catch (e) {
      timer.cancel();
      completer.completeError(e);
    }
  });
}
