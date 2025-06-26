# kiss_queue

A simple, backend-agnostic queue interface for Dart — part of the [KISS](https://pub.dev/publishers/wearemobilefirst.com/packages) (Keep It Simple, Stupid) family of libraries.

## 🎯 Purpose

`kiss_queue` provides a unified, async queue interface that works with any backend. Whether you're building with in-memory queues for development, cloud-scale message queuing for production, or implementing custom database-backed queues, this library gives you a consistent API with enterprise-grade features.

Just queues. No ceremony. No complexity.

---

## ✨ Features

- 🔄 **Backend Agnostic**: Unified interface works with any queue implementation
- ⚡ **Production Ready**: Visibility timeouts, dead letter queues, message expiration
- 🔌 **Serialization Support**: Pluggable serialization for any data format (JSON, Binary, etc.)
- 🧪 **Comprehensive Testing**: Built-in test suite for validating any implementation  
- 📊 **Enterprise Ready**: Dead letter queues, visibility timeouts, message expiration
- 🚀 **High Performance**: Optimized interface for maximum throughput
- 🛡️ **Reliable**: SQS-like behavior with automatic message reprocessing
- 🎯 **Simple API**: Minimal interface - enqueue, dequeue, acknowledge, reject
- 📦 **Zero Dependencies**: Pure Dart implementation (except uuid for message IDs)

## 🚀 Quick Start

### Basic Usage

```dart
import 'package:kiss_queue/kiss_queue.dart';

void main() async {
  // Create a queue factory
  final factory = InMemoryQueueFactory();
  
  // Create a queue
  final queue = await factory.createQueue<String, String>('my-queue');
  
  // Enqueue a message (two equivalent ways)
  await queue.enqueue(QueueMessage.create('Hello, World!'));
  await queue.enqueuePayload('Hello, simplified!'); // Shorthand
  
  // Dequeue and process
  final message = await queue.dequeue();
  if (message != null) {
    print('Received: ${message.payload}');
    await queue.acknowledge(message.id);
  }
  
  // Cleanup
  factory.disposeAll();
}
```

### Serialization Example

```dart
import 'dart:convert';
import 'package:kiss_queue/kiss_queue.dart';

class Order {
  final String orderId;
  final double amount;
  Order(this.orderId, this.amount);
  
  // Serialization methods
  Map<String, dynamic> toJson() => {'orderId': orderId, 'amount': amount};
  static Order fromJson(Map<String, dynamic> json) => 
      Order(json['orderId'], json['amount']);
}

// Custom JSON serializer
class OrderJsonSerializer implements MessageSerializer<Order, String> {
  @override
  String serialize(Order payload) => jsonEncode(payload.toJson());
  
  @override
  Order deserialize(String data) => Order.fromJson(jsonDecode(data));
}

void main() async {
  final factory = InMemoryQueueFactory();
  
  // Create queue with serialization
  final queue = await factory.createQueue<Order, String>(
    'order-queue',
    serializer: OrderJsonSerializer(),
  );
  
  // Both methods work with serialization
  final order = Order('ORD-123', 99.99);
  await queue.enqueuePayload(order);              // Serializes automatically
  await queue.enqueue(QueueMessage.create(order)); // Also serializes
  
  // Dequeue automatically deserializes
  final message = await queue.dequeue();
  if (message != null) {
    print('Order: ${message.payload.orderId}'); // Fully typed Order object
    await queue.acknowledge(message.id);
  }
  
  factory.disposeAll();
}
```

### Advanced Usage with Error Handling

```dart
import 'package:kiss_queue/kiss_queue.dart';

class Order {
  final String orderId;
  final double amount;
  
  Order(this.orderId, this.amount);
}

void main() async {
  final factory = InMemoryQueueFactory();
  
  // Create main queue with dead letter queue for failed messages
  final deadLetterQueue = await factory.createQueue<Order, Order>('failed-orders');
  final orderQueue = await factory.createQueue<Order, Order>(
    'orders',
    configuration: QueueConfiguration.highThroughput,
    deadLetterQueue: deadLetterQueue,
  );
  
  // Enqueue an order
  final order = Order('ORD-123', 99.99);
  await orderQueue.enqueuePayload(order); // Simple payload enqueue
  
  // Process with error handling
  final message = await orderQueue.dequeue();
  if (message != null) {
    try {
      await processOrder(message.payload);
      await orderQueue.acknowledge(message.id);
    } catch (e) {
      // Reject and requeue for retry (will move to DLQ after max attempts)
      await orderQueue.reject(message.id, requeue: true);
    }
  }
  
  // Queue operations completed successfully
  print('Order processing complete!');
  
  factory.disposeAll();
}

Future<void> processOrder(Order order) async {
  // Your order processing logic here
  print('Processing order ${order.orderId} for \$${order.amount}');
}
```

## 🏗️ Architecture

### Core Interface

```dart
abstract class Queue<T, S> {
  // Queue configuration and dead letter queue  
  QueueConfiguration get configuration;
  Queue<T, S>? get deadLetterQueue;
  String Function()? get idGenerator;
  MessageSerializer<T, S>? get serializer;
  
  // Core operations
  Future<void> enqueue(QueueMessage<T> message);
  Future<void> enqueuePayload(T payload);           // Shorthand helper
  Future<QueueMessage<T>?> dequeue();
  Future<void> acknowledge(String messageId);
  Future<QueueMessage<T>?> reject(String messageId, {bool requeue = true});
  
  // Cleanup
  void dispose();
}
```

### QueueFactory Interface

```dart
abstract class QueueFactory<T, S> {
  Future<Queue<T, S>> createQueue(
    String queueName, {
    QueueConfiguration? configuration,
    Queue<T, S>? deadLetterQueue,
  });
  
  Future<Queue<T, S>> getQueue(String queueName);
  Future<void> deleteQueue(String queueName);
}
```

### Serialization Interface

```dart
abstract class MessageSerializer<T, S> {
  /// Serialize payload to storage format
  S serialize(T payload);
  
  /// Deserialize from storage format back to payload
  T deserialize(S data);
}
```

### Message Lifecycle

1. **Enqueue**: Add message to queue (with optional serialization)
2. **Dequeue**: Retrieve message (becomes invisible to other consumers, with optional deserialization)  
3. **Process**: Handle the message in your application
4. **Acknowledge**: Mark message as successfully processed (removes from queue)
5. **Reject**: Mark message as failed (can requeue for retry or move to DLQ)

### Built-in Reliability Features

- **Visibility Timeout**: Messages become invisible after dequeue, automatically restored if not acknowledged
- **Dead Letter Queue**: Failed messages move to DLQ after max retry attempts
- **Message Expiration**: Optional TTL for automatic message cleanup
- **Receive Count Tracking**: Monitor how many times a message has been processed
- **Serialization Support**: Automatic serialization/deserialization with pluggable serializers

## 🔌 Serialization

### Built-in Serialization Patterns

The queue supports flexible serialization through the `MessageSerializer<T, S>` interface, where:
- `T` is your payload type (e.g., `Order`, `User`)
- `S` is the storage format (e.g., `String`, `Map<String, dynamic>`, `List<int>`)

### Common Serialization Examples

#### JSON String Serialization
```dart
class JsonStringSerializer<T> implements MessageSerializer<T, String> {
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;
  
  JsonStringSerializer({required this.fromJson, required this.toJson});
  
  @override
  String serialize(T payload) => jsonEncode(toJson(payload));
  
  @override
  T deserialize(String data) => fromJson(jsonDecode(data));
}

// Usage
final queue = await factory.createQueue<Order, String>(
  'orders',
  serializer: JsonStringSerializer<Order>(
    fromJson: Order.fromJson,
    toJson: (order) => order.toJson(),
  ),
);
```

#### Binary Serialization
```dart
class BinarySerializer<T> implements MessageSerializer<T, List<int>> {
  final JsonStringSerializer<T> _jsonSerializer;
  
  BinarySerializer(this._jsonSerializer);
  
  @override
  List<int> serialize(T payload) {
    final jsonString = _jsonSerializer.serialize(payload);
    return utf8.encode(jsonString);
  }
  
  @override
  T deserialize(List<int> data) {
    final jsonString = utf8.decode(data);
    return _jsonSerializer.deserialize(jsonString);
  }
}
```

#### No Serialization (Direct Storage)
```dart
// When T == S, no serializer is needed
final queue = await factory.createQueue<String, String>('simple-queue');
await queue.enqueuePayload('Direct string storage');
```

### Serialization Error Handling

```dart
try {
  await queue.enqueuePayload(complexObject);
} on SerializationError catch (e) {
  print('Failed to serialize: ${e.message}');
}

try {
  final message = await queue.dequeue();
} on DeserializationError catch (e) {
  print('Failed to deserialize: ${e.message}');
  print('Raw data: ${e.data}');
}
```

## 📦 Implementations

### In-Memory Queue (Included)

Perfect for development, testing, and single-instance applications:

```dart
// Basic factory
final factory = InMemoryQueueFactory();

// Factory with default ID generator and serializer
final factory = InMemoryQueueFactory<MyData, String>(
  idGenerator: () => 'MSG-${DateTime.now().millisecondsSinceEpoch}',
  serializer: MySerializer(),
);

final queue = await factory.createQueue<MyData, String>('my-queue');
```

### Custom Implementations

The generic interface makes it easy to implement queues for any backend:

- **Cloud Providers**: Cloud-scale message queuing with built-in serialization
- **Google Cloud Pub/Sub**: Global message distribution  
- **Redis**: High-performance in-memory queuing
- **PostgreSQL/MySQL**: Database-backed persistence with JSON/binary serialization
- **Apache Kafka**: High-throughput event streaming
- **RabbitMQ**: Feature-rich message broker

## 🧪 Instant Implementation Testing

**Test any queue implementation instantly with one line of code!** 

The `ImplementationTester` class provides 87 comprehensive tests that validate any custom queue implementation automatically. No need to write your own tests - just provide your factory and let the tester do the work.

### Zero-Effort Testing

```dart
// test/my_implementation_test.dart
import 'package:kiss_queue/kiss_queue.dart';
import 'implementation_tester.dart';

void main() {
  final factory = MyCustomQueueFactory();
  final tester = ImplementationTester('MyCustomQueue', factory, () {
    factory.disposeAll(); // Your cleanup logic
  });
  
  tester.run(); // That's it! 87 comprehensive tests will run instantly
}
```

**Instant Results**: Run `dart test` and get complete validation of your implementation across functionality, performance, serialization, concurrency, and edge cases.

### What Gets Tested Automatically

The `ImplementationTester` validates your implementation across these areas:

- ✅ **Core Queue Operations**: All `enqueue`, `enqueuePayload`, `dequeue`, `acknowledge`, and `reject` functionality
- ✅ **Serialization Support**: JSON, binary, and Map serializers with full error handling validation
- ✅ **Performance & Concurrency**: Throughput benchmarks, latency tests, and multi-consumer scenarios
- ✅ **Reliability Features**: Visibility timeouts, dead letter queues, message expiration, and retry logic
- ✅ **Edge Cases**: Non-existent messages, timeout scenarios, malformed data, and cleanup operations
- ✅ **Factory Management**: Queue creation, retrieval, deletion, and lifecycle management
- ✅ **API Consistency**: Ensures both `enqueue()` and `enqueuePayload()` produce identical results

### Three Steps to Full Test Coverage

1. **Build Your Implementation**: Create your custom `QueueFactory` and `Queue` classes implementing the kiss_queue interfaces
2. **Add the Tester**: Create a test file with `ImplementationTester` pointing to your factory
3. **Run Tests**: Execute `dart test` to get instant validation with 87 comprehensive tests

The `ImplementationTester` automatically configures appropriate test scenarios for your implementation, including performance benchmarks and stress tests.

## ⚙️ Configuration

### Predefined Configurations

```dart
// Default configuration (balanced settings)
QueueConfiguration.defaultConfig

// High throughput (production)
QueueConfiguration.highThroughput

// Quick testing (shorter timeouts)
QueueConfiguration.testing
```

### Custom Configuration

```dart
const myConfig = QueueConfiguration(
  maxReceiveCount: 5,                              // Max retries before DLQ
  visibilityTimeout: Duration(minutes: 5),         // Processing timeout
  messageRetentionPeriod: Duration(hours: 24),     // Message TTL
);
```

## 📊 Performance

The `kiss_queue` interface is designed for high-performance implementations:

- ✅ Thread-safe operations
- ✅ Multiple consumer support  
- ✅ Async-first design for scalability
- ✅ Minimal overhead interface
- ✅ Optional serialization (no overhead when T == S)

## 📱 Flutter Example App

We've included a complete Flutter example app that demonstrates the `kiss_queue` interface with multiple implementations:

### Features
- **Interactive Demo**: Visual interface to enqueue and dequeue messages
- **Implementation Switching**: Dropdown to switch between queue backends
- **Real-time Updates**: See messages being processed in real-time
- **Error Handling**: Visual feedback for queue operations and errors

### Supported Implementations
1. **In-Memory Queue**: Built-in implementation (no additional setup)
2. **Amazon SQS**: Production-ready AWS SQS implementation via [`kiss_amazon_sqs_queue`](https://pub.dev/packages/kiss_amazon_sqs_queue)

### Quick Start

```bash
cd example
flutter pub get
flutter run
```

The app starts with the In-Memory Queue by default. To enable Amazon SQS:

1. Uncomment SQS dependencies in `example/pubspec.yaml`
2. Set up LocalStack or AWS credentials
3. Uncomment SQS implementation in `example/lib/queue_implementations.dart`

See the [example README](example/README.md) for detailed setup instructions and architecture overview.

## 🛠️ Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  kiss_queue: ^1.0.0
```

Then run:
```bash
dart pub get
```

## �� API Reference

### QueueMessage

```dart
// Auto-generated UUID ID and timestamp (most common)
QueueMessage.create(payload)

// With custom ID generation function
QueueMessage.create(payload, idGenerator: () => 'MSG-${DateTime.now().millisecondsSinceEpoch}')

// With optional parameters
QueueMessage(payload: data, id: customId, createdAt: timestamp)

// With explicit ID (useful for testing)
QueueMessage.withId(id: 'custom-123', payload: data)
```

### Queue Operations

```dart
// Enqueue with full QueueMessage control
await queue.enqueue(QueueMessage.create(payload));
await queue.enqueue(QueueMessage.withId(id: 'custom-id', payload: payload));

// Enqueue payload directly (uses queue's configured idGenerator)
await queue.enqueuePayload(payload);

// Both methods are equivalent and work with serialization
```

#### Custom ID Generation Examples

```dart
// Sequential counter at factory level
int messageCounter = 1000;
final factory = InMemoryQueueFactory<Order, String>(
  idGenerator: () => 'MSG-${messageCounter++}',
  serializer: OrderSerializer(),
);
final queue = await factory.createQueue<Order, String>('orders');

// Custom ID generation per message
QueueMessage.create(data, idGenerator: () => 'TS-${DateTime.now().millisecondsSinceEpoch}')

// Prefixed UUID
QueueMessage.create(data, idGenerator: () => 'ORDER-${Uuid().v4()}')

// Custom format
QueueMessage.create(data, idGenerator: () => '${userId}-${Random().nextInt(10000)}')
```

### Error Handling

```dart
try {
  await queue.acknowledge('non-existent-id');
} on MessageNotFoundError catch (e) {
  print('Message not found: ${e.messageId}');
}

try {
  await queue.enqueuePayload(complexObject);
} on SerializationError catch (e) {
  print('Serialization failed: ${e.message}');
  print('Cause: ${e.cause}');
}

try {
  final message = await queue.dequeue();
} on DeserializationError catch (e) {
  print('Deserialization failed: ${e.message}');
  print('Raw data: ${e.data}');
  print('Cause: ${e.cause}');
}
```

## 🤝 Contributing

We welcome contributions! Please see our [contributing guidelines](CONTRIBUTING.md) for details.

### Running Tests

```bash
# Run all tests (87 comprehensive tests)
dart test

# Run specific implementation tests
dart test test/in_memory_test.dart

# Run serialization tests
dart test test/serialization_test.dart

# Run performance benchmarks
dart test test/performance_test.dart
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🌟 Why kiss_queue?

- **Simple**: Minimal API surface, easy to understand
- **Reliable**: Battle-tested patterns from cloud message queuing services  
- **Flexible**: Works with any backend via clean interface, supports any serialization format
- **Performant**: Optimized for high throughput and low latency
- **Testable**: Comprehensive test suite with 87 tests included
- **Production Ready**: Used in production applications with full serialization support

Perfect for microservices, event-driven architectures, background job processing, and any application that needs reliable async message processing with flexible data serialization.

---

Built with ❤️ by the WAMF team. Part of the [KISS family](https://pub.dev/publishers/wearemobilefirst.com/packages) of simple, focused Dart packages.
