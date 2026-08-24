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
