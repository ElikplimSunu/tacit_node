import 'dart:developer' as developer;

/// Unified logger for TacitNode.
/// All logs use the tag 'TacitNode' so you can filter with:
///   adb logcat -s TacitNode
///   adb logcat | grep TacitNode
class TLog {
  static const String _tag = 'TacitNode';

  static void info(String message) {
    developer.log(message, name: _tag, level: 800);
  }

  static void warn(String message) {
    developer.log('⚠️ $message', name: _tag, level: 900);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      '❌ $message',
      name: _tag,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void success(String message) {
    developer.log('✅ $message', name: _tag, level: 800);
  }
}
