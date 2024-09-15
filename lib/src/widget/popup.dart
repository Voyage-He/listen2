import 'package:flutter/material.dart';

class Popup extends StatefulWidget {
  Widget child;
  Popup(this.child, {super.key});

  @override
  State<Popup> createState() => PopupState();
}

class PopupState extends State<Popup> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  open() {
    _animationController.forward();
  }

  close() {
    _animationController.reverse();
  }

  toggle() {
    if (_animationController.isCompleted) {
      close();
    } else if (_animationController.isDismissed) {
      open();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 3), // 从屏幕底部滑入
        end: const Offset(0, 2),
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      )),
      child: Container(
        width: double.infinity,
        height: 300,
        color: Colors.grey,
        child: widget.child,
      ),
    );
  }
}
