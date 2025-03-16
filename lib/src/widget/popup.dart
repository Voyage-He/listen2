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

    _animationController.addListener(() {
      setState(() {
        // 每次动画状态变化都会触发重建，可修改为AnimationBuilder，自动更新状态
      });
    });
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
    if (_animationController.isDismissed) return const SizedBox.shrink();
    return Stack(
      children: [
        modal(),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 400,
          child: Center(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1), // 从屏幕底部滑入
                end: const Offset(0, 0),
              ).animate(CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeInOut,
              )),
              child: Container(
                // color: Colors.grey,
                child: widget.child,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget modal() {
    return GestureDetector(
      onTap: () => close(),
      child: Container(
        color: Color.fromARGB(150, 0, 0, 0),
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}
