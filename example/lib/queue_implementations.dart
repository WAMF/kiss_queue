import 'package:aws_sqs_api/sqs-2012-11-05.dart';
import 'package:kiss_queue/kiss_queue.dart';
import 'package:kiss_amazon_sqs_queue/kiss_amazon_sqs_queue.dart';

enum QueueImplementation {
  inMemory('In-Memory Queue', 'Local in-memory implementation (default)'),
  amazonSqs('Amazon SQS', 'AWS SQS implementation (requires configuration)');

  const QueueImplementation(this.displayName, this.description);

  final String displayName;
  final String description;
}

class AwsCredentials {
  final String accessKey;
  final String secretKey;
  final String region;
  final String? endpointUrl;

  const AwsCredentials({
    required this.accessKey,
    required this.secretKey,
    this.region = 'us-east-1',
    this.endpointUrl, // Defaults to null - uses AWS default endpoints
  });
}

class QueueImplementations {
  static Future<Queue<String, String>> createQueue(
    QueueImplementation implementation, {
    AwsCredentials? awsCredentials,
  }) async {
    switch (implementation) {
      case QueueImplementation.inMemory:
        return _createInMemoryQueue();
      case QueueImplementation.amazonSqs:
        return _createAmazonSqsQueue(awsCredentials);
    }
  }

  static Future<Queue<String, String>> _createInMemoryQueue() async {
    final factory = InMemoryQueueFactory<String, String>();
    return await factory.createQueue(
      'demo-queue',
      configuration: const QueueConfiguration(
        maxReceiveCount: 3,
        visibilityTimeout: Duration(seconds: 30),
      ),
    );
  }

  static Future<Queue<String, String>> _createAmazonSqsQueue(
    AwsCredentials? credentials,
  ) async {
    if (credentials == null) {
      throw Exception('AWS credentials are required for SQS implementation');
    }

    try {
      final sqs = SQS(
        region: credentials.region,
        credentials: AwsClientCredentials(
          accessKey: credentials.accessKey,
          secretKey: credentials.secretKey,
        ),
        endpointUrl: credentials.endpointUrl,
      );

      final factory = SqsQueueFactory<String, String>(sqs: sqs);

      final sqsQueue = await factory.createQueue(
        'demo-queue',
        configuration: const QueueConfiguration(
          maxReceiveCount: 3,
          visibilityTimeout: Duration(seconds: 30),
        ),
      );

      // Create a wrapper that converts between String and Map<String, dynamic>
      return sqsQueue;
    } catch (e) {
      rethrow;
    }
  }
}
