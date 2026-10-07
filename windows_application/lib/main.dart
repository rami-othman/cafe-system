import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/errors/framework_error_filter.dart';
import 'core/network/dev_auth_bootstrap.dart';
import 'core/services/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installFrameworkErrorFilter();
  setupServiceLocator();
  await bootstrapDevAuthIfNeeded();

  runApp(const App());
}
