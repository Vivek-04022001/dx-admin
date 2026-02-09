import 'package:flutter/material.dart';


// --- Common Screen Structure for Management Sections ---
// This is a reusable template for all management screens, providing
// a consistent AppBar and a flexible body for content.
class ManagementScreenTemplate extends StatelessWidget {
  final String title;
  final Widget bodyContent;
  final List<Widget>? actions; // Optional actions for the AppBar

  const ManagementScreenTemplate({
    super.key,
    required this.title,
    required this.bodyContent,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      // The drawer is handled by MainDashboard, so we don't need it here.
      // The body content is passed in.
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: bodyContent,
      ),
    );
  }
}
