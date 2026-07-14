import 'package:logger/logger.dart';

/// Centralized logger for the app
final logger = Logger(
  printer: SimplePrinter(
    colors: false,
  ),
);

/// Logger for API/Network calls
final apiLogger = Logger(
  printer: SimplePrinter(
    colors: false,
  ),
);
