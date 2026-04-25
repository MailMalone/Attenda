import 'package:flutter/material.dart';

/// Auto-scrolling marquee text. Scrolls horizontally if content overflows,
/// pauses at the end, then resets and repeats.
class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const ScrollingText({Key? key, required this.text, this.style}) : super(key: key);

  @override
  _ScrollingTextState createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> {
  final ScrollController _sc = ScrollController();
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeScroll());
  }

  @override
  void didUpdateWidget(ScrollingText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _running = false;
      if (_sc.hasClients) _sc.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeScroll());
    }
  }

  Future<void> _maybeScroll() async {
    if (!_sc.hasClients || _running) return;
    final max = _sc.position.maxScrollExtent;
    if (max <= 0) return;
    _running = true;
    await Future.delayed(const Duration(milliseconds: 1200));
    while (mounted && _running) {
      await _sc.animateTo(
        max,
        duration: Duration(milliseconds: (max * 12).round()),
        curve: Curves.linear,
      );
      if (!mounted) break;
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) break;
      _sc.jumpTo(0);
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  @override
  void dispose() {
    _running = false;
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _sc,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, softWrap: false),
    );
  }
}
