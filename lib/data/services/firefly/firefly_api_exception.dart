class FireflyApiException implements Exception {
  FireflyApiException._({
    required this.method,
    required this.uri,
    required this.statusCode,
    required this.message,
    required this.responseSnippet,
    required this.contentType,
    required this.isJson,
  });

  final String method;
  final Uri uri;
  final int statusCode;
  final String message;
  final String responseSnippet;
  final String? contentType;
  final bool isJson;

  String get userMessage => message;

  factory FireflyApiException.httpError({
    required String method,
    required Uri uri,
    required int statusCode,
    required String responseSnippet,
    required String? contentType,
    required bool isJson,
  }) {
    return FireflyApiException._(
      method: method,
      uri: uri,
      statusCode: statusCode,
      message:
          'Firefly III returned an error (HTTP $statusCode). Please try again.',
      responseSnippet: responseSnippet,
      contentType: contentType,
      isJson: isJson,
    );
  }

  factory FireflyApiException.unexpectedResponse({
    required String method,
    required Uri uri,
    required int statusCode,
    required String responseSnippet,
    required String? contentType,
    required bool isJson,
  }) {
    return FireflyApiException._(
      method: method,
      uri: uri,
      statusCode: statusCode,
      message: 'Firefly III returned an unexpected response. Please try again.',
      responseSnippet: responseSnippet,
      contentType: contentType,
      isJson: isJson,
    );
  }

  factory FireflyApiException.invalidJson({
    required String method,
    required Uri uri,
    required int statusCode,
    required String responseSnippet,
    required String? contentType,
  }) {
    return FireflyApiException._(
      method: method,
      uri: uri,
      statusCode: statusCode,
      message: 'Firefly III returned malformed data. Please try again.',
      responseSnippet: responseSnippet,
      contentType: contentType,
      isJson: true,
    );
  }

  factory FireflyApiException.authenticationRequired({
    required String method,
    required Uri uri,
    required String responseSnippet,
    required String? contentType,
  }) {
    return FireflyApiException._(
      method: method,
      uri: uri,
      statusCode: 401,
      message:
          'Authentication failed. Please check your Firefly III API token.',
      responseSnippet: responseSnippet,
      contentType: contentType,
      isJson: false,
    );
  }

  factory FireflyApiException.gatewayError({
    required String method,
    required Uri uri,
    required int statusCode,
    required String responseSnippet,
    required String? contentType,
  }) {
    final String message;
    switch (statusCode) {
      case 502:
        message =
            'Firefly III server is unreachable. This is usually a temporary issue. Please try again.';
        break;
      case 503:
        message =
            'Firefly III server is temporarily unavailable. Please try again in a moment.';
        break;
      case 504:
        message = 'Firefly III server timed out. Please try again.';
        break;
      default:
        message =
            'Firefly III returned an error (HTTP $statusCode). Please try again.';
    }

    return FireflyApiException._(
      method: method,
      uri: uri,
      statusCode: statusCode,
      message: message,
      responseSnippet: responseSnippet,
      contentType: contentType,
      isJson: false,
    );
  }

  @override
  String toString() => message;
}
