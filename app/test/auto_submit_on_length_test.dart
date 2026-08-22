import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/core/utils/auto_submit_on_length.dart';

void main() {
  test('fires once the controller reaches the target length', () {
    final controller = TextEditingController();
    var completions = 0;
    final autoSubmit = AutoSubmitOnLength(
      controller: controller,
      length: 4,
      onComplete: () => completions++,
    );
    addTearDown(autoSubmit.dispose);

    controller.text = '12';
    controller.text = '123';
    expect(completions, 0);

    controller.text = '1234';
    expect(completions, 1);
  });

  test('does not fire again for the same value (no duplicate auto-submit)', () {
    final controller = TextEditingController();
    var completions = 0;
    final autoSubmit = AutoSubmitOnLength(
      controller: controller,
      length: 4,
      onComplete: () => completions++,
    );
    addTearDown(autoSubmit.dispose);

    controller.text = '1234';
    expect(completions, 1);

    // Same 4-digit value re-set (e.g. a rebuild) must not re-trigger.
    controller.text = '1234';
    expect(completions, 1);
  });

  test(
    're-arms once the value changes to something new at the target length',
    () {
      final controller = TextEditingController();
      var completions = 0;
      final autoSubmit = AutoSubmitOnLength(
        controller: controller,
        length: 4,
        onComplete: () => completions++,
      );
      addTearDown(autoSubmit.dispose);

      controller.text = '1234';
      expect(completions, 1);

      controller.text = '';
      controller.text = '5678';
      expect(completions, 2);
    },
  );

  test(
    // Regression test: PIN setup confirms by retyping the *identical*
    // PIN, and re-uses one AutoSubmitOnLength across both steps — reset()
    // must re-arm it for that exact same value, or a real PIN-setup
    // confirm step would silently never auto-submit.
    'reset() re-arms auto-submit for the same value that just triggered '
    'it (PIN setup confirm step retypes the identical PIN)',
    () {
      final controller = TextEditingController();
      var completions = 0;
      final autoSubmit = AutoSubmitOnLength(
        controller: controller,
        length: 4,
        onComplete: () => completions++,
      );
      addTearDown(autoSubmit.dispose);

      controller.text = '1234';
      expect(completions, 1);

      controller.clear();
      autoSubmit.reset();
      controller.text = '1234';
      expect(completions, 2);
    },
  );

  test('never fires for a length other than the target', () {
    final controller = TextEditingController();
    var completions = 0;
    final autoSubmit = AutoSubmitOnLength(
      controller: controller,
      length: 6,
      onComplete: () => completions++,
    );
    addTearDown(autoSubmit.dispose);

    controller.text = '1234';
    controller.text = '12345678';
    expect(completions, 0);
  });
}
