class ApiResponseParser {
  const ApiResponseParser._();

  static dynamic unwrapData(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }

    return body;
  }
}
