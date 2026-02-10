import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apex_run/main.dart';

void main() {
  testWidgets('ApexRunApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ApexRunApp()));
  });
}
