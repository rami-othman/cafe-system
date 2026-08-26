import '../debug/schedule_check_debug.dart';

class ApiResponseParser {
  const ApiResponseParser._();

  static dynamic unwrapData(dynamic body, {String? debugContext}) {
    if (debugContext != null) {
      ScheduleCheckDebug.log('parser entered: ApiResponseParser.unwrapData');
      ScheduleCheckDebug.responseShape(body);
    }
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }

    return body;
  }
}
