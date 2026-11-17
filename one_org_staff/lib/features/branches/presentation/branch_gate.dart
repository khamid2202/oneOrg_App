import 'package:flutter/material.dart';

import '../application/branch_controller.dart';

/// Holds back [child] until the branch is known, so no screen can load data
/// for the wrong one.
class BranchGate extends StatefulWidget {
  const BranchGate({
    super.key,
    required this.controller,
    required this.onSignOut,
    required this.child,
  });

  final BranchController controller;
  final VoidCallback onSignOut;
  final Widget child;

  @override
  State<BranchGate> createState() => _BranchGateState();
}

class _BranchGateState extends State<BranchGate> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  void dispose() {
    widget.controller.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        switch (widget.controller.status) {
          case BranchStatus.loading:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            );
          case BranchStatus.ready:
            return widget.child;
          case BranchStatus.none:
            return _BranchProblem(
              message: 'You are not assigned to a branch yet.',
              onSignOut: widget.onSignOut,
            );
          case BranchStatus.error:
            return _BranchProblem(
              message: 'Could not load your branches.',
              onRetry: widget.controller.load,
              onSignOut: widget.onSignOut,
            );
        }
      },
    );
  }
}

class _BranchProblem extends StatelessWidget {
  const _BranchProblem({
    required this.message,
    required this.onSignOut,
    this.onRetry,
  });

  final String message;
  final VoidCallback onSignOut;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (onRetry != null)
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            TextButton(onPressed: onSignOut, child: const Text('Sign out')),
          ],
        ),
      ),
    );
  }
}
