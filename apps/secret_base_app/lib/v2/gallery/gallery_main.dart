// Dev-only entry point that boots straight into the 2.0 gallery, without
// auth, sockets or Firebase:
//
//   flutter run -d chrome -t lib/v2/gallery/gallery_main.dart
import 'package:flutter/material.dart';

import 'v2_gallery_screen.dart';

void main() {
  runApp(
    const MaterialApp(
      title: '비밀기지 2.0 갤러리',
      debugShowCheckedModeBanner: false,
      home: V2GalleryScreen(),
    ),
  );
}
