import 'package:web/web.dart' as web;

Future<void> setApplicationTitle(String title) async {
  web.document.title = title;
}
