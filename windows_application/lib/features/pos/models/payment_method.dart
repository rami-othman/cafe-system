import 'package:flutter/material.dart';

enum PaymentMethod {
  cash(label: 'Cash', icon: Icons.payments_outlined),
  card(label: 'Card', icon: Icons.credit_card),
  wallet(label: 'Wallet', icon: Icons.account_balance_wallet_outlined),
  split(label: 'Split', icon: Icons.call_split);

  const PaymentMethod({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

extension PaymentMethodApiValue on PaymentMethod {
  String get apiValue {
    return switch (this) {
      PaymentMethod.cash => 'cash',
      PaymentMethod.card => 'card',
      PaymentMethod.wallet => 'wallet',
      PaymentMethod.split => 'split',
    };
  }
}

PaymentMethod paymentMethodFromApi(String value) {
  return switch (value) {
    'card' => PaymentMethod.card,
    'wallet' => PaymentMethod.wallet,
    'split' => PaymentMethod.split,
    _ => PaymentMethod.cash,
  };
}
