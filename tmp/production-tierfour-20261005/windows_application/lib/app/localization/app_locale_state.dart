import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

class AppLocaleState extends Equatable {
  const AppLocaleState({required this.locale, this.isLoaded = false});

  final Locale locale;
  final bool isLoaded;

  @override
  List<Object> get props => <Object>[locale, isLoaded];
}
