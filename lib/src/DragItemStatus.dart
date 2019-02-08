class DragItemStatus {
  const DragItemStatus._(this.name);

  final String name;

  static const ABOVE = DragItemStatus._('ABOVE');
  static const BELOW = DragItemStatus._('BELOW');
  static const HOVER = DragItemStatus._('HOVER');
  static const SETTLED = DragItemStatus._('SETTLED');

  factory DragItemStatus(int currentIndex, int hoverIndex) {
    if (hoverIndex == null) return DragItemStatus.SETTLED;
    if (currentIndex == hoverIndex) return DragItemStatus.HOVER;
    if (currentIndex < hoverIndex) return DragItemStatus.ABOVE;
    if (currentIndex > hoverIndex) return DragItemStatus.BELOW;
    throw Exception('Cannot determine DragItemStatus. ' +
        'Indices were: $currentIndex (current), $hoverIndex (hover).');
  }

  @override
  String toString() => '$runtimeType.$name';
}
