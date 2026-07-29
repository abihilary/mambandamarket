import 'package:flutter/material.dart';

class BottomActionBar extends StatelessWidget {
  final VoidCallback onMessagePressed;

  const BottomActionBar({Key? key, required this.onMessagePressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA2E03A), // Light bright lime green
            foregroundColor: Colors.black87,
            elevation: 0,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: onMessagePressed,
          icon: const Icon(Icons.chat_bubble_outline, size: 20),
          label: const Text(
            "Message",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}