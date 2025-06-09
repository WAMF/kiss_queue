# Kiss Queue Test Suite

This directory contains a comprehensive, implementation-agnostic test suite for testing any EventQueue implementation. The test suite is designed to validate the EventQueue interface contract while allowing for implementation-specific performance expectations and behavior.

## Architecture

### Generic Test Suites

#### `queue_test_suite.dart`
Contains the core functional tests that validate EventQueue behavior:
- Message lifecycle (enqueue, dequeue, acknowledge, reject)
- Visibility timeouts and message restoration
- Dead letter queue functionality
- Message expiration and cleanup
- Concurrent processing
- Error handling and edge cases

#### `performance_test_suite.dart`
Contains performance and load tests:
- Basic operation benchmarking
- High-volume load testing
- Concurrent processing scalability
- End-to-end latency measurement
- Memory pressure testing

### Configuration System

#### `QueueTestConfig`
Provides implementation-specific test parameters:

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
  final int concurrentTimeoutMs;
}
```

#### Predefined Configurations

- **`QueueTestConfig.inMemory`**: Fast, high-volume tests for in-memory implementations
- **`QueueTestConfig.cloud`**: Moderate tests for cloud services with reasonable latencies
- **`QueueTestConfig.aws`**: Conservative tests for AWS SQS with high latency tolerance

## Usage

### Testing Your Implementation

1. **Create a factory function** that implements the `QueueFactory<T>` type:
```dart
Future<EventQueue<T>> createMyQueue<T>(
  String queueName, {
  QueueConfiguration? configuration,
  EventQueue<T>? deadLetterQueue,
}) async {
  // Return your EventQueue implementation
}
```

2. **Create a cleanup function** that implements the `QueueCleanup` type:
```dart
void cleanupMyQueues() {
  // Clean up any resources, connections, test queues, etc.
}
```

3. **Run the test suites**:
```dart
void main() {
  // Run functional tests
  runQueueTests<EventQueue<Order>>(
    implementationName: 'My Implementation',
    createQueue: createMyQueue<Order>,
    cleanup: cleanupMyQueues,
    config: QueueTestConfig.cloud, // Choose appropriate config
  );

  // Run performance tests
  runPerformanceTests(
    implementationName: 'My Implementation',
    createOrderQueue: createMyQueue<Order>,
    createBenchmarkQueue: createMyQueue<BenchmarkMessage>,
    cleanup: cleanupMyQueues,
    config: QueueTestConfig.cloud,
  );
}
```

### Example Implementations

#### In-Memory Queue (Reference Implementation)
```bash
dart test test/in_memory_test.dart
```
- Uses `QueueTestConfig.inMemory`
- High-volume tests (10,000 messages)
- Low latency expectations (<50ms average)
- Fast timeouts (5 seconds)

#### Custom Implementation Template
```bash
dart test test/my_queue_example_test.dart
```
- Generic template for any custom implementation
- Choose appropriate `QueueTestConfig`:
  - `inMemory`: Fast local implementations (Redis, RabbitMQ)
  - `cloud`: Cloud services (Google Pub/Sub, Azure Service Bus)
  - `aws`: AWS SQS specifically
  - Custom: Specialized requirements (Apache Kafka, etc.)
- Comprehensive implementation guide with examples
- Placeholder for implementation-specific tests

## Test Categories

### Functional Tests (15 tests)
- ✅ Message API validation
- ✅ Basic queue operations
- ✅ Visibility timeout behavior
- ✅ Dead letter queue functionality
- ✅ Message expiration
- ✅ Error handling
- ✅ Edge cases

### Performance Tests (6 tests)
- ✅ Operation benchmarking
- ✅ Load testing
- ✅ Concurrent processing
- ✅ Latency measurement
- ✅ Memory pressure testing

## Creating Custom Configurations

For specialized implementations, create custom configurations:

```dart
static const myCustomConfig = QueueTestConfig(
  enqueueTimeoutMs: 8000,
  dequeueTimeoutMs: 8000,
  acknowledgeTimeoutMs: 8000,
  loadTestMessageCount: 5000,
  loadTestTimeoutMs: 45000,
  maxAverageLatencyUs: 250000, // 250ms
  maxP95LatencyUs: 1000000,    // 1s
  concurrentMessageCount: 200,
  concurrentWorkerCount: 3,
  concurrentTimeoutMs: 15000,
  performanceTestMessageCount: 500,
  performanceTestTimeoutMs: 8000,
);
```

## Benefits

### 🔄 **Implementation Agnostic**
Test any EventQueue implementation with the same comprehensive suite.

### ⚡ **Performance Validation**
Configurable performance expectations for different implementation types.

### 🧪 **Comprehensive Coverage**
21 tests covering all aspects of queue behavior and performance.

### 🎯 **Easy Integration**
Simple factory pattern - just provide creation and cleanup functions.

### 📊 **Detailed Metrics**
Performance tests provide throughput, latency, and concurrency metrics.

### 🔧 **Flexible Configuration**
Predefined configs for common scenarios, with easy customization.

## Implementation Examples

This testing approach enables you to confidently implement and validate:

- **AWS SQS** adapters
- **Google Cloud Pub/Sub** implementations  
- **Redis** queue implementations
- **Apache Kafka** adapters
- **RabbitMQ** implementations
- **Azure Service Bus** adapters
- Custom database-backed queues

All using the exact same test suite with appropriate performance expectations for each backend! 
