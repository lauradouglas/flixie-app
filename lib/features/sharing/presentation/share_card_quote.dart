import 'package:flutter/material.dart';

const shareCardQuoteLimit = 180;

/// An editable starting excerpt for finite-size artwork, never a diary edit.
String shareCardQuoteExcerpt(String? note) {
  final text = note?.trim() ?? '';
  if (text.characters.length <= shareCardQuoteLimit) return text;
  final excerpt = text.characters.take(shareCardQuoteLimit).toString();
  final lastSpace = excerpt.lastIndexOf(RegExp(r'\s'));
  return (lastSpace > shareCardQuoteLimit * .7
          ? excerpt.substring(0, lastSpace)
          : excerpt)
      .trimRight();
}
