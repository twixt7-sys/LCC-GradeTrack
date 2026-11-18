import 'package:flutter_test/flutter_test.dart';
import 'package:lcc_gradetrack/core/services/pin_service.dart';
import 'package:lcc_gradetrack/core/services/validators.dart';

void main() {
  test('score cannot exceed total', () {
    expect(Validators.score('21', '20'), 'Score cannot exceed total items.');
    expect(Validators.score('18', '20'), isNull);
    expect(Validators.score('-1', '20'), 'Score cannot be negative.');
    expect(Validators.score('', '20'), 'Enter the score.');
    expect(Validators.score('', '20', allowEmpty: true), isNull);
    expect(Validators.score('abc', '20'), 'Enter a number.');
  });

  test('total and units', () {
    expect(Validators.total('0'), 'Total must be greater than 0.');
    expect(Validators.total('20'), isNull);
    expect(Validators.units('0'), 'Units must be greater than 0.');
    expect(Validators.units('11'), 'Units must be 10 or less.');
    expect(Validators.units('3'), isNull);
  });

  test('weights must total 100', () {
    expect(Validators.weightsComplete([20, 15, 25, 40]), isTrue);
    expect(Validators.weightsComplete([20, 15, 25]), isFalse);
    expect(Validators.weightsStatus([20, 15, 25, 40]), '100%');
    expect(Validators.weightsStatus([20, 15, 25, 25]), '85% — 15% left');
    expect(Validators.weightsStatus([60, 50]), '110% — 10% over');
  });

  test('final grade range', () {
    expect(Validators.finalGrade(''), isNull);
    expect(Validators.finalGrade('1.75'), isNull);
    expect(
      Validators.finalGrade('0.5'),
      'Grade must be between 1.00 and 5.00.',
    );
  });

  test('PIN hash verifies and differs per salt', () {
    final salt = PinService.newSalt();
    final h = PinService.hash('1234', salt);
    expect(PinService.verify('1234', salt, h), isTrue);
    expect(PinService.verify('1235', salt, h), isFalse);
    expect(PinService.hash('1234', PinService.newSalt()), isNot(h));
    expect(Validators.pin('12a4'), 'Use 4 digits.');
    expect(Validators.pin('0420'), isNull);
  });
}
