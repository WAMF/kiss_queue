import 'package:kiss_queue/kiss_queue.dart';
import 'package:test/test.dart';
import 'dart:async';
import 'benchmark_models.dart';

void main() {
  group('Kiss Queue Performance Benchmarks', () {
    late InMemoryQueueFactory factory;

    setUp(() {
      factory = InMemoryQueueFactory();
    });

    tearDown(() {
      factory.disposeAll();
    });

    test('Benchmark: Single Operation Performance', () async {
      final queue = await factory.createQueue<BenchmarkMessage>(
        'benchmark-single',
        configuration: QueueConfiguration.highThroughput,
      );

      final message = BenchmarkMessage(
        id: 'bench-001',
        data: 'x' * 1024, // 1KB payload
        timestamp: DateTime.now(),
        metadata: {'type': 'benchmark', 'size': 1024},
      );

      const iterations = 10000;

      print('\n🚀 SINGLE OPERATION BENCHMARK');
      print('=' * 50);

      // Benchmark enqueue
      final enqueueTimes = <int>[];
      for (int i = 0; i < iterations; i++) {
        final start = DateTime.now().microsecondsSinceEpoch;
        await queue.enqueue(QueueMessage.create(message));
        final end = DateTime.now().microsecondsSinceEpoch;
        enqueueTimes.add(end - start);
      }

      // Benchmark dequeue
      final dequeueTimes = <int>[];
      for (int i = 0; i < iterations; i++) {
        final start = DateTime.now().microsecondsSinceEpoch;
        final msg = await queue.dequeue();
        final end = DateTime.now().microsecondsSinceEpoch;
        dequeueTimes.add(end - start);
        if (msg != null) {
          await queue.acknowledge(msg.id);
        }
      }

      _printStats('Enqueue', enqueueTimes);
      _printStats('Dequeue', dequeueTimes);

      expect(enqueueTimes.isNotEmpty, true);
      expect(dequeueTimes.isNotEmpty, true);
    });

    test('Benchmark: Throughput Test (Various Message Sizes)', () async {
      print('\n📊 THROUGHPUT BENCHMARK');
      print('=' * 50);

      final messageSizes = [100, 1024, 10240, 102400]; // 100B, 1KB, 10KB, 100KB

      for (final size in messageSizes) {
        final queue = await factory.createQueue<BenchmarkMessage>(
          'throughput-$size',
          configuration: QueueConfiguration.highThroughput,
        );

        final message = BenchmarkMessage(
          id: 'throughput-$size',
          data: 'x' * size,
          timestamp: DateTime.now(),
          metadata: {'size': size},
        );

        const messageCount = 5000;

        // Enqueue throughput
        final enqueueStart = DateTime.now();
        for (int i = 0; i < messageCount; i++) {
          await queue.enqueue(QueueMessage.create(message));
        }
        final enqueueEnd = DateTime.now();
        final enqueueDuration = enqueueEnd.difference(enqueueStart);

        // Dequeue + Acknowledge throughput
        final processStart = DateTime.now();
        for (int i = 0; i < messageCount; i++) {
          final msg = await queue.dequeue();
          if (msg != null) {
            await queue.acknowledge(msg.id);
          }
        }
        final processEnd = DateTime.now();
        final processDuration = processEnd.difference(processStart);

        final enqueueRate =
            messageCount / enqueueDuration.inMilliseconds * 1000;
        final processRate =
            messageCount / processDuration.inMilliseconds * 1000;
        final enqueueThroughput = (size * enqueueRate) / (1024 * 1024); // MB/s
        final processThroughput = (size * processRate) / (1024 * 1024); // MB/s

        print('Message Size: ${_formatBytes(size)}');
        print(
          '  Enqueue: ${enqueueRate.toStringAsFixed(0)} msg/s (${enqueueThroughput.toStringAsFixed(2)} MB/s)',
        );
        print(
          '  Process: ${processRate.toStringAsFixed(0)} msg/s (${processThroughput.toStringAsFixed(2)} MB/s)',
        );
        print('');
      }
    });

    test('Benchmark: Concurrent Processing Scalability', () async {
      print('\n⚡ CONCURRENT PROCESSING BENCHMARK');
      print('=' * 50);

      const messageCount = 2000;
      final workerCounts = [1, 2, 4, 8, 16];

      for (final workerCount in workerCounts) {
        final queue = await factory.createQueue<BenchmarkMessage>(
          'concurrent-$workerCount',
          configuration: const QueueConfiguration(
            maxReceiveCount: 3,
            visibilityTimeout: Duration(seconds: 10),
          ),
        );

        // Populate queue
        for (int i = 0; i < messageCount; i++) {
          final message = BenchmarkMessage(
            id: 'concurrent-$workerCount-$i',
            data: 'benchmark data for message $i',
            timestamp: DateTime.now(),
            metadata: {'worker_count': workerCount, 'message_id': i},
          );
          await queue.enqueue(QueueMessage.create(message));
        }

        // Start concurrent processing
        final processStart = DateTime.now();
        final completers = <Completer<int>>[];
        final processedMessages = <String>[];

        for (int workerId = 0; workerId < workerCount; workerId++) {
          final completer = Completer<int>();
          completers.add(completer);
          _startBenchmarkWorker(workerId, queue, processedMessages, completer);
        }

        final results = await Future.wait(completers.map((c) => c.future));
        final processEnd = DateTime.now();
        final processDuration = processEnd.difference(processStart);

        final totalProcessed = results.reduce((a, b) => a + b);
        final throughput =
            totalProcessed / processDuration.inMilliseconds * 1000;
        final efficiency =
            throughput / workerCount; // Messages per worker per second

        print('Workers: $workerCount');
        print(
          '  Total: $totalProcessed messages in ${processDuration.inMilliseconds}ms',
        );
        print('  Throughput: ${throughput.toStringAsFixed(0)} msg/s');
        print('  Efficiency: ${efficiency.toStringAsFixed(0)} msg/s/worker');
        print('');

        expect(totalProcessed, equals(messageCount));
      }
    });

    test('Benchmark: Memory Usage Pattern', () async {
      print('\n💾 MEMORY USAGE BENCHMARK');
      print('=' * 50);

      // Note: Individual queues created per batch to avoid accumulation

      final batchSizes = [1000, 5000, 10000, 25000];

      for (final batchSize in batchSizes) {
        // Create fresh queue for each batch size to avoid accumulation
        final batchQueue = await factory.createQueue<BenchmarkMessage>(
          'memory-batch-$batchSize',
          configuration: QueueConfiguration.highThroughput,
        );

        print('Testing batch size: $batchSize messages');

        // Create large messages for memory testing
        final largeData = 'x' * 10240; // 10KB per message

        // Enqueue batch
        final enqueueStart = DateTime.now();
        for (int i = 0; i < batchSize; i++) {
          final message = BenchmarkMessage(
            id: 'memory-$batchSize-$i',
            data: largeData,
            timestamp: DateTime.now(),
            metadata: {'batch': batchSize, 'index': i},
          );
          await batchQueue.enqueue(QueueMessage.create(message));
        }
        final enqueueEnd = DateTime.now();

        // Verify messages were enqueued by checking one
        final testMessage = await batchQueue.dequeue();
        expect(testMessage, isNotNull);
        // Put it back for processing
        await batchQueue.enqueue(testMessage!);

        // Process batch
        final processStart = DateTime.now();
        for (int i = 0; i < batchSize; i++) {
          final msg = await batchQueue.dequeue();
          if (msg != null) {
            await batchQueue.acknowledge(msg.id);
          }
        }
        final processEnd = DateTime.now();

        // Verify cleanup - queue should be empty
        final noMoreMessages = await batchQueue.dequeue();
        expect(noMoreMessages, isNull);

        final enqueueTime = enqueueEnd.difference(enqueueStart);
        final processTime = processEnd.difference(processStart);
        final totalDataMB = (batchSize * largeData.length) / (1024 * 1024);

        print(
          '  Enqueue: ${enqueueTime.inMilliseconds}ms (${totalDataMB.toStringAsFixed(1)} MB)',
        );
        print('  Process: ${processTime.inMilliseconds}ms');
        print('  Memory cleaned: ✓');
        print('');
      }
    });

    test('Benchmark: Dead Letter Queue Performance', () async {
      print('\n☠️ DEAD LETTER QUEUE BENCHMARK');
      print('=' * 50);

      final dlq = await factory.createQueue<BenchmarkMessage>(
        'dlq-benchmark',
        configuration: QueueConfiguration.testing,
      );

      final queue = await factory.createQueue<BenchmarkMessage>(
        'main-dlq-benchmark',
        configuration: const QueueConfiguration(
          maxReceiveCount: 2,
          visibilityTimeout: Duration(milliseconds: 50),
        ),
        deadLetterQueue: dlq,
      );

      const poisonMessageCount = 100;

      // Create poison messages that will fail and move to DLQ
      final enqueueStart = DateTime.now();
      for (int i = 0; i < poisonMessageCount; i++) {
        final message = BenchmarkMessage(
          id: 'poison-$i',
          data: 'poison message $i',
          timestamp: DateTime.now(),
          metadata: {'type': 'poison', 'id': i},
        );
        await queue.enqueue(QueueMessage.create(message));
      }
      final enqueueEnd = DateTime.now();

      // Process and fail messages to trigger DLQ movement
      final processStart = DateTime.now();
      int attempts = 0;
      while (attempts < poisonMessageCount * 3) {
        // 3 attempts per message max
        final msg = await queue.dequeue();
        if (msg != null) {
          await queue.reject(msg.id, requeue: true);
          attempts++;
        } else {
          break; // No more messages in main queue
        }
      }
      final processEnd = DateTime.now();

      // Verify DLQ contains poison messages and main queue is empty
      final mainQueueEmpty = await queue.dequeue();
      expect(mainQueueEmpty, isNull);

      // Count messages in DLQ
      int dlqCount = 0;
      while (true) {
        final dlqMsg = await dlq.dequeue();
        if (dlqMsg == null) break;
        dlqCount++;
        // Put it back for verification
        await dlq.enqueue(dlqMsg);
      }

      final enqueueTime = enqueueEnd.difference(enqueueStart);
      final processTime = processEnd.difference(processStart);

      print('Poison messages: $poisonMessageCount');
      print('Enqueue time: ${enqueueTime.inMilliseconds}ms');
      print('Process time: ${processTime.inMilliseconds}ms');
      print('Main queue remaining: 0');
      print('DLQ messages: $dlqCount');
      print('Processing attempts: $attempts');

      expect(dlqCount, equals(poisonMessageCount));
    });
  });
}

void _printStats(String operation, List<int> times) {
  if (times.isEmpty) return;

  times.sort();
  final avg = times.reduce((a, b) => a + b) / times.length;
  final min = times.first;
  final max = times.last;
  final p50 = times[(times.length * 0.5).floor()];
  final p95 = times[(times.length * 0.95).floor()];
  final p99 = times[(times.length * 0.99).floor()];

  print('$operation Performance:');
  print('  Avg: ${avg.toStringAsFixed(1)}μs');
  print('  Min: $minμs');
  print('  Max: $maxμs');
  print('  P50: $p50μs');
  print('  P95: $p95μs');
  print('  P99: $p99μs');
  print('');
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}

void _startBenchmarkWorker(
  int workerId,
  Queue<BenchmarkMessage> queue,
  List<String> processedMessages,
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

        // Simulate processing time
        await Future.delayed(const Duration(microseconds: 50));

        await queue.acknowledge(msg.id);
        processedMessages.add(msg.payload.id);
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
