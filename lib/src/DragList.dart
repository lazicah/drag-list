import 'package:drag_list/src/AxisDimen.dart';
import 'package:drag_list/src/DragListState.dart';
import 'package:flutter/material.dart';

typedef Widget DragItemBuilder<T>(BuildContext context, T item, Widget handle);
typedef void ItemReorderCallback(int from, int to);

class DragList<T> extends StatefulWidget with AxisDimen {
  final List<T> items;
  final double itemExtent;
  final double handleAlignment;
  final Duration animDuration;
  final Duration dragDelay;
  final WidgetBuilder handleBuilder;
  final DragItemBuilder<T> builder;
  final ItemReorderCallback onItemReorder;
  final Axis scrollDirection;

  DragList({
    @required this.items,
    @required this.itemExtent,
    @required this.builder,
    Duration animDuration,
    Duration dragDelay,
    double handleAlignment,
    Axis scrollDirection,
    this.handleBuilder,
    this.onItemReorder,
  })  : this.animDuration = animDuration ?? Duration(milliseconds: 300),
        this.dragDelay = dragDelay ?? Duration(milliseconds: 300),
        this.handleAlignment = handleAlignment ?? 0.0,
        this.scrollDirection = scrollDirection ?? Axis.vertical {
    assert(this.handleAlignment >= -1.0 && this.handleAlignment <= 1.0,
        'Handle alignment has to be in bounds (-1, 1) inclusive. Passed value was: $handleAlignment.');
  }

  DragList.handleless({
    @required List<T> items,
    @required double itemExtent,
    Widget Function(BuildContext, T) builder,
    Duration animDuration,
    Duration dragDelay,
    double handleAlignment,
    Axis scrollDirection,
    ItemReorderCallback onItemReorder,
  }) : this(
          items: items,
          itemExtent: itemExtent,
          handleAlignment: handleAlignment,
          scrollDirection: scrollDirection,
          animDuration: animDuration,
          dragDelay: dragDelay,
          onItemReorder: onItemReorder,
          handleBuilder: (_) => Container(),
          builder: (context, item, handle) {
            return Stack(children: [
              builder(context, item),
              Positioned.fill(child: handle),
            ]);
          },
        );

  @override
  DragListState<T> createState() => DragListState<T>();

  @override
  Axis get axis => scrollDirection;
}
