// lib/api/giftcard_transaction_history.dart
import 'package:flutter/material.dart';

class GiftCardTransactionHistory {
  final String code;
  final String ownerName;
  final double oldBalance;
  final double changeAmount;
  final double newBalance;
  final DateTime updateDate;
  final int paymentMethod;

  GiftCardTransactionHistory({
    required this.code,
    required this.ownerName,
    required this.oldBalance,
    required this.changeAmount,
    required this.newBalance,
    required this.updateDate,
    required this.paymentMethod,
  });

  factory GiftCardTransactionHistory.fromJson(Map<String, dynamic> json) {
    return GiftCardTransactionHistory(
      code: json['code'] ?? '',
      ownerName: json['ownerName'] ?? '',
      oldBalance: (json['oldBalance'] ?? 0.0).toDouble(),
      changeAmount: (json['changeAmount'] ?? 0.0).toDouble(),
      newBalance: (json['newBalance'] ?? 0.0).toDouble(),
      updateDate: DateTime.parse(json['updateDate']),
      paymentMethod: json['paymentMethod'] ?? 1,
    );
  }

  // Helper getter: Determine transaction type
  String get transactionType {
    // If old balance is 0 and change equals new balance, it's a CREATE
    if (oldBalance == 0.0 && changeAmount == newBalance) {
      return 'CREATE';
    }
    return 'TOPUP';
  }

  // Helper getter: Payment method as text
  String get paymentMethodText {
    return paymentMethod == 1 ? 'Credit' : 'Cash';
  }

  // Helper getter: Color based on transaction type
  Color get typeColor {
    return transactionType == 'CREATE' ? Colors.green : Colors.blue;
  }

  // Helper getter: Icon based on transaction type
  IconData get typeIcon {
    return transactionType == 'CREATE' ? Icons.add_card : Icons.account_balance_wallet;
  }
}