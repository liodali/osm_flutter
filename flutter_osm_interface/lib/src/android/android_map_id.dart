/// Stable identifier for a native Android map marker.
final class MarkerId {
  const MarkerId(this.value) : assert(value != '');

  final String value;

  @override
  bool operator ==(Object other) => other is MarkerId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MarkerId($value)';
}

/// Stable identifier for native Android road geometry.
final class RoadId {
  const RoadId(this.value) : assert(value != '');

  final String value;

  @override
  bool operator ==(Object other) => other is RoadId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'RoadId($value)';
}

/// Stable identifier for a native Android shape.
final class ShapeId {
  const ShapeId(this.value) : assert(value != '');

  final String value;

  @override
  bool operator ==(Object other) => other is ShapeId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ShapeId($value)';
}

/// Stable identifier for a native Android static-position group.
final class StaticPositionId {
  const StaticPositionId(this.value) : assert(value != '');

  final String value;

  @override
  bool operator ==(Object other) =>
      other is StaticPositionId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'StaticPositionId($value)';
}
