import 'package:flutter/material.dart';

class Input extends StatefulWidget {
  const Input(
      {super.key,
      this.onChange,
      this.onDone,
      this.hintText = '输入歌单名称',
      this.initialValue = '',
      this.textInputAction = TextInputAction.done});
  final ValueChanged<String>? onChange;
  final VoidCallback? onDone;
  final String hintText;
  final String initialValue;
  final TextInputAction textInputAction;

  @override
  State<Input> createState() => _InputState();
}

class _InputState extends State<Input> {
  late final _controller = TextEditingController(text: widget.initialValue);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        textInputAction: widget.textInputAction,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(hintText: widget.hintText),
        onChanged: widget.onChange,
        onSubmitted: (_) {
          FocusManager.instance.primaryFocus?.unfocus();
          widget.onDone?.call();
        },
      );
}
