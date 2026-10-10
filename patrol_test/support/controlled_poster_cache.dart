import 'dart:ui' as ui;
import 'package:file/local.dart';
import 'package:file/file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Local synthetic 2:3 raster files at the requested CDN width. No image network
/// or artificial latency. Unique URL keys still use production image decoding.
class ControlledPosterCache extends CacheManager {
  ControlledPosterCache() : super(Config('poster-scroll-fixture'));
  final files = <int, File>{};
  final reads = <String, int>{};
  late Directory directory;
  Future<void> prepare() async {
    directory = await const LocalFileSystem()
        .systemTempDirectory
        .createTemp('poster-scroll-');
    for (final width in [92, 154, 185, 200, 300, 342, 500, 780, 1280]) {
      final height = (width * 1.5).round();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          Paint()..color = const Color(0xff442277));
      for (var y = 0; y < height; y += 12) {
        canvas.drawLine(
            Offset(0, y.toDouble()),
            Offset(width.toDouble(), (height - y).toDouble()),
            Paint()
              ..color = const Color(0xffccbbee)
              ..strokeWidth = 2);
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = directory.childFile('$width.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      files[width] = file;
      image.dispose();
      picture.dispose();
    }
  }

  @override
  Stream<FileResponse> getFileStream(String url,
      {String? key,
      Map<String, String>? headers,
      bool withProgress = false}) async* {
    final match = RegExp(r'/w(\d+)/').firstMatch(url);
    final width = match == null ? 342 : int.parse(match.group(1)!);
    if (!files.containsKey(width)) {
      throw StateError('Unprepared image width: $url');
    }
    reads.update(url, (n) => n + 1, ifAbsent: () => 1);
    yield FileInfo(files[width]!, FileSource.Cache,
        DateTime.now().add(const Duration(days: 1)), url);
  }

  Future<void> cleanUp() async {
    await dispose();
    await directory.delete(recursive: true);
  }
}
