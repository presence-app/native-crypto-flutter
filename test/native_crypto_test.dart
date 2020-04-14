import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_crypto/native_crypto.dart';

void main() {
  const MethodChannel channel = MethodChannel('native_crypto');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });
}
