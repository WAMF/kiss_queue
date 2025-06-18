import 'package:collection/collection.dart';

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

  @override
  String toString() =>
      'Order($orderId: \$${amount.toStringAsFixed(2)} for $customerId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order &&
          runtimeType == other.runtimeType &&
          orderId == other.orderId &&
          customerId == other.customerId &&
          amount == other.amount &&
          const ListEquality<String>().equals(items, other.items);

  @override
  int get hashCode => Object.hash(orderId, customerId, amount, items);
}
