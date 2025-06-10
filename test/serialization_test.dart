import 'dart:convert';
import 'package:kiss_queue/kiss_queue.dart';
import 'package:test/test.dart';

import 'test_models.dart';

extension OrderExtension on Order {
  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'customerId': customerId,
    'amount': amount,
    'items': items,
  };
}

Order orderFromJson(Map<String, dynamic> json) => Order(
  orderId: json['orderId'],
  customerId: json['customerId'],
  amount: json['amount'],
  //cast to list of strings
  items: (json['items'] as List<dynamic>).map((e) => e.toString()).toList(),
);

// String JSON serializer
class JsonStringSerializer implements MessageSerializer<Order, String> {
  @override
  String serialize(Order payload) {
    try {
      return jsonEncode(payload.toJson());
    } catch (e) {
      throw SerializationError(
        'Failed to serialize TestOrder to JSON string',
        e,
      );
    }
  }

  @override
  Order deserialize(String data) {
    try {
      final json = jsonDecode(data);
      return orderFromJson(json);
    } catch (e) {
      throw DeserializationError(
        'Failed to deserialize JSON string to TestOrder',
        data,
        e,
      );
    }
  }
}

// Map serializer
class JsonMapSerializer
    implements MessageSerializer<Order, Map<String, dynamic>> {
  @override
  Map<String, dynamic> serialize(Order payload) {
    try {
      return payload.toJson();
    } catch (e) {
      throw SerializationError('Failed to serialize TestOrder to Map', e);
    }
  }

  @override
  Order deserialize(Map<String, dynamic> data) {
    try {
      return orderFromJson(data);
    } catch (e) {
      throw DeserializationError(
        'Failed to deserialize Map to TestOrder',
        data,
        e,
      );
    }
  }
}

// Binary serializer
class BinarySerializer implements MessageSerializer<Order, List<int>> {
  @override
  List<int> serialize(Order payload) {
    try {
      final jsonString = jsonEncode(payload.toJson());
      return utf8.encode(jsonString);
    } catch (e) {
      throw SerializationError('Failed to serialize TestOrder to binary', e);
    }
  }

  @override
  Order deserialize(List<int> data) {
    try {
      final jsonString = utf8.decode(data);
      final json = jsonDecode(jsonString);
      if (json is! Map<String, dynamic>) {
        throw DeserializationError(
          'Binary data does not contain a valid JSON map',
          data,
        );
      }
      return orderFromJson(json);
    } catch (e) {
      throw DeserializationError(
        'Failed to deserialize binary data to TestOrder',
        data,
        e,
      );
    }
  }
}

void main() {
  group('Serialization Interface Tests', () {
    late Order testOrder;
    late InMemoryQueueFactory factory;

    setUp(() {
      testOrder = Order(
        orderId: 'ORD-123',
        customerId: 'CUST-123',
        amount: 99.99,
        items: ['Item 1', 'Item 2'],
      );
      factory = InMemoryQueueFactory();
    });

    tearDown(() {
      factory.disposeAll();
    });

    group('Serializer Unit Tests', () {
      test(
        'JsonStringSerializer should serialize and deserialize correctly',
        () {
          final serializer = JsonStringSerializer();

          // Test serialization
          final serialized = serializer.serialize(testOrder);
          expect(serialized, isA<String>());
          expect(serialized, contains('ORD-123'));
          expect(serialized, contains('CUST-123'));
          expect(serialized, contains('99.99'));
          expect(serialized, contains('Item 1'));
          expect(serialized, contains('Item 2'));

          // Test deserialization
          final deserialized = serializer.deserialize(serialized);
          expect(deserialized, equals(testOrder));
        },
      );

      test('JsonMapSerializer should serialize and deserialize correctly', () {
        final serializer = JsonMapSerializer();

        // Test serialization
        final serialized = serializer.serialize(testOrder);
        expect(serialized, isA<Map<String, dynamic>>());
        expect(serialized['orderId'], equals('ORD-123'));
        expect(serialized['customerId'], equals('CUST-123'));
        expect(serialized['amount'], equals(99.99));
        expect(serialized['items'], equals(['Item 1', 'Item 2']));

        // Test deserialization
        final deserialized = serializer.deserialize(serialized);
        expect(deserialized, equals(testOrder));
      });

      test('BinarySerializer should serialize and deserialize correctly', () {
        final serializer = BinarySerializer();

        // Test serialization
        final serialized = serializer.serialize(testOrder);
        expect(serialized, isA<List<int>>());
        expect(serialized.isNotEmpty, isTrue);

        // Test deserialization
        final deserialized = serializer.deserialize(serialized);
        expect(deserialized, equals(testOrder));
      });
    });

    group('Queue Integration with Serializers', () {
      test('enqueuePayload should work with JsonStringSerializer', () async {
        final queue = await factory.createQueue<Order, String>(
          'test-enqueuePayload-string',
          serializer: JsonStringSerializer(),
        );

        expect(queue.serializer, isA<JsonStringSerializer>());

        // Test enqueuePayload
        await queue.enqueuePayload(testOrder);
        final dequeued = await queue.dequeue();

        expect(dequeued, isNotNull);
        expect(dequeued!.payload, equals(testOrder));

        await queue.acknowledge(dequeued.id);
      });

      test('enqueue should work with JsonStringSerializer', () async {
        final queue = await factory.createQueue<Order, String>(
          'test-enqueue-string',
          serializer: JsonStringSerializer(),
        );

        // Test enqueue with QueueMessage
        await queue.enqueue(QueueMessage.create(testOrder));
        final dequeued = await queue.dequeue();

        expect(dequeued, isNotNull);
        expect(dequeued!.payload, equals(testOrder));

        await queue.acknowledge(dequeued.id);
      });

      test(
        'enqueuePayload and enqueue should behave identically with serializer',
        () async {
          final queue1 = await factory.createQueue<Order, String>(
            'test-enqueuePayload-identical',
            serializer: JsonStringSerializer(),
          );
          final queue2 = await factory.createQueue<Order, String>(
            'test-enqueue-identical',
            serializer: JsonStringSerializer(),
          );

          // Test both methods with same data
          await queue1.enqueuePayload(testOrder);
          await queue2.enqueue(QueueMessage.create(testOrder));

          final dequeued1 = await queue1.dequeue();
          final dequeued2 = await queue2.dequeue();

          // Should have identical payload after serialization/deserialization
          expect(dequeued1!.payload, equals(dequeued2!.payload));
          expect(dequeued1.payload, equals(testOrder));
          expect(dequeued2.payload, equals(testOrder));

          await queue1.acknowledge(dequeued1.id);
          await queue2.acknowledge(dequeued2.id);
        },
      );

      test('Queue should work with different serializers', () async {
        // Test with Map serializer
        final mapQueue = await factory.createQueue<Order, Map<String, dynamic>>(
          'test-map-serializer',
          serializer: JsonMapSerializer(),
        );

        // Test with Binary serializer
        final binaryQueue = await factory.createQueue<Order, List<int>>(
          'test-binary-serializer',
          serializer: BinarySerializer(),
        );

        // Test both with enqueuePayload
        await mapQueue.enqueuePayload(testOrder);
        await binaryQueue.enqueuePayload(testOrder);

        final mapDequeued = await mapQueue.dequeue();
        final binaryDequeued = await binaryQueue.dequeue();

        expect(mapDequeued!.payload, equals(testOrder));
        expect(binaryDequeued!.payload, equals(testOrder));

        await mapQueue.acknowledge(mapDequeued.id);
        await binaryQueue.acknowledge(binaryDequeued.id);
      });

      test('Queue should work without a serializer', () async {
        final queue = await factory.createQueue<Order, Order>(
          'test-no-serializer',
        );

        expect(queue.serializer, isNull);

        // Both methods should work when T == S
        await queue.enqueuePayload(testOrder);
        await queue.enqueue(QueueMessage.create(testOrder));

        final dequeued1 = await queue.dequeue();
        final dequeued2 = await queue.dequeue();

        expect(dequeued1!.payload, equals(testOrder));
        expect(dequeued2!.payload, equals(testOrder));

        await queue.acknowledge(dequeued1.id);
        await queue.acknowledge(dequeued2.id);
      });
    });

    group('Serialization Call Tracking', () {
      test(
        'Should verify serialization is actually called during storage',
        () async {
          var serializeCallCount = 0;
          var deserializeCallCount = 0;

          final trackingSerializer = _TrackingSerializer(
            onSerialize: () => serializeCallCount++,
            onDeserialize: () => deserializeCallCount++,
          );

          final queue = await factory.createQueue<Order, String>(
            'test-tracking-serializer',
            serializer: trackingSerializer,
          );

          // Test enqueuePayload calls serialize
          await queue.enqueuePayload(testOrder);
          expect(serializeCallCount, equals(1));
          expect(deserializeCallCount, equals(0));

          // Test enqueue calls serialize
          await queue.enqueue(QueueMessage.create(testOrder));
          expect(serializeCallCount, equals(2));
          expect(deserializeCallCount, equals(0));

          // Dequeue should call deserialize twice
          final dequeued1 = await queue.dequeue();
          expect(serializeCallCount, equals(2));
          expect(deserializeCallCount, equals(1));

          final dequeued2 = await queue.dequeue();
          expect(serializeCallCount, equals(2));
          expect(deserializeCallCount, equals(2));

          expect(dequeued1!.payload, equals(testOrder));
          expect(dequeued2!.payload, equals(testOrder));

          await queue.acknowledge(dequeued1.id);
          await queue.acknowledge(dequeued2.id);
        },
      );

      test(
        'Queue without serializer should not call any serialization',
        () async {
          // This test ensures no serialization overhead when T == S
          final queue = await factory.createQueue<Order, Order>(
            'test-no-serializer-calls',
          );

          await queue.enqueuePayload(testOrder);
          await queue.enqueue(QueueMessage.create(testOrder));

          final dequeued1 = await queue.dequeue();
          final dequeued2 = await queue.dequeue();

          expect(
            dequeued1!.payload,
            same(testOrder),
          ); // Should be same instance
          expect(
            dequeued2!.payload.orderId,
            equals(testOrder.orderId),
          ); // Different instance from QueueMessage.create

          await queue.acknowledge(dequeued1.id);
          await queue.acknowledge(dequeued2.id);
        },
      );
    });

    group('Error Handling', () {
      test('SerializationError should contain proper error information', () {
        expect(
          () => throw SerializationError('Test error', Exception('cause')),
          throwsA(
            predicate(
              (e) =>
                  e is SerializationError &&
                  e.message == 'Test error' &&
                  e.cause is Exception,
            ),
          ),
        );
      });

      test('DeserializationError should contain proper error information', () {
        const badData = 'invalid json';
        expect(
          () => throw DeserializationError(
            'Test error',
            badData,
            Exception('cause'),
          ),
          throwsA(
            predicate(
              (e) =>
                  e is DeserializationError &&
                  e.message == 'Test error' &&
                  e.data == badData &&
                  e.cause is Exception,
            ),
          ),
        );
      });

      test(
        'JsonStringSerializer should throw DeserializationError on invalid data',
        () {
          final serializer = JsonStringSerializer();

          expect(
            () => serializer.deserialize('invalid json'),
            throwsA(isA<DeserializationError>()),
          );
        },
      );

      test(
        'JsonMapSerializer should throw DeserializationError on invalid data',
        () {
          final serializer = JsonMapSerializer();

          expect(
            () => serializer.deserialize({'invalid': 'structure'}),
            throwsA(isA<DeserializationError>()),
          );
        },
      );

      test(
        'BinarySerializer should throw DeserializationError on invalid data',
        () {
          final serializer = BinarySerializer();

          expect(
            () => serializer.deserialize([255, 254, 253]), // Invalid UTF-8
            throwsA(isA<DeserializationError>()),
          );
        },
      );

      test(
        'Should throw SerializationError during enqueuePayload if serialization fails',
        () async {
          final faultySerializer = _FaultySerializer<Order>(
            failOnSerialize: true,
          );

          final queue = await factory.createQueue<Order, String>(
            'test-enqueuePayload-serialize-error',
            serializer: faultySerializer,
          );

          expect(
            () => queue.enqueuePayload(testOrder),
            throwsA(isA<SerializationError>()),
          );
        },
      );

      test(
        'Should throw SerializationError during enqueue if serialization fails',
        () async {
          final faultySerializer = _FaultySerializer<Order>(
            failOnSerialize: true,
          );

          final queue = await factory.createQueue<Order, String>(
            'test-enqueue-serialize-error',
            serializer: faultySerializer,
          );

          expect(
            () => queue.enqueue(QueueMessage.create(testOrder)),
            throwsA(isA<SerializationError>()),
          );
        },
      );

      test(
        'Should throw DeserializationError during dequeue if deserialization fails',
        () async {
          final faultySerializer = _FaultySerializer<Order>(
            failOnDeserialize: true,
          );

          final queue = await factory.createQueue<Order, String>(
            'test-deserialize-error',
            serializer: faultySerializer,
          );

          // Enqueue should work (serialization is not failing)
          await queue.enqueuePayload(testOrder);

          // Dequeue should fail (deserialization is failing)
          expect(() => queue.dequeue(), throwsA(isA<DeserializationError>()));
        },
      );
    });
  });
}

/// Test serializer that tracks when serialize/deserialize are called
class _TrackingSerializer implements MessageSerializer<Order, String> {
  final void Function() onSerialize;
  final void Function() onDeserialize;

  _TrackingSerializer({required this.onSerialize, required this.onDeserialize});

  @override
  String serialize(Order payload) {
    onSerialize();
    return JsonStringSerializer().serialize(payload);
  }

  @override
  Order deserialize(String data) {
    onDeserialize();
    return JsonStringSerializer().deserialize(data);
  }
}

/// Test serializer that can be configured to fail on serialize or deserialize
class _FaultySerializer<T> implements MessageSerializer<T, String> {
  final bool failOnSerialize;
  final bool failOnDeserialize;

  _FaultySerializer({
    this.failOnSerialize = false,
    this.failOnDeserialize = false,
  });

  @override
  String serialize(T payload) {
    if (failOnSerialize) {
      throw Exception('Intentional serialization failure');
    }
    return 'fake-serialized-data';
  }

  @override
  T deserialize(String data) {
    if (failOnDeserialize) {
      throw Exception('Intentional deserialization failure');
    }
    throw UnimplementedError(
      'This serializer only fails, it does not actually deserialize',
    );
  }
}
