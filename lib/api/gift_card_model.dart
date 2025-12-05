// lib/api/models/user_gift_card.dart
class UserGiftCard {
  final int id;
  final String code;
  final double remainingBalance;
  final DateTime? lastTopupDate;
  final DateTime? lastUsageDate;
  final String status;
  final String ownerName;

  UserGiftCard({
    required this.id,
    required this.code,
    required this.remainingBalance,
    this.lastTopupDate,
    this.lastUsageDate,
    required this.status,
    required this.ownerName,
  });

  factory UserGiftCard.fromJson(Map<String, dynamic> json) {
    return UserGiftCard(
      id: json['id'],
      code: json['code'],
      remainingBalance: (json['remainingBalance'] as num).toDouble(),
      lastTopupDate: json['lastTopupDate'] != null
          ? DateTime.parse(json['lastTopupDate'])
          : null,
      lastUsageDate: json['lastUsageDate'] != null
          ? DateTime.parse(json['lastUsageDate'])
          : null,
      status: json['status'],
      ownerName: json['ownerName'],
    );
  }
}

// lib/api/models/gift_card_transaction.dart
class GiftCardTransaction {
  final int id;
  final String code;
  final String type; // CREATE, TOPUP, USAGE
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final DateTime transactionDate;
  final String description;
  final int? paymentMethod; // 1: Credit, 2: Cash, null for USAGE

  GiftCardTransaction({
    required this.id,
    required this.code,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.transactionDate,
    required this.description,
    this.paymentMethod,
  });

  factory GiftCardTransaction.fromJson(Map<String, dynamic> json) {
    return GiftCardTransaction(
      id: json['id'],
      code: json['code'],
      type: json['type'],
      amount: (json['amount'] as num).toDouble(),
      balanceBefore: (json['balanceBefore'] as num).toDouble(),
      balanceAfter: (json['balanceAfter'] as num).toDouble(),
      transactionDate: DateTime.parse(json['transactionDate']),
      description: json['description'] ?? '',
      paymentMethod: json['paymentMethod'],
    );
  }

  String get paymentMethodText {
    if (paymentMethod == null) return '';
    return paymentMethod == 1 ? 'Credit Card' : 'Cash';
  }

  bool get isPositive => type == 'CREATE' || type == 'TOPUP';
  bool get isNegative => type == 'USAGE';
}