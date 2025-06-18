/*import 'package:kiss_queue/kiss_queue.dart';

import 'serialization_test.dart';

void main() {
  final defaultFactory = InMemoryQueueFactory<Order, Order>();
  final tester = ImplementationTester('InMemoryQueue', defaultFactory, () {
    defaultFactory.disposeAll();
  });

  tester.run();

  final serializerFactory = InMemoryQueueFactory<Order, String>(
    serializer: JsonStringSerializer(),
  );

  final tester2 = ImplementationTester<String>(
    'InMemoryQueueSerializer',
    serializerFactory,
    () {
      serializerFactory.disposeAll();
    },
  );

  tester2.run();

  final customIdFactory = InMemoryQueueFactory<Order, String>(
    serializer: JsonStringSerializer(),
    idGenerator: () => 'custom-id-${DateTime.now().millisecondsSinceEpoch}',
  );

  final tester3 = ImplementationTester<String>(
    'InMemoryQueueCustomId',
    customIdFactory,
    () {
      customIdFactory.disposeAll();
    },
  );

  tester3.run();
}*/
