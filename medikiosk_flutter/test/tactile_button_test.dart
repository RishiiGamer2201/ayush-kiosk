import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medikiosk_flutter/widgets/tactile_button.dart';

void main() {
  testWidgets('a tap presses; a finger that travels is scrolling, not pressing', (tester) async {
    var presses = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: TactileButton(onPressed: () => presses++, height: 60, width: 200, label: 'Confirm'),
    ))));
    await tester.tap(find.text('Confirm'));
    expect(presses, 1);
    // A swipe that starts on the button and lifts 120px away.
    final gesture = await tester.startGesture(tester.getCenter(find.text('Confirm')));
    await gesture.moveBy(const Offset(0, -120));
    await gesture.up();
    await tester.pump();
    expect(presses, 1);
  });
}
