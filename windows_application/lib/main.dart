import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/network/dev_auth_bootstrap.dart';
import 'core/services/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();
  await bootstrapDevAuthIfNeeded();

  runApp(const App());
}
