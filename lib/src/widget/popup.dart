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
    print('adsa' + _animationController.status.toString());
    if (_animationController.isDismissed) return const SizedBox.shrink();
    return Stack(
      children: [
        modal(),
        SlideTransition(
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
            // color: Colors.grey,
            child: widget.child,
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
