import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bucket_list_app/screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';

/// Mock User class
class MockUser extends Mock implements User {
  @override
  String get uid => 'test-uid';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders home screen title', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: HomeScreen(mockUser: MockUser())));
    expect(find.text('My Bucket Lists'), findsOneWidget);
  });

  testWidgets('renders add bucket list FAB', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: HomeScreen(mockUser: MockUser())));
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('tapping FAB opens new list dialog', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: HomeScreen(mockUser: MockUser())));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('New Bucket List'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}