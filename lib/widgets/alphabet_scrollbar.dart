import 'package:flutter/material.dart';

class AlphabetScrollbar extends StatefulWidget {
  final List<String> availableLetters;
  final String? activeLetter;
  final ValueChanged<String> onLetterChanged;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  const AlphabetScrollbar({
    super.key,
    required this.availableLetters,
    this.activeLetter,
    required this.onLetterChanged,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  @override
  State<AlphabetScrollbar> createState() => _AlphabetScrollbarState();
}

class _AlphabetScrollbarState extends State<AlphabetScrollbar> {
  @override
  Widget build(BuildContext context) {
    if (widget.availableLetters.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final itemHeight = totalHeight / widget.availableLetters.length;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragDown: (details) {
            widget.onDragStarted();
            _selectLetter(details.localPosition, itemHeight);
          },
          onVerticalDragUpdate: (details) {
            _selectLetter(details.localPosition, itemHeight);
          },
          onVerticalDragEnd: (_) => widget.onDragEnded(),
          onVerticalDragCancel: () => widget.onDragEnded(),
          child: const SizedBox(width: 28),
        );
      },
    );
  }

  void _selectLetter(Offset localPosition, double itemHeight) {
    final index = (localPosition.dy / itemHeight).floor().clamp(0, widget.availableLetters.length - 1);
    widget.onLetterChanged(widget.availableLetters[index]);
  }
}
