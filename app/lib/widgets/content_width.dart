import 'package:flutter/material.dart';

/// Keeps a screen's content in a centered phone-width column on wide windows.
class ContentWidth extends StatelessWidget {
  final Widget child;

  const ContentWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SizedBox.expand(child: child),
        ),
      );
}
