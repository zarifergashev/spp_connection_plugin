import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spp_connection_plugin/spp_connection_plugin_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelSppConnectionPlugin platform = MethodChannelSppConnectionPlugin();
  const MethodChannel channel = MethodChannel('spp_connection_plugin');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
