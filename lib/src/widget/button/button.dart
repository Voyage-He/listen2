import 'package:flutter/material.dart';
import 'package:listen2/src/widget/app_style.dart';

class Button extends StatelessWidget {
  const Button(
      {super.key,
      required this.onTap,
      this.child,
      this.circle = false,
      this.disabled = false,
      this.color = AppStyle.accent});
  final GestureTapCallback onTap;
  final Widget? child;
  final bool circle;
  final bool disabled;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(4),
        child: FilledButton(
          onPressed: disabled ? null : onTap,
          style: FilledButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size(48, 48),
              shape: circle
                  ? const CircleBorder()
                  : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
          child: child ?? const SizedBox.shrink(),
        ),
      );
}
