class CarouselPosition {
  CarouselPosition(int value) : value = _validate(value);

  static const int minValue = 0;
  static const int maxValue = 14;
  static final CarouselPosition start = CarouselPosition(0);

  final int value;

  bool get isStart => value == 0;
  bool get isDoseSlot => value >= 1 && value <= maxValue;

  CarouselPosition nextCounterclockwise() {
    return CarouselPosition(value == maxValue ? minValue : value + 1);
  }

  static int _validate(int value) {
    if (value < minValue || value > maxValue) {
      throw ArgumentError.value(value, 'value', 'Must be between 0 and 14.');
    }
    return value;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarouselPosition && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
