import 'package:drag_list/src/AxisDimen.dart';
import 'package:drag_list/src/DragListState.dart';
import 'package:flutter/material.dart';

typedef Widget HandlelessBuilder<T>(BuildContext context, T item);
typedef Widget DragItemBuilder<T>(BuildContext context, T item, Widget handle);
typedef void ItemReorderCallback(int from, int to);

class DragList<T> extends StatefulWidget with AxisDimen {
  /// List of items displayed in the list.
  final List<T> items;

  /// Extent of each item widget in the list. Corresponds to
  /// width/height in case of horizontal/vertical axis orientation.
  final double itemExtent;

  /// Relative position within item widget that corresponds to the center of
  /// handle, where -1.0 stands for beginning and 1.0 for end of the item.
  final double handleAlignment;

  /// Duration of raise and drop animation of dragged item.
  final Duration animDuration;

  /// Duration between list item touch and drag start.
  final Duration dragDelay;

  /// Builder function that creates handle widget.
  final WidgetBuilder handleBuilder;

  /// Builder function that creates widget for eatch element of the list.
  final DragItemBuilder<T> builder;

  /// Callback function that invokes if dragged item changed
  /// its index and drag action is ended. By default this
  /// will swap start and end position in [items] list.
  final ItemReorderCallback onItemReorder;

  /// Axis orientation of the list widget.
  final Axis scrollDirection;

  /// Whether the extent of the scroll view in the scrollDirection
  /// should be determined by the contents being viewed.
  final bool shrinkWrap;
  
  /// An object that can be used to control the position to which this scroll
  /// view is scrolled.
  final ScrollController controller;

  DragList({
    @required this.items,
    @required this.itemExtent,
    @required this.builder,
    Duration animDuration,
    Duration dragDelay,
    double handleAlignment,
    Axis scrollDirection,
    bool shrinkWrap,
    this.handleBuilder,
    this.onItemReorder,
    this.controller,
  })  : this.animDuration = animDuration ?? Duration(milliseconds: 300),
        this.dragDelay = dragDelay ?? Duration.zero,
        this.handleAlignment = handleAlignment ?? 0.0,
        this.scrollDirection = scrollDirection ?? Axis.vertical,
        this.shrinkWrap = shrinkWrap ?? false {
    assert(this.handleAlignment >= -1.0 && this.handleAlignment <= 1.0,
        'Handle alignment has to be in bounds (-1, 1) inclusive. Passed value was: $handleAlignment.');
  }

  DragList.handleless({
    @required List<T> items,
    @required double itemExtent,
    HandlelessBuilder<T> builder,
    Duration animDuration,
    Duration dragDelay,
    double handleAlignment,
    Axis scrollDirection,
    bool shrinkWrap,
    ItemReorderCallback onItemReorder,
  }) : this(
          items: items,
          itemExtent: itemExtent,
          handleAlignment: handleAlignment,
          scrollDirection: scrollDirection,
          shrinkWrap: shrinkWrap,
          animDuration: animDuration,
          dragDelay: dragDelay ?? Duration(milliseconds: 300),
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
