import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Input extends StatefulWidget {
  Input({
    super.key,
    this.onChange
  });

  Function(String)? onChange;

  @override
  State<Input> createState() => _InputState();
}

class _InputState extends State<Input> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final String text = _controller.text;
      if (widget.onChange != null) {
        widget.onChange!(text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = FocusNode();
    return Listener(onPointerDown: (_){},
      child: EditableText(
        controller: _controller,
        focusNode: n,
        style: const TextStyle(color: Colors.black, fontSize: 20),
        cursorColor: Colors.blue.shade700,
        backgroundCursorColor: Colors.white10
      )
    );
    
  }
}