import 'package:kiss_queue/kiss_queue.dart';

import 'implementation_tester.dart';

void main() {
  final factory = InMemoryQueueFactory();
  final tester = ImplementationTester('InMemoryQueue', factory, () {
    factory.disposeAll();
  });

  tester.run();
}
