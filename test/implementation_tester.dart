import 'package:kiss_queue/kiss_queue.dart';

import 'queue_test_suite.dart';
import 'test_models.dart';

class ImplementationTester<S> {
  final String implementationName;
  final QueueFactory factory;
  final MessageSerializer<Order, S>? serializer;
  final String Function()? idGenerator;
  final Function() tearDown;

  ImplementationTester(
    this.implementationName,
    this.factory,
    this.tearDown, {
    this.serializer,
    this.idGenerator,
  });

  void run() {
    runQueueTests<Queue<Order, S>, S>(
      implementationName: implementationName,
      cleanup: tearDown,
      config: QueueTestConfig.inMemory,
      serializer: serializer,
      idGenerator: idGenerator,
      factoryProvider: () =>
          factory, // Factory provider for generic factory tests
    );
  }
}
