import 'package:kiss_queue/kiss_queue.dart';
import 'package:kiss_queue_tests/kiss_queue_tests.dart';

import 'serialization_test.dart';

void main() {
  final test1Factory = InMemoryQueueFactory<Order, Order>();
  runQueueTests<InMemoryQueue<Order, Order>, Order>(
    implementationName: 'InMemoryQueue',
    factoryProvider: () => test1Factory,
    cleanup: () {
      test1Factory.disposeAll();
    },
  );

  final serializerFactory = InMemoryQueueFactory<Order, String>(
    serializer: JsonStringSerializer(),
  );

  runQueueTests<InMemoryQueue<Order, String>, String>(
    implementationName: 'InMemoryQueueSerializer',
    factoryProvider: () => serializerFactory,
    cleanup: () {
      serializerFactory.disposeAll();
    },
  );

  final customIdFactory = InMemoryQueueFactory<Order, String>(
    serializer: JsonStringSerializer(),
    idGenerator: () => 'custom-id-${DateTime.now().millisecondsSinceEpoch}',
  );

  runQueueTests<InMemoryQueue<Order, String>, String>(
    implementationName: 'InMemoryQueueCustomId',
    factoryProvider: () => customIdFactory,
    cleanup: () {
      customIdFactory.disposeAll();
    },
  );
}
