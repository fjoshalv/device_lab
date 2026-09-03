import 'dart:async';

import 'package:device_lab/src/data/native_apis/device_info_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;

class DeviceInfoScreen extends StatefulWidget {
  const DeviceInfoScreen({super.key});

  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> {
  String nativeMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Info'),
        centerTitle: true,
      ),
      body: SizedBox(
        width: .infinity,
        child: Column(
          mainAxisAlignment: .center,
          children: <Widget>[
            FilledButton(
              onPressed: _getDeviceInfo,
              child: const Text('Get device info'),
            ),
            const SizedBox(
              height: 30,
            ),
            Text('Battery Level: $nativeMessage'),
          ],
        ),
      ),
    );
  }

  /// Can throw a [PlatformException] or [MissingPluginException] if the native
  /// code fails to get the device info or the method does not exist or isn't
  /// handled.
  Future<void> _getDeviceInfo() async {
    final deviceInfoApi = DeviceInfoApi();
    try {
      final batteryLevelResult = await deviceInfoApi.getBatteryInfo();
      final deviceInfoResult = await deviceInfoApi.getDeviceInfo();

      setState(() {
        nativeMessage = '$batteryLevelResult%\n$deviceInfoResult';
      });
    } catch (e) {
      _showErrorDialog();
    }
  }

  void _showErrorDialog() {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to get device info.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}
