import 'package:flutter/material.dart';

class PlaceholderTable extends StatelessWidget {
  final String title;

  const PlaceholderTable({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title Screen (UI Placeholder)',
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}

