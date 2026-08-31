import 'package:device_lab/src/data/native_apis/device_info_api.dart';
import 'package:flutter/material.dart';

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
              onPressed: () async {
                final result = await DeviceInfoApi().ping();
                setState(() {
                  nativeMessage = result;
                });
              },
              child: const Text('Ping Android'),
            ),
            const SizedBox(
              height: 30,
            ),
            Text('Native Answer: $nativeMessage'),
          ],
        ),
      ),
    );
  }
}
