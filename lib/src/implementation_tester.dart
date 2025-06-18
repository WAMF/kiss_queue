import 'package:kiss_queue/kiss_queue.dart';

class ImplementationTester<S> {
  final String implementationName;
  final QueueFactory<Order, S> factory;
  final Function() tearDown;

  ImplementationTester(this.implementationName, this.factory, this.tearDown);

  void run() {
    runQueueTests<Queue<Order, S>, S>(
      implementationName: implementationName,
      cleanup: tearDown,
      factoryProvider: () =>
          factory, // Factory provider for generic factory tests
    );
  }
}
