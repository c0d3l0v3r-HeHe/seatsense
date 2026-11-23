import 'package:flutter_test/flutter_test.dart';
import 'package:seatsense/widgets.dart';

void main() {
  test('three crowding levels with labels', () {
    expect(levelLabels.length, 3);
    expect(levelLabels.first, 'Seats likely');
  });
}
