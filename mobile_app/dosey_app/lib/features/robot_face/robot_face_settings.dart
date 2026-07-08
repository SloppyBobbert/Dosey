class RobotFaceSettings {
  const RobotFaceSettings({
    this.isFlipped = false,
    this.dimAfterInactivity = true,
  });

  final bool isFlipped;
  final bool dimAfterInactivity;

  RobotFaceSettings copyWith({bool? isFlipped, bool? dimAfterInactivity}) {
    return RobotFaceSettings(
      isFlipped: isFlipped ?? this.isFlipped,
      dimAfterInactivity: dimAfterInactivity ?? this.dimAfterInactivity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is RobotFaceSettings &&
        other.isFlipped == isFlipped &&
        other.dimAfterInactivity == dimAfterInactivity;
  }

  @override
  int get hashCode => Object.hash(isFlipped, dimAfterInactivity);
}
