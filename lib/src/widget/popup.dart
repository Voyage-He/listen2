import 'package:flutter/material.dart';

class Popup extends StatefulWidget {
  const Popup(this.child, {super.key});
  final Widget child;
  @override
  State<Popup> createState() => PopupState();
}

class PopupState extends State<Popup> with SingleTickerProviderStateMixin {
  late final _animationController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240))
    ..addListener(() => setState(() {}));
  void open() => _animationController.forward();
  void close() => _animationController.reverse();
  void toggle() => _animationController.isDismissed ? open() : close();
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_animationController.isDismissed) return const SizedBox.shrink();
    return LayoutBuilder(
        builder: (context, constraints) => Stack(children: [
              Positioned.fill(
                  child: GestureDetector(
                      onTap: close,
                      child: ColoredBox(
                          color: Colors.black.withOpacity(
                              0.32 * _animationController.value)))),
              Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: (constraints.maxHeight * 0.75).clamp(0.0, 420.0),
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 1), end: Offset.zero)
                        .animate(CurvedAnimation(
                            parent: _animationController,
                            curve: Curves.easeOutCubic)),
                    child: Material(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28)),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                            child: Column(children: [
                              Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                      color: Colors.black12,
                                      borderRadius: BorderRadius.circular(4))),
                              const SizedBox(height: 20),
                              Expanded(child: widget.child),
                            ]))),
                  )),
            ]));
  }
}
