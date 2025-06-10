import 'dart:convert';
import 'package:kiss_queue/kiss_queue.dart';
import 'package:test/test.dart';

// Test model
class TestOrder {
  final String id;
  final String name;
  final double price;

  TestOrder({required this.id, required this.name, required this.price});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};

  factory TestOrder.fromJson(Map<String, dynamic> json) => TestOrder(
    id: json['id'],
    name: json['name'],
    price: json['price'].toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestOrder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          price == other.price;

  @override
  int get hashCode => Object.hash(id, name, price);
}

// String JSON serializer
class JsonStringSerializer implements MessageSerializer<TestOrder, String> {
  @override
  String serialize(TestOrder payload) {
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
  TestOrder deserialize(String data) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) {
        throw DeserializationError('JSON data is not a map', data);
      }
      return TestOrder.fromJson(json);
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
    implements MessageSerializer<TestOrder, Map<String, dynamic>> {
  @override
  Map<String, dynamic> serialize(TestOrder payload) {
    try {
      return payload.toJson();
    } catch (e) {
      throw SerializationError('Failed to serialize TestOrder to Map', e);
    }
  }

  @override
  TestOrder deserialize(Map<String, dynamic> data) {
    try {
      return TestOrder.fromJson(data);
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
class BinarySerializer implements MessageSerializer<TestOrder, List<int>> {
  @override
  List<int> serialize(TestOrder payload) {
    try {
      final jsonString = jsonEncode(payload.toJson());
      return utf8.encode(jsonString);
    } catch (e) {
      throw SerializationError('Failed to serialize TestOrder to binary', e);
    }
  }

  @override
  TestOrder deserialize(List<int> data) {
    try {
      final jsonString = utf8.decode(data);
      final json = jsonDecode(jsonString);
      if (json is! Map<String, dynamic>) {
        throw DeserializationError(
          'Binary data does not contain a valid JSON map',
          data,
        );
      }
      return TestOrder.fromJson(json);
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
    late TestOrder testOrder;
    late InMemoryQueueFactory factory;

    setUp(() {
      testOrder = TestOrder(id: 'ORD-123', name: 'Test Product', price: 99.99);
      factory = InMemoryQueueFactory();
    });

    tearDown(() {
      factory.disposeAll();
    });

    test('JsonStringSerializer should serialize and deserialize correctly', () {
      final serializer = JsonStringSerializer();

      // Test serialization
      final serialized = serializer.serialize(testOrder);
      expect(serialized, isA<String>());
      expect(serialized, contains('ORD-123'));
      expect(serialized, contains('Test Product'));
      expect(serialized, contains('99.99'));

      // Test deserialization
      final deserialized = serializer.deserialize(serialized);
      expect(deserialized, equals(testOrder));
    });

    test('JsonMapSerializer should serialize and deserialize correctly', () {
      final serializer = JsonMapSerializer();

      // Test serialization
      final serialized = serializer.serialize(testOrder);
      expect(serialized, isA<Map<String, dynamic>>());
      expect(serialized['id'], equals('ORD-123'));
      expect(serialized['name'], equals('Test Product'));
      expect(serialized['price'], equals(99.99));

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

    test('Queue should work with JsonStringSerializer', () async {
      final queue = await factory.createQueue<TestOrder>(
        'test-string-serializer',
        serializer: JsonStringSerializer(),
      );

      expect(queue.serializer, isA<JsonStringSerializer>());

      // Basic queue operations should still work
      await queue.enqueuePayload(testOrder);
      final dequeued = await queue.dequeue();

      expect(dequeued, isNotNull);
      expect(dequeued!.payload, equals(testOrder));

      await queue.acknowledge(dequeued.id);
    });

    test('Queue should work with JsonMapSerializer', () async {
      final queue = await factory.createQueue<TestOrder>(
        'test-map-serializer',
        serializer: JsonMapSerializer(),
      );

      expect(queue.serializer, isA<JsonMapSerializer>());

      // Basic queue operations should still work
      await queue.enqueuePayload(testOrder);
      final dequeued = await queue.dequeue();

      expect(dequeued, isNotNull);
      expect(dequeued!.payload, equals(testOrder));

      await queue.acknowledge(dequeued.id);
    });

    test('Queue should work with BinarySerializer', () async {
      final queue = await factory.createQueue<TestOrder>(
        'test-binary-serializer',
        serializer: BinarySerializer(),
      );

      expect(queue.serializer, isA<BinarySerializer>());

      // Basic queue operations should still work
      await queue.enqueuePayload(testOrder);
      final dequeued = await queue.dequeue();

      expect(dequeued, isNotNull);
      expect(dequeued!.payload, equals(testOrder));

      await queue.acknowledge(dequeued.id);
    });

    test('Queue should work without a serializer', () async {
      final queue = await factory.createQueue<TestOrder>('test-no-serializer');

      expect(queue.serializer, isNull);

      // Basic queue operations should still work
      await queue.enqueuePayload(testOrder);
      final dequeued = await queue.dequeue();

      expect(dequeued, isNotNull);
      expect(dequeued!.payload, equals(testOrder));

      await queue.acknowledge(dequeued.id);
    });

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
      'JsonStringSerializer should throw SerializationError on invalid data',
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
      'InMemoryQueue should actually serialize/deserialize during storage',
      () async {
        // Create a tracking serializer to verify it's being called
        var serializeCallCount = 0;
        var deserializeCallCount = 0;

        final trackingSerializer = _TrackingSerializer(
          onSerialize: () => serializeCallCount++,
          onDeserialize: () => deserializeCallCount++,
        );

        final queue = await factory.createQueue<TestOrder>(
          'test-tracking-serializer',
          serializer: trackingSerializer,
        );

        // Enqueue should call serialize
        await queue.enqueuePayload(testOrder);
        expect(serializeCallCount, equals(1));
        expect(deserializeCallCount, equals(0));

        // Dequeue should call deserialize
        final dequeued = await queue.dequeue();
        expect(serializeCallCount, equals(1));
        expect(deserializeCallCount, equals(1));

        expect(dequeued, isNotNull);
        expect(dequeued!.payload, equals(testOrder));

        await queue.acknowledge(dequeued.id);
      },
    );

    test(
      'InMemoryQueue should throw SerializationError during enqueue if serialization fails',
      () async {
        final faultySerializer = _FaultySerializer<TestOrder>(
          failOnSerialize: true,
        );

        final queue = await factory.createQueue<TestOrder>(
          'test-serialize-error',
          serializer: faultySerializer,
        );

        expect(
          () => queue.enqueuePayload(testOrder),
          throwsA(isA<SerializationError>()),
        );
      },
    );

    test(
      'InMemoryQueue should throw DeserializationError during dequeue if deserialization fails',
      () async {
        final faultySerializer = _FaultySerializer<TestOrder>(
          failOnDeserialize: true,
        );

        final queue = await factory.createQueue<TestOrder>(
          'test-deserialize-error',
          serializer: faultySerializer,
        );

        // Enqueue should work (serialization is not failing)
        await queue.enqueuePayload(testOrder);

        // Dequeue should fail (deserialization is failing)
        expect(() => queue.dequeue(), throwsA(isA<DeserializationError>()));
      },
    );

    test(
      'InMemoryQueue without serializer should not call any serialization',
      () async {
        var serializeCallCount = 0;
        var deserializeCallCount = 0;

        // This queue has no serializer, so these counters should stay at 0
        final queue = await factory.createQueue<TestOrder>(
          'test-no-serializer-calls',
        );

        await queue.enqueuePayload(testOrder);
        final dequeued = await queue.dequeue();

        expect(dequeued, isNotNull);
        expect(dequeued!.payload, equals(testOrder));
        expect(serializeCallCount, equals(0));
        expect(deserializeCallCount, equals(0));

        await queue.acknowledge(dequeued.id);
      },
    );
  });
}

/// Test serializer that tracks when serialize/deserialize are called
class _TrackingSerializer implements MessageSerializer<TestOrder, String> {
  final void Function() onSerialize;
  final void Function() onDeserialize;

  _TrackingSerializer({required this.onSerialize, required this.onDeserialize});

  @override
  String serialize(TestOrder payload) {
    onSerialize();
    return JsonStringSerializer().serialize(payload);
  }

  @override
  TestOrder deserialize(String data) {
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
