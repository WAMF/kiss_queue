# Kiss Queue Flutter Demo

A Flutter example app that demonstrates the `kiss_queue` interface with different queue implementations.

## Features

- **Interactive Queue Demo**: Visual interface to enqueue and dequeue messages
- **Multiple Implementations**: Switch between different queue backends
- **AWS Credential Prompts**: Easy setup for Amazon SQS with credential dialogs
- **Real-time Updates**: See messages being processed in real-time
- **Error Handling**: Graceful error display and handling

## Supported Queue Implementations

### 1. In-Memory Queue (Default)
- Local implementation using memory storage
- Perfect for development and testing
- No external dependencies required
- Built into the `kiss_queue` package

### 2. Amazon SQS (Demo Mode)
- Interactive credential configuration
- Demonstrates SQS integration patterns
- Shows credential handling best practices
- Can be upgraded to full SQS functionality

## Getting Started

### Basic Setup

1. **Navigate to the example directory:**
   ```bash
   cd example
   ```

2. **Get dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

The app will start with the In-Memory Queue implementation enabled by default.

## How to Use the Demo

### 1. Select Implementation
Use the dropdown at the top to choose between queue implementations:
- **In-Memory Queue**: Ready to use immediately
- **Amazon SQS**: Will prompt for AWS credentials

### 2. Configure AWS SQS (Optional)
When you select Amazon SQS, you'll be prompted to enter:
- **Access Key ID**: Your AWS access key
- **Secret Access Key**: Your AWS secret key  
- **Region**: AWS region (default: us-east-1)
- **Endpoint URL**: For LocalStack testing (default: http://localhost:4566)

**Note**: The current demo mode will show your credentials but not actually connect to SQS. See "Enabling Real SQS" below for full functionality.

### 3. Queue Operations
- **Add Messages**: Type a message and click "Enqueue"
- **Process Messages**: Click "Dequeue Message" to retrieve messages
- **Handle Messages**: Acknowledge, requeue, or reject dequeued messages
- **Monitor Progress**: Watch the pending and completed message columns

## Enabling Real SQS Functionality

To upgrade from demo mode to real SQS connectivity:

1. **Add dependencies to `pubspec.yaml`:**
   ```yaml
   dependencies:
     # ... existing dependencies ...
     kiss_amazon_sqs_queue: ^0.0.1
     aws_sqs_api: ^2.0.0
   ```

2. **Update `lib/queue_implementations.dart`:**
   - Uncomment the real SQS implementation code
   - Remove the demo exception throwing

3. **Set up your environment** (choose one):

   **Option A: LocalStack (Recommended for Testing)**
   ```bash
   # Install LocalStack
   pip install localstack
   
   # Start LocalStack with SQS
   localstack start
   ```

   **Option B: Real AWS**
   - Configure AWS credentials with SQS permissions
   - Use real AWS region and remove endpoint URL

4. **Test the connection:**
   ```bash
   flutter pub get
   flutter run
   ```

## Understanding the Credential Flow

### Security Features
- **Masked Display**: Only first 4 characters of access key shown
- **Secure Input**: Secret key field is obscured
- **Reconfiguration**: Easy credential updates without app restart
- **Cancellation**: Fallback to in-memory queue if cancelled

### Default Values
- **Region**: us-east-1 (configurable)
- **Endpoint**: http://localhost:4566 (LocalStack default)
- **Timeout**: 30 seconds visibility timeout
- **Retries**: 3 maximum receive attempts

## Understanding Queue Behavior

### Message Flow
1. **Enqueue**: Messages added to selected queue
2. **Dequeue**: Messages retrieved and become invisible
3. **Acknowledge**: Confirm successful processing
4. **Reject**: Return to queue (requeue) or discard

### Visibility Timeout
- Dequeued messages become invisible to other consumers
- Automatically return to queue if not acknowledged
- Prevents duplicate processing

### Dead Letter Queues
- Messages exceeding retry limits move to DLQ
- Prevents infinite retry loops
- Enables poison message analysis

## Architecture

```
lib/
├── main.dart                    # App entry point
├── queue_demo_screen.dart       # Main UI with credential dialogs
└── queue_implementations.dart   # Queue factory with AWS support
```

### Key Components

- **QueueDemoScreen**: UI with credential management
- **AwsCredentials**: Credential data class
- **QueueImplementations**: Factory supporting credential injection
- **Credential Dialog**: Secure credential collection UI

## Customization

### Adding Queue Implementations

1. **Define new implementation:**
   ```dart
   enum QueueImplementation {
     // ... existing ...
     myQueue('My Queue', 'Custom implementation');
   }
   ```

2. **Add factory method:**
   ```dart
   static Future<Queue<String, String>> _createMyQueue() async {
     // Your implementation
   }
   ```

3. **Update switch statement** in `createQueue()`

### Customizing Credential Dialog

The credential dialog can be modified to support:
- Additional fields (endpoint, timeout settings)
- Validation logic
- Credential persistence
- Different authentication methods

## Troubleshooting

### SQS Demo Mode
**"SQS Demo Mode - Credentials received"** message means:
- Credentials were successfully captured
- Demo mode is active (real SQS disabled)
- Follow "Enabling Real SQS" steps for full functionality

### Connection Issues
**Real SQS setup problems:**
- Verify LocalStack is running: `localstack status`
- Check AWS credentials have SQS permissions
- Confirm region and endpoint URL are correct
- Review CloudWatch logs for AWS errors

### Credential Problems
**Dialog or input issues:**
- Access key and secret key are required fields
- Region defaults to us-east-1 if empty
- Endpoint URL is optional (for LocalStack/custom endpoints)
- Use "Reconfigure" button to update credentials

## Getting Help

- [kiss_queue documentation](https://pub.dev/packages/kiss_queue)
- [kiss_amazon_sqs_queue docs](https://pub.dev/packages/kiss_amazon_sqs_queue)
- [LocalStack SQS documentation](https://docs.localstack.cloud/user-guide/aws/sqs/)
- [GitHub Issues](https://github.com/WAMF/kiss_queue)

## License

This example app is part of the kiss_queue project and is licensed under the MIT License. 
