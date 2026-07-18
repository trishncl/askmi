import 'package:flutter/material.dart';
import '../../core/widgets/empty_state.dart';

/// Stand-in for destinations whose sprint hasn't happened yet. Keeps the
/// drawer and bottom nav fully navigable while Phase 4 is built one
/// module at a time, instead of dead-ending on a blank screen.
class ComingSoonPage extends StatelessWidget {
  final String title;
  const ComingSoonPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icons.construction_rounded,
        title: '$title is coming up',
        message: 'This module is scheduled for a later sprint in Phase 4.',
      ),
    );
  }
}