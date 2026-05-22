import 'package:flutter_test/flutter_test.dart';
import 'package:gui_task_manager/app.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TaskManagerApp());

    // Check if the header text is present (example)
    expect(find.text('GUI Based Task Manager by Huzaifa and Danish'), findsOneWidget);

    // Optional: check if the first tab exists
    expect(find.text('Process'), findsOneWidget);
  });
}
