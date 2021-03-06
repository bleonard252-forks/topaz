// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:chat_conversation/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'MessageInput.onTapSharePhoto callback test',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        new MaterialApp(
          theme: new ThemeData(platform: TargetPlatform.fuchsia),
          home: const Material(
            child: const MessageInput(),
          ),
        ),
      );

      // Tapping this icon must not crash the app.
      await tester.tap(
        find.byWidgetPredicate(
          (Widget w) => (w is Icon && w.icon == Icons.photo_library),
        ),
      );

      int tapSharePhotoCount = 0;

      await tester.pumpWidget(
        new MaterialApp(
          theme: new ThemeData(platform: TargetPlatform.fuchsia),
          home: new Material(
            child: new MessageInput(
              onTapSharePhoto: () => ++tapSharePhotoCount,
            ),
          ),
        ),
      );

      await tester.tap(
        find.byWidgetPredicate(
          (Widget w) => (w is Icon && w.icon == Icons.photo_library),
        ),
      );

      expect(tapSharePhotoCount, 1);
    },
  );
}
