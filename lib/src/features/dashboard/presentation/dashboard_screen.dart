import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PF Tracker')),
      body: const SafeArea(
        child: Center(child: Text('Complete setup to view your PF dashboard.')),
      ),
    );
  }
}
