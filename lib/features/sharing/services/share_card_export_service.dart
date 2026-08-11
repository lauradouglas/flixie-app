import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flixie_app/features/sharing/models/share_card_data.dart';

class ShareCardExportService {
  const ShareCardExportService();

  Future<Uint8List> renderPng(GlobalKey boundaryKey) async {
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('The share card is not ready yet.');
    }

    final image = await renderObject.toImage(pixelRatio: 3);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('The share image could not be created.');
      }
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> share({
    required Uint8List bytes,
    required ShareCardData data,
    required Rect origin,
  }) async {
    await Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: 'image/png', name: data.fileName)],
      fileNameOverrides: [data.fileName],
      sharePositionOrigin: origin,
    );
  }

  Future<void> save({
    required Uint8List bytes,
    required ShareCardData data,
  }) async {
    var allowed = await Gal.hasAccess();
    if (!allowed) allowed = await Gal.requestAccess();
    if (!allowed) {
      throw StateError('Photo access is needed to save this image.');
    }
    await Gal.putImageBytes(
      bytes,
      name: data.fileName.replaceFirst(RegExp(r'\.png$'), ''),
    );
  }

  Future<void> shareReferralInvite({
    required String inviteUrl,
    required String referralCode,
    required Rect origin,
  }) async {
    await Share.share(
      'Join me on Flixie — we can build joint lists, share recommendations '
      'and see what each other is watching.\n\n'
      '$inviteUrl\n\nReferral code: $referralCode',
      subject: 'Join me on Flixie',
      sharePositionOrigin: origin,
    );
  }
}
