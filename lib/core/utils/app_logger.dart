import 'package:logger/logger.dart';

/// Keep normal Flutter runs readable. Pass
/// `--dart-define=VERBOSE_FLUTTER_LOGS=true` only when investigating an issue.
const verboseFlutterLogs = bool.fromEnvironment(
  'VERBOSE_FLUTTER_LOGS',
  defaultValue: false,
);

const _logLevel = verboseFlutterLogs ? Level.debug : Level.warning;

/// Centralized logger for the app. Normal builds keep warnings and errors only.
final logger = Logger(
  level: _logLevel,
  printer: SimplePrinter(
    colors: false,
  ),
);

/// Logger for API/network calls. Request and response diagnostics are opt-in.
final apiLogger = Logger(
  level: _logLevel,
  printer: SimplePrinter(
    colors: false,
  ),
);
