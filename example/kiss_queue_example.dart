import 'package:kiss_queue/kiss_queue.dart';

void main() async {
  // Create factory for managing queues
  final factory = InMemoryQueueFactory();

  print('=== Demonstrating Queue-Level Custom ID Generation ===\n');

  // Create a queue with a custom ID generator configured at the queue level
  int messageCounter = 1000;
  final queueWithCustomIds = await factory.createQueue<String, String>(
    'custom-id-queue',
    configuration: QueueConfiguration.defaultConfig,
    idGenerator: () => 'MSG-${messageCounter++}',
  );

  // Now all messages use the custom ID generator automatically
  await queueWithCustomIds.enqueuePayload('Hello with queue-level custom IDs!');
  await queueWithCustomIds.enqueuePayload('Another message with auto ID!');

  print('=== Demonstrating Multiple ID Generation Methods ===\n');

  // Create a standard queue (uses UUID by default)
  final standardQueue = await factory.createQueue<String, String>(
    'standard-queue',
    configuration: QueueConfiguration.defaultConfig,
  );

  // Method 1: Queue helper with auto-generated ID (uses queue's idGenerator or UUID)
  await standardQueue.enqueuePayload('Hello with enqueuePayload helper!');

  // Method 2: Most common - just provide the payload (auto-generated ID and timestamp)
  await standardQueue.enqueue(QueueMessage.create('Hello, simplified world!'));

  // Method 3: Default constructor with optional parameters
  await standardQueue.enqueue(QueueMessage(payload: 'Hello with defaults!'));

  // Method 4: Explicit ID when needed (e.g., for testing or specific requirements)
  await standardQueue.enqueue(
    QueueMessage.withId(id: 'custom-id-123', payload: 'Hello with custom ID!'),
  );

  // Method 5: Per-message custom ID generation function (overrides queue-level)
  int perMessageCounter = 2000;
  await standardQueue.enqueue(
    QueueMessage.create(
      'Hello with per-message ID generator!',
      idGenerator: () => 'PER-MSG-${perMessageCounter++}',
    ),
  );

  print('Enqueued messages with different ID generation methods\n');

  // Process messages from the custom ID queue
  print('=== Processing Custom ID Queue Messages ===\n');
  for (int i = 1; i <= 2; i++) {
    final message = await queueWithCustomIds.dequeue();
    if (message != null) {
      print('Custom Queue Message $i:');
      print('  ID: ${message.id}');
      print('  Payload: ${message.payload}');
      print('  Created: ${message.createdAt}');
      print('  Processed: ${message.processedAt}');
      print('');

      // Acknowledge successful processing
      await queueWithCustomIds.acknowledge(message.id);
      print('  ✓ Message acknowledged\n');
    }
  }

  // Process messages from the standard queue
  print('=== Processing Standard Queue Messages ===\n');
  for (int i = 1; i <= 5; i++) {
    final message = await standardQueue.dequeue();
    if (message != null) {
      print('Standard Queue Message $i:');
      print('  ID: ${message.id}');
      print('  Payload: ${message.payload}');
      print('  Created: ${message.createdAt}');
      print('  Processed: ${message.processedAt}');
      print('');

      // Acknowledge successful processing
      await standardQueue.acknowledge(message.id);
      print('  ✓ Message acknowledged\n');
    }
  }

  // Clean up
  factory.disposeAll();
  print('Queues disposed - example complete!');
}
