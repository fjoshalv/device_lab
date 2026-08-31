import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DeviceLab - Home'),
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: const Text('Device Info'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, 'device_info');
            },
          ),
          const Divider(
            height: 0,
          ),
        ],
      ),
    );
  }
}
