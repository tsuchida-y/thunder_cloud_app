import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thunder_cloud_app/screens/intro/intro_screen.dart';

void main() {
  test('はじめての起動では使い方を見せる', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(IntroScreen.isDone(prefs), isFalse);
  });

  test('見せ終わった人には、もう見せない', () async {
    SharedPreferences.setMockInitialValues({'intro_done': true});
    final prefs = await SharedPreferences.getInstance();
    expect(IntroScreen.isDone(prefs), isTrue);
  });

  test('許可のお願いを済ませた人（1.0.4 から上げた人を含む）には見せない', () async {
    SharedPreferences.setMockInitialValues({'welcome_done': true});
    final prefs = await SharedPreferences.getInstance();
    expect(IntroScreen.isDone(prefs), isTrue);
  });
}
