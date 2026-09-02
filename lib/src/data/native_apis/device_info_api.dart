import 'package:flutter/services.dart';

class DeviceInfoApi {
  static const _ch = MethodChannel('devicelab/device_info');

  Future<int> getBatteryInfo() async {
    return (await _ch.invokeMethod<int>('getBatteryLevel'))!;
  }

  Future<Map<String, String>> getDeviceInfo() async {
    return (await _ch.invokeMapMethod<String, String>('getDeviceInfo'))!;
  }
}
