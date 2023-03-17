import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Colors;

class ProgressBar extends StatefulWidget {
  double now;
  Future Function(double)? onSeek;

  ProgressBar({
    super.key,
    required this.now,
    this.onSeek
  });

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  bool _seeking = false;
  double _seek = 0;

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      width: 300,
      height: 20,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Align(child: _bar()),
          Align(
            alignment: Alignment(2 * (_seeking ? _seek : widget.now) - 1, 0),
            child: _indicator(),
          )
        ],
      )
    );
  }

  Widget _bar() {
    return Container(
      width: 300,
      height: 5,
      decoration: const BoxDecoration(
        color: Colors.white70,
        borderRadius: BorderRadius.all(Radius.circular(10))
      ),
    );
  }

  Widget _indicator() {
    return GestureDetector(
      onHorizontalDragStart: (details) {
        print(details);
        _seek = widget.now;
        _seeking = true;
        setState(() {});
      },
      onHorizontalDragUpdate: (details) {
        final delta = details.delta.dx / 300;
        _seek += delta;
        if (_seek < 0) _seek = 0;
        if (_seek > 1) _seek = 1;
        setState(() {});
      },
      onHorizontalDragEnd: (details) async {
        if (widget.onSeek != null) { await widget.onSeek!(_seek); }
        await Future.delayed(Duration.zero);
        widget.now = _seek;
        _seeking = false;
        setState(() {});
      },
      child: Container(
        width: 20.0,
        height: 20.0,
        decoration: BoxDecoration(
          color: _seeking ? Colors.blue : Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

