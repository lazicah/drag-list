import 'package:drag_list/src/AxisDimen.dart';
import 'package:drag_list/src/DragListState.dart';
import 'package:flutter/material.dart';

typedef Widget HandlelessDragItemBuilder<T>(BuildContext context, T item);
typedef Widget DragItemBuilder<T>(BuildContext context, T item, Widget handle);
typedef Widget HandlelessFeedbackBuilder<T>(
    BuildContext context, T item, Animation<double> transition);
typedef Widget FeedbackBuilder<T>(
    BuildContext context, T item, Widget handle, Animation<double> transition);
typedef Widget HandleFeedbackBuilder(
    BuildContext context, Animation<double> transition);
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

  /// Builder function that creates handle widget for each element of the list.
  final WidgetBuilder handleBuilder;

  /// Builder function that creates widget for each element of the list.
  final DragItemBuilder<T> builder;

  /// Builder function that creates handle widget of currently dragged item.
  /// If null, [handleBuilder] function will be used instead.
  final HandleFeedbackBuilder handleFeedbackBuilder;

  /// Builder function that creates widget of currently dragged item.
  /// If null, [builder] function will be used instead.
  final FeedbackBuilder<T> feedbackBuilder;

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

  /// The amount of space by which to inset the children.
  final EdgeInsetsGeometry padding;

  /// How the scroll view should respond to user input.
  final ScrollPhysics physics;

  DragList({
    @required this.items,
    @required this.itemExtent,
    @required this.builder,
    Key key,
    Duration animDuration,
    Duration dragDelay,
    double handleAlignment,
    Axis scrollDirection,
    bool shrinkWrap,
    FeedbackBuilder<T> feedbackBuilder,
    HandleFeedbackBuilder handleFeedbackBuilder,
    WidgetBuilder handleBuilder,
    this.onItemReorder,
    this.controller,
    this.padding,
    this.physics,
  })  : this.animDuration = animDuration ?? Duration(milliseconds: 300),
        this.dragDelay = dragDelay ?? Duration.zero,
        this.handleAlignment = handleAlignment ?? 0.0,
        this.scrollDirection = scrollDirection ?? Axis.vertical,
        this.shrinkWrap = shrinkWrap ?? false,
        this.handleBuilder =
            handleBuilder ?? ((_) => _buildDefaultHandle(itemExtent)),
        this.feedbackBuilder = feedbackBuilder ??
            ((context, item, handle, _) => builder(context, item, handle)),
        this.handleFeedbackBuilder =
            handleFeedbackBuilder ?? ((context, _) => handleBuilder(context)),
        super(key: key) {
    assert(this.handleAlignment >= -1.0 && this.handleAlignment <= 1.0,
        'Handle alignment has to be in bounds (-1, 1) inclusive. Passed value was: $handleAlignment.');
  }

  DragList.handleless({
    @required List<T> items,
    @required double itemExtent,
    @required HandlelessDragItemBuilder<T> builder,
    Key key,
    HandlelessFeedbackBuilder<T> feedbackBuilder,
    Duration animDuration,
    Duration dragDelay,
    double handleAlignment,
    Axis scrollDirection,
    ScrollPhysics physics,
    bool shrinkWrap,
    ItemReorderCallback onItemReorder,
  }) : this(
          items: items,
          itemExtent: itemExtent,
          key: key,
          handleAlignment: handleAlignment,
          scrollDirection: scrollDirection,
          physics: physics,
          shrinkWrap: shrinkWrap,
          animDuration: animDuration,
          dragDelay: dragDelay ?? Duration(milliseconds: 300),
          onItemReorder: onItemReorder,
          handleBuilder: (_) => Container(),
          builder: (context, item, handle) => Stack(children: [
            builder(context, item),
            Positioned.fill(child: handle),
          ]),
          feedbackBuilder: (context, item, _, transition) =>
              feedbackBuilder(context, item, transition),
        );

  static Widget _buildDefaultHandle(double itemExtent) {
    final size = 24.0;
    final padding = (itemExtent - size).clamp(0.0, 8.0);
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Icon(Icons.drag_handle, size: size),
    );
  }

  @override
  DragListState<T> createState() => DragListState<T>();

  @override
  Axis get axis => scrollDirection;
}
