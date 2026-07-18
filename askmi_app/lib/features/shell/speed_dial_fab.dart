import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

class SpeedDialAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const SpeedDialAction({required this.label, required this.icon, required this.onTap});
}

/// Expandable FAB: the main button rotates into an X while the actions
/// stagger upward. Written by hand to avoid another package dependency.
class SpeedDialFab extends StatefulWidget {
  final List<SpeedDialAction> actions;
  const SpeedDialFab({super.key, required this.actions});

  @override
  State<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends State<SpeedDialFab> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() {
      _open = !_open;
      _open ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < widget.actions.length; i++)
          _buildAction(widget.actions[i], i),
        FloatingActionButton(
          heroTag: 'speedDialMain',
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          onPressed: _toggle,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.rotate(
              angle: _controller.value * 0.75,
              child: Icon(_open ? Icons.close_rounded : Icons.add_rounded),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAction(SpeedDialAction action, int index) {
    // Stagger: each action's slice of the parent animation starts slightly
    // later than the one below it.
    final start = index * 0.12;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(start.clamp(0.0, 0.6), 1.0, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Transform.scale(
        scale: curved.value.clamp(0.0, 1.0),
        alignment: Alignment.bottomRight,
        child: Opacity(opacity: curved.value.clamp(0.0, 1.0), child: child),
      ),
      child: IgnorePointer(
        ignoring: !_open,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  action.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.small(
                heroTag: 'speedDial_${action.label}',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.teal,
                elevation: 2,
                onPressed: () {
                  _toggle();
                  action.onTap();
                },
                child: Icon(action.icon, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}