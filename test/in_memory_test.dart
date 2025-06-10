import 'package:kiss_queue/kiss_queue.dart';

import 'implementation_tester.dart';
import 'serialization_test.dart';

void main() {
  final factory = InMemoryQueueFactory();
  final tester = ImplementationTester('InMemoryQueue', factory, () {
    factory.disposeAll();
  });

  tester.run();

  final tester2 = ImplementationTester<String>(
    'InMemoryQueueSerializer',
    factory,
    () {
      factory.disposeAll();
    },
    serializer: JsonStringSerializer(),
  );

  tester2.run();

  final tester3 = ImplementationTester<String>(
    'InMemoryQueueCustomId',
    factory,
    () {
      factory.disposeAll();
    },
    serializer: JsonStringSerializer(),
    idGenerator: () => 'custom-id-${DateTime.now().millisecondsSinceEpoch}',
  );

  tester3.run();
}
