import 'package:flutter/material.dart';

class Button extends StatefulWidget {
  Button({
    super.key,
    required this.onTap,
    this.child,
    this.circle = false
  });

  final GestureTapCallback onTap;
  final Widget? child;
  bool taped = false;
  bool circle;

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() { widget.taped = true; }),
      onTapUp: (_) => setState(() { widget.taped = false; }),
      onTapCancel: () => setState(() { widget.taped = false; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: widget.circle ? (widget.taped ? const EdgeInsets.all(40) : const EdgeInsets.all(41)) : EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
          color: Colors.blue
        ),
        child: widget.child,
      )
    );
  }
}