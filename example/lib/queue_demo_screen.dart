import 'package:flutter/material.dart';
import 'package:kiss_queue/kiss_queue.dart';
import 'package:kiss_queue_example/queue_implementations.dart';

class QueueDemoScreen extends StatefulWidget {
  const QueueDemoScreen({super.key});

  @override
  State<QueueDemoScreen> createState() => _QueueDemoScreenState();
}

class _QueueDemoScreenState extends State<QueueDemoScreen> {
  QueueImplementation _selectedImplementation = QueueImplementation.inMemory;
  Queue<String, String>? _currentQueue;
  final List<QueueMessage<String>> _pendingMessages = [];
  final List<QueueMessage<String>> _acceptedMessages = [];
  final List<QueueMessage<String>> _rejectedMessages = [];
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  AwsCredentials? _awsCredentials;
  bool _showInstructions = false;

  @override
  void initState() {
    super.initState();
    _initializeQueue();
  }

  @override
  void dispose() {
    _currentQueue?.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initializeQueue() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // If SQS is selected and we don't have credentials, prompt for them
      if (_selectedImplementation == QueueImplementation.amazonSqs &&
          _awsCredentials == null) {
        final credentials = await _showCredentialsDialog();
        if (credentials == null) {
          // User cancelled, revert to in-memory
          setState(() {
            _selectedImplementation = QueueImplementation.inMemory;
          });
        } else {
          _awsCredentials = credentials;
        }
      }

      _currentQueue?.dispose();
      _currentQueue = await QueueImplementations.createQueue(
        _selectedImplementation,
        awsCredentials: _awsCredentials,
      );
      _pendingMessages.clear();
      _acceptedMessages.clear();
      _rejectedMessages.clear();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize queue: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<AwsCredentials?> _showCredentialsDialog() async {
    final accessKeyController = TextEditingController();
    final secretKeyController = TextEditingController();
    final regionController = TextEditingController(text: 'us-east-1');
    final endpointController = TextEditingController();

    return showDialog<AwsCredentials>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('AWS SQS Configuration'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter your AWS credentials to connect to SQS. Leave endpoint URL empty to use standard AWS endpoints.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: accessKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Access Key ID',
                    border: OutlineInputBorder(),
                    hintText: 'Enter AWS Access Key ID',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: secretKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Secret Access Key',
                    border: OutlineInputBorder(),
                    hintText: 'Enter AWS Secret Access Key',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: regionController,
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    border: OutlineInputBorder(),
                    hintText: 'us-east-1',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: endpointController,
                  decoration: const InputDecoration(
                    labelText: 'Endpoint URL (Optional)',
                    border: OutlineInputBorder(),
                    hintText:
                        'Leave empty for AWS, or http://localhost:4566 for LocalStack',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (accessKeyController.text.isNotEmpty &&
                    secretKeyController.text.isNotEmpty) {
                  final credentials = AwsCredentials(
                    accessKey: accessKeyController.text.trim(),
                    secretKey: secretKeyController.text.trim(),
                    region: regionController.text.trim().isNotEmpty
                        ? regionController.text.trim()
                        : 'us-east-1',
                    endpointUrl: endpointController.text.trim().isNotEmpty
                        ? endpointController.text.trim()
                        : null,
                  );
                  Navigator.of(context).pop(credentials);
                }
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _enqueueMessage() async {
    final messageText = _messageController.text.trim();

    if (messageText.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a message to enqueue';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    if (_currentQueue == null) {
      setState(() {
        _errorMessage =
            'Queue not initialized. Please select a queue implementation first.';
        _successMessage = null;
      });
      return;
    }

    try {
      final message = QueueMessage.create(messageText);
      await _currentQueue!.enqueue(message);

      setState(() {
        _messageController.clear();
        _successMessage = 'Message "$messageText" successfully added to queue!';
      });

      // Auto-hide success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to enqueue message: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _dequeueMessage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    if (_currentQueue == null) {
      setState(() {
        _errorMessage =
            'Queue not initialized. Please select a queue implementation first.';
      });
      return;
    }

    try {
      final message = await _currentQueue!.dequeue();
      if (message != null) {
        setState(() {
          _pendingMessages.add(message);
          _successMessage =
              'Message dequeued successfully! It\'s now pending processing.';
        });

        // Auto-hide success message after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      } else {
        setState(() {
          _errorMessage =
              'No messages available to dequeue. Try adding some messages first!';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to dequeue message: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptMessage(QueueMessage<String> message) async {
    try {
      await _currentQueue!.acknowledge(message.id!);
      setState(() {
        _pendingMessages.removeWhere((m) => m.id == message.id);
        _acceptedMessages.add(message);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to acknowledge message: $e';
      });
    }
  }

  Future<void> _rejectMessage(
    QueueMessage<String> message, {
    bool requeue = true,
  }) async {
    try {
      await _currentQueue!.reject(message.id!, requeue: requeue);
      setState(() {
        _pendingMessages.removeWhere((m) => m.id == message.id);
        _rejectedMessages.add(message);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to reject message: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Kiss Queue Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions Section
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'How Queue Demo Works',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.blue[800],
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showInstructions = !_showInstructions;
                            });
                          },
                          icon: Icon(
                            _showInstructions
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.blue[700],
                          ),
                          label: Text(
                            _showInstructions ? 'Hide' : 'Show',
                            style: TextStyle(color: Colors.blue[700]),
                          ),
                        ),
                      ],
                    ),
                    if (_showInstructions) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        '📝 Queue Operations:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildInstructionItem(
                        '1. Enqueue',
                        'Add messages to the queue for processing',
                        Icons.add_circle_outline,
                      ),
                      _buildInstructionItem(
                        '2. Dequeue',
                        'Retrieve messages for processing (makes them invisible to others)',
                        Icons.download,
                      ),
                      _buildInstructionItem(
                        '3. Acknowledge',
                        'Mark message as successfully processed (removes from queue)',
                        Icons.check_circle_outline,
                      ),
                      _buildInstructionItem(
                        '4. Reject',
                        'Return message to queue (requeue) or discard permanently',
                        Icons.cancel_outlined,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '⚡ Key Concepts:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildConceptItem(
                        'Visibility Timeout',
                        'Dequeued messages become invisible for 30 seconds to prevent duplicate processing',
                      ),
                      _buildConceptItem(
                        'Message Flow',
                        'Messages move: Queue → Pending (invisible) → Processed or back to Queue',
                      ),
                      _buildConceptItem(
                        'Retry Logic',
                        'Failed messages retry up to 3 times before being discarded',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Try: Add messages, dequeue them, then acknowledge or reject to see the flow!',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Queue Implementation',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<QueueImplementation>(
                      value: _selectedImplementation,
                      isExpanded: true,
                      underline: const SizedBox(),
                      onChanged: _isLoading
                          ? null
                          : (value) async {
                              if (value != null) {
                                // Clear credentials when switching implementations
                                if (value != _selectedImplementation) {
                                  _awsCredentials = null;
                                }
                                setState(() {
                                  _selectedImplementation = value;
                                });
                                await _initializeQueue();
                              }
                            },
                      items: QueueImplementation.values.map((impl) {
                        return DropdownMenuItem(
                          value: impl,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(impl.displayName),
                              Text(
                                impl.description,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    if (_selectedImplementation ==
                        QueueImplementation.amazonSqs) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            _awsCredentials != null
                                ? Icons.check_circle
                                : Icons.warning,
                            color: _awsCredentials != null
                                ? Colors.green
                                : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _awsCredentials != null
                                  ? 'AWS Credentials: ${_awsCredentials!.accessKey.substring(0, 4)}...'
                                  : 'AWS Credentials not configured',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    final credentials =
                                        await _showCredentialsDialog();
                                    if (credentials != null) {
                                      _awsCredentials = credentials;
                                      await _initializeQueue();
                                    }
                                  },
                            child: Text(
                              _awsCredentials != null
                                  ? 'Reconfigure'
                                  : 'Configure',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_errorMessage != null)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),

            if (_successMessage != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.green),
                        onPressed: () {
                          setState(() {
                            _successMessage = null;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Message to Queue',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Enter message content...',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: _isLoading
                                ? null
                                : (_) => _enqueueMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _enqueueMessage,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add),
                          label: const Text('Enqueue'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _dequeueMessage,
                    icon: const Icon(Icons.remove),
                    label: const Text('Dequeue Message'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pending Messages (${_pendingMessages.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _pendingMessages.length,
                                itemBuilder: (context, index) {
                                  final message = _pendingMessages[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message.payload,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                          Text(
                                            'ID: ${message.id?.substring(0, 8)}...',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: () =>
                                                    _acceptMessage(message),
                                                icon: const Icon(
                                                  Icons.check,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'Acknowledge',
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: () => _rejectMessage(
                                                  message,
                                                  requeue: true,
                                                ),
                                                icon: const Icon(
                                                  Icons.refresh,
                                                  size: 16,
                                                ),
                                                label: const Text('Requeue'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.grey[600],
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: () => _rejectMessage(
                                                  message,
                                                  requeue: false,
                                                ),
                                                icon: const Icon(
                                                  Icons.close,
                                                  size: 16,
                                                ),
                                                label: const Text('Reject'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor: Colors.black,
                                                  side: const BorderSide(
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Completed Messages',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView(
                                children: [
                                  if (_acceptedMessages.isNotEmpty) ...[
                                    Text(
                                      'Acknowledged (${_acceptedMessages.length})',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    ..._acceptedMessages.map(
                                      (message) => ListTile(
                                        dense: true,
                                        leading: const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                        title: Text(
                                          message.payload,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        subtitle: Text(
                                          'ID: ${message.id?.substring(0, 8)}...',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (_rejectedMessages.isNotEmpty) ...[
                                    Text(
                                      'Rejected (${_rejectedMessages.length})',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    ..._rejectedMessages.map(
                                      (message) => ListTile(
                                        dense: true,
                                        leading: const Icon(
                                          Icons.cancel,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        title: Text(
                                          message.payload,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        subtitle: Text(
                                          'ID: ${message.id?.substring(0, 8)}...',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(
    String title,
    String description,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(
                  context,
                ).style.copyWith(fontSize: 12),
                children: [
                  TextSpan(
                    text: title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  TextSpan(
                    text: ': $description',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: BoxDecoration(
              color: Colors.blue[600],
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(
                  context,
                ).style.copyWith(fontSize: 12),
                children: [
                  TextSpan(
                    text: title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  TextSpan(
                    text: ': $description',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
