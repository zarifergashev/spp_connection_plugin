import 'package:flutter_test/flutter_test.dart';
import 'package:spp_connection_plugin/spp_connection_plugin.dart';
import 'package:spp_connection_plugin/spp_connection_plugin_platform_interface.dart';
import 'package:spp_connection_plugin/spp_connection_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSppConnectionPluginPlatform
    with MockPlatformInterfaceMixin
    implements SppConnectionPluginPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SppConnectionPluginPlatform initialPlatform = SppConnectionPluginPlatform.instance;

  test('$MethodChannelSppConnectionPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSppConnectionPlugin>());
  });

  test('getPlatformVersion', () async {
    SppConnectionPlugin sppConnectionPlugin = SppConnectionPlugin();
    MockSppConnectionPluginPlatform fakePlatform = MockSppConnectionPluginPlatform();
    SppConnectionPluginPlatform.instance = fakePlatform;

    expect(await sppConnectionPlugin.getPlatformVersion(), '42');
  });
}
