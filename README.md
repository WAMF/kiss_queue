# kiss_queue

A simple, backend-agnostic queue interface for Dart — part of the [KISS](https://pub.dev/publishers/wearemobilefirst.com/packages) (Keep It Simple, Stupid) family of libraries.

## 🎯 Purpose

`kiss_queue` provides a unified, async queue interface that works with any backend. Whether you're building with in-memory queues for development, planning to use AWS SQS for production, or implementing custom database-backed queues, this library gives you a consistent API with enterprise-grade features.

Just queues. No ceremony. No complexity.

---

## ✨ Features

- 🔄 **Backend Agnostic**: Unified interface works with any queue implementation
- ⚡ **Production Ready**: Visibility timeouts, dead letter queues, message expiration
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
  final queue = await factory.createQueue<String>('my-queue');
  
  // Enqueue a message
  await queue.enqueue(QueueMessage.create('Hello, World!'));
  
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
  final deadLetterQueue = await factory.createQueue<Order>('failed-orders');
  final orderQueue = await factory.createQueue<Order>(
    'orders',
    configuration: QueueConfiguration.highThroughput,
    deadLetterQueue: deadLetterQueue,
  );
  
  // Enqueue an order
  final order = Order('ORD-123', 99.99);
  await orderQueue.enqueue(QueueMessage.create(order));
  
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
abstract class Queue<T> {
  // Queue configuration and dead letter queue  
  QueueConfiguration get configuration;
  Queue<T>? get deadLetterQueue;
  
  // Core operations
  Future<void> enqueue(QueueMessage<T> message);
  Future<QueueMessage<T>?> dequeue();
  Future<void> acknowledge(String messageId);
  Future<QueueMessage<T>?> reject(String messageId, {bool requeue = true});
  
  // Cleanup
  void dispose();
}
```

### Message Lifecycle

1. **Enqueue**: Add message to queue
2. **Dequeue**: Retrieve message (becomes invisible to other consumers)  
3. **Process**: Handle the message in your application
4. **Acknowledge**: Mark message as successfully processed (removes from queue)
5. **Reject**: Mark message as failed (can requeue for retry or move to DLQ)

### Built-in Reliability Features

- **Visibility Timeout**: Messages become invisible after dequeue, automatically restored if not acknowledged
- **Dead Letter Queue**: Failed messages move to DLQ after max retry attempts
- **Message Expiration**: Optional TTL for automatic message cleanup
- **Receive Count Tracking**: Monitor how many times a message has been processed

## 📦 Implementations

### In-Memory Queue (Included)

Perfect for development, testing, and single-instance applications:

```dart
final factory = InMemoryQueueFactory();
final queue = await factory.createQueue<MyData>('my-queue');
```

### Custom Implementations

The generic interface makes it easy to implement queues for any backend:

- **AWS SQS**: Cloud-scale message queuing
- **Google Cloud Pub/Sub**: Global message distribution  
- **Redis**: High-performance in-memory queuing
- **PostgreSQL/MySQL**: Database-backed persistence
- **Apache Kafka**: High-throughput event streaming
- **RabbitMQ**: Feature-rich message broker

## 🧪 Testing Your Implementation

`kiss_queue` includes a comprehensive test suite that can validate any implementation:

```dart
// test/my_implementation_test.dart
import 'package:kiss_queue/kiss_queue.dart';
import 'queue_test_suite.dart';
import 'performance_test_suite.dart';

void main() {
  // Test your implementation with the same comprehensive suite
  runQueueTests<Queue<Order>>(
    implementationName: 'My Custom Queue',
    createQueue: createMyQueue<Order>,
    cleanup: cleanupMyQueue,
    config: QueueTestConfig.cloud, // Adjust expectations for your backend
  );
  
  runPerformanceTests(
    implementationName: 'My Custom Queue', 
    createOrderQueue: createMyQueue<Order>,
    createBenchmarkQueue: createMyQueue<BenchmarkMessage>,
    cleanup: cleanupMyQueue,
    config: QueueTestConfig.cloud,
  );
}
```

**Test Coverage**: 21 tests covering functionality, performance, concurrency, and edge cases.

## ⚙️ Configuration

### Predefined Configurations

```dart
// Fast, high-volume (development/testing)
QueueConfiguration.inMemory

// Balanced (cloud services)  
QueueConfiguration.cloud

// Conservative (AWS SQS)
QueueConfiguration.aws

// High throughput (production)
QueueConfiguration.highThroughput

// Quick testing
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

## 📚 API Reference

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

#### Custom ID Generation Examples

```dart
// Sequential counter
int messageCounter = 1000;
QueueMessage.create(data, idGenerator: () => 'MSG-${messageCounter++}')

// Timestamp-based
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
```

## 🤝 Contributing

We welcome contributions! Please see our [contributing guidelines](CONTRIBUTING.md) for details.

### Running Tests

```bash
# Run all tests
dart test

# Run specific implementation tests
dart test test/in_memory_test.dart

# Run performance benchmarks
dart test test/performance_test.dart
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🌟 Why kiss_queue?

- **Simple**: Minimal API surface, easy to understand
- **Reliable**: Battle-tested patterns from AWS SQS  
- **Flexible**: Works with any backend via clean interface
- **Performant**: Optimized for high throughput and low latency
- **Testable**: Comprehensive test suite included
- **Production Ready**: Used in production applications

Perfect for microservices, event-driven architectures, background job processing, and any application that needs reliable async message processing.

---

Built with ❤️ by the WAMF team. Part of the [KISS family](https://pub.dev/publishers/wearemobilefirst.com/packages) of simple, focused Dart packages.
