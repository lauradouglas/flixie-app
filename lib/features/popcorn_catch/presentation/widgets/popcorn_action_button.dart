import 'package:flutter/material.dart';

/// Gold and purple card actions from the approved cinema challenge mockup.
class PopcornActionButton extends StatelessWidget {
  const PopcornActionButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.gold = true});
  final String label;
  final VoidCallback? onPressed;
  final bool gold;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gold
                    ? const [Color(0xFFFFE8A5), Color(0xFFFFCA56)]
                    : const [Color(0xFFB568FF), Color(0xFF7D32DA)])),
        child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                foregroundColor: gold ? const Color(0xFF28143D) : Colors.white,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            child: Text(label, textAlign: TextAlign.center)),
      );
}
