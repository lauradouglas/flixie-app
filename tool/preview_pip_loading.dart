// Standalone visual preview: no authentication or API requests.
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/widgets/pip_loading_strip.dart';

void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.darkTheme,
  home: Scaffold(
    backgroundColor: const Color(0xFF150C24),
    appBar: AppBar(title: const Text('Pip loading preview')),
    body: Center(child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 600),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        PipLoadingStrip(),
        SizedBox(height: 24),
        Padding(padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('Preview stays loading so you can watch Pip skip.', textAlign: TextAlign.center)),
      ]))),
  ),
));
