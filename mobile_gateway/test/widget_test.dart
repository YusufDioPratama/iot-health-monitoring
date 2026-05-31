import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_gateway/main.dart';

void main() {
  testWidgets('builds gateway app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GatewayApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
