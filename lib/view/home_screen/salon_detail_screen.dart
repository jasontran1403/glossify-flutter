import 'package:flutter/material.dart';

class SalonDetailScreen extends StatelessWidget {
  final Map<String, String> salon;

  const SalonDetailScreen({super.key, required this.salon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(salon["name"]!)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Tên tiệm: ${salon['name']}",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Tiểu bang: ${salon['state']}",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Quay lại"),
            )
          ],
        ),
      ),
    );
  }
}
