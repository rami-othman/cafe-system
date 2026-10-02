import 'package:flutter/material.dart';

enum PaymentMethod {
  cash(icon: Icons.payments_outlined),
  card(icon: Icons.credit_card),
  wallet(icon: Icons.account_balance_wallet_outlined),
  shamCash(icon: Icons.qr_code_2),
  split(icon: Icons.call_split);

  const PaymentMethod({required this.icon});

  final IconData icon;
}

extension PaymentMethodApiValue on PaymentMethod {
  String get apiValue {
    return switch (this) {
      PaymentMethod.cash => 'cash',
      PaymentMethod.card => 'card',
      PaymentMethod.wallet => 'wallet',
      PaymentMethod.shamCash => 'sham_cash',
      PaymentMethod.split => 'split',
    };
  }
}

PaymentMethod paymentMethodFromApi(String value) {
  return switch (value) {
    'card' => PaymentMethod.card,
    'wallet' => PaymentMethod.wallet,
    'sham_cash' => PaymentMethod.shamCash,
    'split' => PaymentMethod.split,
    _ => PaymentMethod.cash,
  };
}
