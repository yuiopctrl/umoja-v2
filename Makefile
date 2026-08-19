.PHONY: flutter-get flutter-analyze flutter-test flutter-format flutter-web flutter-linux check

flutter-get:
	cd app && flutter pub get

flutter-analyze:
	cd app && flutter analyze

flutter-test:
	cd app && flutter test

flutter-format:
	cd app && dart format .

flutter-web:
	cd app && flutter run -d chrome

flutter-linux:
	cd app && flutter run -d linux

check: flutter-get flutter-format flutter-analyze flutter-test
