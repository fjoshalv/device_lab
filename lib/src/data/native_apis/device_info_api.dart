import 'package:flutter/services.dart';

class DeviceInfoApi {
  static const _ch = MethodChannel('devicelab/device_info');

  Future<String> ping() async {
    return (await _ch.invokeMethod<String>('ping'))!;
  }
}
