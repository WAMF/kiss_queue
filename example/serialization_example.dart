import 'dart:convert';
import 'package:kiss_queue/kiss_queue.dart';

// Example domain model
class Order {
  final String orderId;
  final String customerId;
  final double amount;
  final List<String> items;

  Order({
    required this.orderId,
    required this.customerId,
    required this.amount,
    required this.items,
  });

  // Serialization methods
  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'customerId': customerId,
    'amount': amount,
    'items': items,
  };

  static Order fromJson(Map<String, dynamic> json) => Order(
    orderId: json['orderId'],
    customerId: json['customerId'],
    amount: json['amount'],
    items: (json['items'] as List<dynamic>).map((e) => e.toString()).toList(),
  );

  @override
  String toString() =>
      'Order(id: $orderId, customer: $customerId, amount: \$${amount.toStringAsFixed(2)}, items: ${items.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order &&
          runtimeType == other.runtimeType &&
          orderId == other.orderId &&
          customerId == other.customerId &&
          amount == other.amount &&
          items.length == other.items.length;

  @override
  int get hashCode => Object.hash(orderId, customerId, amount, items.length);
}

// JSON String serializer
class OrderJsonSerializer implements MessageSerializer<Order, String> {
  @override
  String serialize(Order payload) {
    try {
      return jsonEncode(payload.toJson());
    } catch (e) {
      throw SerializationError('Failed to serialize Order to JSON', e);
    }
  }

  @override
  Order deserialize(String data) {
    try {
      final json = jsonDecode(data);
      return Order.fromJson(json);
    } catch (e) {
      throw DeserializationError(
        'Failed to deserialize Order from JSON',
        data,
        e,
      );
    }
  }
}

// Binary serializer (for demonstration)
class OrderBinarySerializer implements MessageSerializer<Order, List<int>> {
  final OrderJsonSerializer _jsonSerializer = OrderJsonSerializer();

  @override
  List<int> serialize(Order payload) {
    try {
      final jsonString = _jsonSerializer.serialize(payload);
      return utf8.encode(jsonString);
    } catch (e) {
      throw SerializationError('Failed to serialize Order to binary', e);
    }
  }

  @override
  Order deserialize(List<int> data) {
    try {
      final jsonString = utf8.decode(data);
      return _jsonSerializer.deserialize(jsonString);
    } catch (e) {
      throw DeserializationError(
        'Failed to deserialize Order from binary',
        data,
        e,
      );
    }
  }
}

void main() async {
  final factory = InMemoryQueueFactory();

  print('=== Kiss Queue Serialization Examples ===\n');

  // Sample orders
  final orders = [
    Order(
      orderId: 'ORD-001',
      customerId: 'CUST-ABC',
      amount: 99.99,
      items: ['Widget A', 'Widget B'],
    ),
    Order(
      orderId: 'ORD-002',
      customerId: 'CUST-XYZ',
      amount: 249.99,
      items: ['Premium Widget', 'Deluxe Package'],
    ),
  ];

  print('=== Example 1: JSON String Serialization ===\n');
  await demonstrateJsonSerialization(factory, orders);

  print('\n=== Example 2: Binary Serialization ===\n');
  await demonstrateBinarySerialization(factory, orders);

  print('\n=== Example 3: No Serialization (Direct Storage) ===\n');
  await demonstrateDirectStorage(factory);

  print('\n=== Example 4: Both Enqueue Methods Work Identically ===\n');
  await demonstrateMethodEquivalence(factory, orders.first);

  print('\n=== Example 5: Error Handling ===\n');
  await demonstrateErrorHandling(factory);

  // Cleanup
  factory.disposeAll();
  print('🎉 All examples completed successfully!');
}

Future<void> demonstrateJsonSerialization(
  InMemoryQueueFactory factory,
  List<Order> orders,
) async {
  // Create queue with JSON serialization
  final orderQueue = await factory.createQueue<Order, String>(
    'json-orders',
    serializer: OrderJsonSerializer(),
  );

  print('📦 Enqueuing orders with JSON serialization...');

  // Both enqueue methods work with serialization
  await orderQueue.enqueuePayload(orders[0]); // Method 1: Simple payload
  await orderQueue.enqueue(
    QueueMessage.create(orders[1]),
  ); // Method 2: QueueMessage

  print('✅ Orders enqueued and automatically serialized to JSON\n');

  // Process orders
  print('📤 Processing orders (automatic deserialization)...');
  for (int i = 1; i <= 2; i++) {
    final message = await orderQueue.dequeue();
    if (message != null) {
      print('Order $i: ${message.payload}');
      print('Message ID: ${message.id}');
      await orderQueue.acknowledge(message.id);
      print('✅ Order $i processed and acknowledged\n');
    }
  }
}

Future<void> demonstrateBinarySerialization(
  InMemoryQueueFactory factory,
  List<Order> orders,
) async {
  // Create queue with binary serialization
  final binaryQueue = await factory.createQueue<Order, List<int>>(
    'binary-orders',
    serializer: OrderBinarySerializer(),
  );

  print('📦 Enqueuing order with binary serialization...');
  await binaryQueue.enqueuePayload(orders[0]);
  print('✅ Order serialized to binary format and stored\n');

  print('📤 Retrieving and deserializing from binary...');
  final message = await binaryQueue.dequeue();
  if (message != null) {
    print('Deserialized order: ${message.payload}');
    print('Original object equality: ${message.payload == orders[0]}');
    await binaryQueue.acknowledge(message.id);
    print('✅ Binary serialization round-trip successful\n');
  }
}

Future<void> demonstrateDirectStorage(InMemoryQueueFactory factory) async {
  // No serializer needed when T == S
  final stringQueue = await factory.createQueue<String, String>(
    'direct-strings',
  );

  print('📦 Storing strings directly (no serialization overhead)...');
  await stringQueue.enqueuePayload('Direct string message 1');
  await stringQueue.enqueue(QueueMessage.create('Direct string message 2'));
  print('✅ Strings stored directly without any serialization\n');

  print('📤 Retrieving direct strings...');
  for (int i = 1; i <= 2; i++) {
    final message = await stringQueue.dequeue();
    if (message != null) {
      print('String $i: ${message.payload}');
      await stringQueue.acknowledge(message.id);
    }
  }
  print('✅ Direct storage complete - no serialization calls made\n');
}

Future<void> demonstrateMethodEquivalence(
  InMemoryQueueFactory factory,
  Order order,
) async {
  final queue1 = await factory.createQueue<Order, String>(
    'equiv-queue-1',
    serializer: OrderJsonSerializer(),
  );
  final queue2 = await factory.createQueue<Order, String>(
    'equiv-queue-2',
    serializer: OrderJsonSerializer(),
  );

  print('📦 Testing that both enqueue methods produce identical results...');

  // Use both methods with the same order
  await queue1.enqueuePayload(order);
  await queue2.enqueue(QueueMessage.create(order));

  // Retrieve and compare
  final message1 = await queue1.dequeue();
  final message2 = await queue2.dequeue();

  if (message1 != null && message2 != null) {
    print('enqueuePayload result: ${message1.payload}');
    print('enqueue result: ${message2.payload}');
    print('Payloads are equal: ${message1.payload == message2.payload}');
    print('✅ Both methods produce identical serialized/deserialized results\n');

    await queue1.acknowledge(message1.id);
    await queue2.acknowledge(message2.id);
  }
}

Future<void> demonstrateErrorHandling(InMemoryQueueFactory factory) async {
  print('🚨 Testing error handling scenarios...\n');

  // Create a faulty serializer for demonstration
  final faultyQueue = await factory.createQueue<Order, String>(
    'error-demo',
    serializer: _FaultySerializer(),
  );

  final testOrder = Order(
    orderId: 'TEST-ERROR',
    customerId: 'ERROR-CUSTOMER',
    amount: 1.0,
    items: ['Error Item'],
  );

  try {
    await faultyQueue.enqueuePayload(testOrder);
    print('❌ This should not print - serialization should have failed');
  } on SerializationError catch (e) {
    print('✅ Caught SerializationError as expected:');
    print('   Message: ${e.message}');
    print('   Cause: ${e.cause}\n');
  }

  // Demonstrate MessageNotFoundError
  final validQueue = await factory.createQueue<String, String>('valid-queue');

  try {
    await validQueue.acknowledge('non-existent-message-id');
    print('❌ This should not print - message should not exist');
  } on MessageNotFoundError catch (e) {
    print('✅ Caught MessageNotFoundError as expected:');
    print('   Message ID: ${e.messageId}\n');
  }

  print('✅ Error handling demonstration complete\n');
}

// Faulty serializer for error demonstration
class _FaultySerializer implements MessageSerializer<Order, String> {
  @override
  String serialize(Order payload) {
    throw Exception('Intentional serialization failure for demonstration');
  }

  @override
  Order deserialize(String data) {
    throw Exception('Intentional deserialization failure for demonstration');
  }
}
