import 'package:flutter/material.dart';

class ProgressBar extends StatefulWidget {
  const ProgressBar({super.key, required this.now, this.onSeek});
  final double now;
  final Future Function(double)? onSeek;
  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  double? _seek;
  @override
  Widget build(BuildContext context) => Slider(
        value:
            _seek ?? (widget.now.isFinite ? widget.now.clamp(0.0, 1.0) : 0.0),
        onChanged: widget.onSeek == null
            ? null
            : (value) => setState(() => _seek = value),
        onChangeEnd: widget.onSeek == null
            ? null
            : (value) async {
                try {
                  await widget.onSeek!(value);
                } finally {
                  if (mounted) setState(() => _seek = null);
                }
              },
      );
}
