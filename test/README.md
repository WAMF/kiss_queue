# Kiss Queue Test Suite

This directory contains a comprehensive, implementation-agnostic test suite for testing any Queue implementation. The test suite is designed to validate the Queue interface contract while allowing for implementation-specific performance expectations and behavior.

## Architecture

### 🧪 Generic Test Suites

#### `queue_test_suite.dart`
**The core functional test suite** that validates Queue behavior:
- Message lifecycle (enqueue, dequeue, acknowledge, reject)
- **Both enqueue methods** (`enqueue()` and `enqueuePayload()` equivalence testing)
- Visibility timeouts and message restoration
- Dead letter queue functionality
- Message expiration and cleanup
- Concurrent processing
- Error handling and edge cases
- **Serialization integration** (when serializer is provided)

#### `serialization_test.dart`
**Comprehensive serialization testing suite**:
- **Serializer unit tests** (JSON String, JSON Map, Binary serializers)
- **Queue integration** with different serializer types
- **Method equivalence** (both `enqueue()` and `enqueuePayload()` work identically with serializers)
- **Serialization call tracking** (verifies serialization actually happens)
- **Error handling** (SerializationError, DeserializationError scenarios)
- **Performance testing** (no overhead when T == S)

#### `performance_test_suite.dart`
**Performance and load testing suite**:
- Basic operation benchmarking
- High-volume load testing with safety mechanisms
- Concurrent processing scalability
- End-to-end latency measurement
- Memory pressure testing

### ⚙️ Configuration System

#### `QueueTestConfig`
Provides implementation-specific test parameters and expectations:

```dart
class QueueTestConfig {
  // Operation timeouts
  final int enqueueTimeoutMs;
  final int dequeueTimeoutMs;
  final int acknowledgeTimeoutMs;
  
  // Load test parameters
  final int loadTestMessageCount;
  final int loadTestTimeoutMs;
  
  // Performance expectations
  final int maxAverageLatencyUs;
  final int maxP95LatencyUs;
  
  // Concurrency settings
  final int concurrentMessageCount;
  final int concurrentWorkerCount;
}
```

#### Predefined Configurations

- **`QueueTestConfig.inMemory`**: Fast, high-volume tests for in-memory implementations
- **`QueueTestConfig.cloud`**: Moderate tests for cloud services with reasonable latencies
- **`QueueTestConfig.conservative`**: Conservative tests for remote services with high latency tolerance

### 🏭 Implementation Examples

#### `in_memory_test.dart`
**Perfect example** of how to test a concrete implementation:

```dart
void main() {
  late InMemoryQueueFactory factory;

  // Wrapper functions needed for Dart's initialization timing
  Future<Queue<T, S>> createQueue<T, S>(String queueName, {
    QueueConfiguration? configuration,
    Queue<T, S>? deadLetterQueue,
    MessageSerializer<T, S>? serializer,
  }) async {
    return factory.createQueue<T, S>(queueName,
      configuration: configuration, 
      deadLetterQueue: deadLetterQueue,
      serializer: serializer);
  }

  void cleanup() => factory.disposeAll();

  setUp(() => factory = InMemoryQueueFactory());

  // 🎯 Run ALL generic tests!
  runQueueTests<Queue<Order, Order>, Order>(
    implementationName: 'InMemoryQueue',
    factoryProvider: () => InMemoryQueueFactory(),
    cleanup: cleanup,
    config: QueueTestConfig.inMemory,
  );

  // 🚀 Run performance tests!
  runPerformanceTests(
    implementationName: 'InMemoryQueue',
    createOrderQueue: createQueue<Order, Order>,
    createBenchmarkQueue: createQueue<BenchmarkMessage, BenchmarkMessage>,
    cleanup: cleanup,
    config: QueueTestConfig.inMemory,
  );
}
```

## 🚀 Testing Your Own Implementation

### Super Simple Testing with ImplementationTester

Testing any Queue implementation is now incredibly simple - just implement your factory and call the tester:

```dart
// test/my_implementation_test.dart
import 'package:kiss_queue/kiss_queue.dart';
import 'implementation_tester.dart';

void main() {
  final factory = MyQueueFactory();
  final tester = ImplementationTester('MyQueue', factory, () {
    factory.disposeAll(); // Your cleanup logic
  });
  
  tester.run(); // One line = 87 comprehensive tests!
}
```

### Prerequisites
Implement the `QueueFactory` interface:

```dart
class MyQueueFactory implements QueueFactory {
  @override
  Future<Queue<T, S>> createQueue<T, S>(String queueName, {
    QueueConfiguration? configuration,
    Queue<T, S>? deadLetterQueue,
    String Function()? idGenerator,
    MessageSerializer<T, S>? serializer,
  }) async {
    // Return your Queue implementation
  }

  @override
  Future<void> deleteQueue(String queueName) async { /* ... */ }

  @override
  Future<Queue<T, S>> getQueue<T, S>(String queueName) async { /* ... */ }

  // Add any cleanup methods you need
  void disposeAll() { /* cleanup logic */ }
}
```

**That's it!** Get 87 comprehensive tests including:
- ✅ **Queue functionality** (enqueue, enqueuePayload, dequeue, ack, reject)
- ✅ **Serialization testing** (JSON, binary, Map serializers + error scenarios)
- ✅ **Method equivalence** (both enqueue methods work identically)
- ✅ **Factory management** (create, get, delete queues + error handling)
- ✅ **Performance benchmarks** (throughput, latency, concurrency)
- ✅ **Edge cases** (timeouts, retries, dead letters)

### Advanced Testing (Optional)
If you need fine-grained control, you can still use the underlying test suites directly:

```dart
void main() {
  late MyQueueFactory factory;

  // Wrapper functions needed for Dart's initialization timing  
  Future<Queue<T, S>> createQueue<T, S>(String queueName, {
    QueueConfiguration? configuration,
    Queue<T, S>? deadLetterQueue,
    MessageSerializer<T, S>? serializer,
  }) async {
    return factory.createQueue<T, S>(queueName,
      configuration: configuration, 
      deadLetterQueue: deadLetterQueue,
      serializer: serializer);
  }

  void cleanup() => factory.disposeAll();

  setUp(() => factory = MyQueueFactory());

  // 🎯 Complete functional AND factory testing!
  runQueueTests<Queue<Order, Order>, Order>(
    implementationName: 'MyQueue',
    factoryProvider: () => MyQueueFactory(),
    cleanup: cleanup,
    config: QueueTestConfig.cloud, // inMemory | cloud | conservative | custom
  );

  // 🚀 Complete performance testing!  
  runPerformanceTests(
    implementationName: 'MyQueue',
    createOrderQueue: createQueue<Order, Order>,
    createBenchmarkQueue: createQueue<BenchmarkMessage, BenchmarkMessage>,
    cleanup: cleanup,
    config: QueueTestConfig.cloud,
  );
}
```

## 🧩 Benefits of This Architecture

### ✅ **Complete Coverage**
- All Queue interface methods tested
- Both `enqueue()` and `enqueuePayload()` validated for equivalence
- Serialization scenarios comprehensively covered
- Edge cases and error conditions covered
- Performance characteristics validated

### ✅ **Implementation Agnostic**
- Same tests work for any Queue implementation
- Consistent validation across different backends
- Easy to compare implementations
- **Serialization support** works with any MessageSerializer

### ✅ **Configurable Expectations**
- Adjust timeouts for different implementations
- Set appropriate performance thresholds
- Scale test loads based on capabilities

### ✅ **No Duplicate Code**
- Write your queue implementation once
- Get comprehensive testing for free
- Focus on implementation, not test writing

### ✅ **Ultra Simple**
- Just implement QueueFactory
- One line (`tester.run()`) to get full test coverage
- Add custom tests as needed

### ✅ **Serialization Ready**
- Automatic testing of serialization behavior
- Validates both enqueue methods work with serializers
- Tests error handling for serialization failures
- Ensures performance when no serialization is needed

## 📊 Test Coverage Breakdown

### Core Queue Tests (69 tests)
- **Basic Operations**: enqueue, enqueuePayload, dequeue, acknowledge, reject
- **Message Lifecycle**: visibility timeouts, message restoration, expiration
- **Reliability Features**: dead letter queues, max receive counts, error handling
- **Concurrent Processing**: multi-worker scenarios, message safety
- **Factory Management**: queue creation, retrieval, deletion, error scenarios
- **Method Equivalence**: ensures `enqueue()` and `enqueuePayload()` work identically

### Serialization Tests (18 tests)
- **Serializer Unit Tests**: JSON String, JSON Map, Binary serializers
- **Queue Integration**: all serializer types work with both enqueue methods
- **Call Tracking**: verifies serialization actually happens during storage
- **Error Scenarios**: SerializationError and DeserializationError handling
- **Performance**: no serialization overhead when T == S
- **Method Comparison**: both enqueue methods produce identical serialized results

**Total: 87 comprehensive tests**

## 📁 File Structure

```
test/
├── implementation_tester.dart  # 🎯 Simple one-line testing interface
├── queue_test_suite.dart       # 🧪 Core functional tests (69 tests)
├── serialization_test.dart     # 🔌 Serialization tests (18 tests)
├── performance_test_suite.dart # 🚀 Performance & load tests  
├── test_models.dart           # 📊 Test data models (Order, etc.)
├── in_memory_test.dart        # ✅ Example implementation test
├── performance_test.dart      # 🔬 Standalone benchmarks
└── README.md                  # 📖 This file
```

## 🎯 Quick Start

1. **Implement `QueueFactory`** for your backend
2. **Create test file**: 
   ```dart
   import 'package:kiss_queue/kiss_queue.dart';
   import 'implementation_tester.dart';
   
   void main() {
     final factory = MyQueueFactory();
     final tester = ImplementationTester('MyQueue', factory, () {
       factory.disposeAll();
     });
     
     tester.run();
   }
   ```
3. **Run:** `dart test my_test.dart`

🎉 **That's it!** You get 87 comprehensive tests validating your entire Queue implementation!

## 💡 Configuration Guide

Choose the right config for your implementation:

```dart
// Fast local implementations (Redis, in-memory)
config: QueueTestConfig.inMemory

// Cloud services (Pub/Sub, Service Bus)  
config: QueueTestConfig.cloud

// Conservative for remote services
config: QueueTestConfig.conservative

// Custom requirements
config: QueueTestConfig(
  loadTestMessageCount: 500,
  maxAverageLatencyUs: 100000, // 100ms
  // ... other parameters
)
```

**Examples:**
- **Remote Services**: `QueueTestConfig.conservative` (high latency tolerance)
- **Redis**: `QueueTestConfig.inMemory` (fast, local)  
- **PostgreSQL**: `QueueTestConfig.cloud` (medium latency)
- **RabbitMQ**: `QueueTestConfig.inMemory` or custom
- **Apache Kafka**: Custom config (high throughput)

## 🔌 Serialization Testing

The test suite automatically validates serialization behavior when you provide serializers:

### Automatic Serialization Tests
- **Both enqueue methods** work with any serializer
- **Serialization happens** during storage (verified with tracking)
- **Deserialization happens** during retrieval
- **Error handling** for serialization/deserialization failures
- **No performance overhead** when T == S (no serializer needed)

### Custom Serializer Testing
```dart
// Your custom serializer will be automatically tested
class MyCustomSerializer implements MessageSerializer<MyData, String> {
  @override
  String serialize(MyData payload) { /* your implementation */ }
  
  @override
  MyData deserialize(String data) { /* your implementation */ }
}

// Just provide it to the factory and all tests will use it
final queue = await factory.createQueue<MyData, String>(
  'test-queue',
  serializer: MyCustomSerializer(),
);
```

The test suite ensures your serializer works correctly with both `enqueue()` and `enqueuePayload()` methods, handles errors gracefully, and performs efficiently.
