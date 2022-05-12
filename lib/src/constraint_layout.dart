import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// author: hackware
/// home page: https:///github.com/hackware1993
/// email: hackware1993@gmail.com
class ConstraintLayout extends MultiChildRenderObjectWidget {
  /// Constraints can be separated from widgets
  final List<ConstraintDefine>? childConstraints;

  final bool debugShowGuideline;
  final bool debugShowClickArea;
  final bool debugPrintConstraints;
  final bool debugPrintLayoutTime;
  final bool debugCheckConstraints;
  final bool releasePrintLayoutTime;
  final String? debugName;
  final bool debugShowZIndex;
  final bool debugShowChildDepth;

  // fixed size、matchParent、wrapContent
  final double width;
  final double height;

  /// When size is non-null, both width and height are set to size
  final double? size;

  final ConstraintVersion? constraintVersion;

  ConstraintLayout({
    Key? key,
    this.childConstraints,
    required List<Widget> children,
    this.debugShowGuideline = false,
    this.debugShowClickArea = false,
    this.debugPrintConstraints = false,
    this.debugPrintLayoutTime = false,
    this.debugCheckConstraints = true,
    this.releasePrintLayoutTime = false,
    this.debugName,
    this.debugShowZIndex = false,
    this.debugShowChildDepth = false,
    this.width = matchParent,
    this.height = matchParent,
    this.size,
    this.constraintVersion,
  }) : super(
          key: key,
          children: children,
        );

  @override
  RenderObject createRenderObject(BuildContext context) {
    assert(_debugEnsureNotEmptyString('debugName', debugName));
    assert(width >= 0 || width == matchParent || width == wrapContent);
    assert(height >= 0 || height == matchParent || height == wrapContent);
    assert(size == null ||
        (size! >= 0 || size == matchParent || size == wrapContent));
    double selfWidth = width;
    double selfHeight = height;
    if (size != null) {
      selfWidth = size!;
      selfHeight = size!;
    }
    return _ConstraintRenderBox()
      ..childConstraints = childConstraints
      .._debugShowGuideline = debugShowGuideline
      .._debugShowClickArea = debugShowClickArea
      .._debugPrintConstraints = debugPrintConstraints
      .._debugPrintLayoutTime = debugPrintLayoutTime
      .._debugCheckConstraints = debugCheckConstraints
      .._releasePrintLayoutTime = releasePrintLayoutTime
      .._debugName = debugName
      .._debugShowZIndex = debugShowZIndex
      .._debugShowChildDepth = debugShowChildDepth
      .._width = selfWidth
      .._height = selfHeight
      .._constraintVersion = constraintVersion?.copy();
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    assert(_debugEnsureNotEmptyString('debugName', debugName));
    assert(width >= 0 || width == matchParent || width == wrapContent);
    assert(height >= 0 || height == matchParent || height == wrapContent);
    assert(size == null ||
        (size! >= 0 || size == matchParent || size == wrapContent));
    double selfWidth = width;
    double selfHeight = height;
    if (size != null) {
      selfWidth = size!;
      selfHeight = size!;
    }
    (renderObject as _ConstraintRenderBox)
      ..childConstraints = childConstraints
      ..debugShowGuideline = debugShowGuideline
      ..debugShowClickArea = debugShowClickArea
      ..debugPrintConstraints = debugPrintConstraints
      ..debugPrintLayoutTime = debugPrintLayoutTime
      ..debugCheckConstraints = debugCheckConstraints
      ..releasePrintLayoutTime = releasePrintLayoutTime
      ..debugName = debugName
      ..debugShowZIndex = debugShowZIndex
      ..debugShowChildDepth = debugShowChildDepth
      ..width = selfWidth
      ..height = selfHeight
      ..constraintVersion = constraintVersion?.copy();
  }
}

Offset circleTranslate({
  required double radius,
  required int angle,
}) {
  assert(radius >= 0 && radius != double.infinity);
  assert(angle >= 0 && angle <= 360);
  double xTranslate = sin((angle / 180) * pi) * radius;
  double yTranslate = -cos((angle / 180) * pi) * radius;
  return Offset(xTranslate, yTranslate);
}

List<Widget> constraintGrid({
  required ConstraintId id,
  required _Align left,
  required _Align top,
  required int itemCount,
  required int columnCount,
  double? itemWidth,
  double? itemHeight,
  double? itemSize,
  Size Function(int index, int rowIndex, int columnIndex)? itemSizeBuilder,
  required Widget Function(int index, int rowIndex, int columnIndex)
      itemBuilder,
  EdgeInsets Function(int index, int rowIndex, int columnIndex)?
      itemMarginBuilder,
  int Function(int index)? itemSpanBuilder,
  EdgeInsets margin = EdgeInsets.zero,
  CLVisibility visibility = visible,
  Offset translate = Offset.zero,
  bool translateConstraint = false,
  int? zIndex,
}) {
  assert(itemCount > 0);
  assert(columnCount > 0);
  assert(itemWidth == null || (itemWidth >= 0 || itemWidth != matchConstraint));
  assert(
      itemHeight == null || (itemHeight >= 0 || itemHeight != matchConstraint));
  assert(itemSize == null || (itemSize >= 0 || itemSize != matchConstraint));
  if (itemSize != null) {
    itemWidth = itemSize;
    itemHeight = itemSize;
  }
  assert((itemSizeBuilder == null && itemWidth != null && itemHeight != null) ||
      (itemSizeBuilder != null && itemWidth == null && itemHeight == null));
  List<Widget> widgets = [];
  _Align leftAnchor = left;
  _Align topAnchor = top;

  EdgeInsets leftMargin = EdgeInsets.only(
    left: margin.left,
  );
  EdgeInsets topMargin = EdgeInsets.only(
    top: margin.top,
  );

  List<ConstraintId> allChildIds = [];
  List<ConstraintId> leftChildIds = [];
  List<ConstraintId> topChildIds = [];
  List<ConstraintId> rightChildIds = [];
  List<ConstraintId> bottomChildIds = [];
  int totalAvailableSpanCount = (itemCount / columnCount).ceil() * columnCount;
  int currentRowIndex = -1;
  int currentRowUsedSpanCount = columnCount + 1;
  int totalUsedSpanCount = 0;
  late int currentRowBarrierCount;
  List<ConstraintId?> currentSpanSlot = List.filled(columnCount + 1, null);
  for (int i = 0; i < itemCount; i++) {
    ConstraintId itemId = ConstraintId(id.id + '_grid_item_$i');
    allChildIds.add(itemId);

    int itemSpan = itemSpanBuilder?.call(i) ?? 1;
    assert(itemSpan >= 1 && itemSpan <= columnCount);
    currentRowUsedSpanCount += itemSpan;
    totalUsedSpanCount += itemSpan;

    late EdgeInsets childMargin;

    /// New row start
    if (currentRowUsedSpanCount > columnCount) {
      currentRowIndex++;
      currentRowUsedSpanCount = itemSpan;
      currentRowBarrierCount = 0;
      if (i > 0) {
        if (!rightChildIds.contains(allChildIds[i - 1])) {
          /// Last column
          rightChildIds.add(allChildIds[i - 1]);
        }
      } else {
        if (itemSpan == columnCount) {
          /// Last column
          rightChildIds.add(itemId);
        }
      }

      /// First column
      leftAnchor = left;
      leftChildIds.add(itemId);
      childMargin = (itemMarginBuilder?.call(
                  i, currentRowIndex, currentRowUsedSpanCount - 1) ??
              EdgeInsets.zero)
          .add(leftMargin) as EdgeInsets;
    } else {
      childMargin = itemMarginBuilder?.call(
              i, currentRowIndex, currentRowUsedSpanCount - 1) ??
          EdgeInsets.zero;
    }

    // First row
    if (currentRowIndex == 0) {
      childMargin = childMargin.add(topMargin) as EdgeInsets;
      topChildIds.add(itemId);
    }

    // Last row
    if (totalAvailableSpanCount - totalUsedSpanCount < columnCount) {
      bottomChildIds.add(itemId);
    }

    if (currentRowIndex > 0) {
      if (itemSpan == 1) {
        topAnchor = currentSpanSlot[currentRowUsedSpanCount]!.bottom;
      } else {
        List<ConstraintId> referencedIds = [];
        for (int i = 0; i < itemSpan; i++) {
          ConstraintId id = currentSpanSlot[currentRowUsedSpanCount - i]!;
          if (!referencedIds.contains(id)) {
            referencedIds.add(id);
          }
        }
        ConstraintId rowBarrierId = ConstraintId(id.id +
            '_row_${currentRowIndex}_bottom_barrier_$currentRowBarrierCount');
        Barrier rowBottomBarrier = Barrier(
          id: rowBarrierId,
          direction: BarrierDirection.bottom,
          referencedIds: referencedIds,
        );
        widgets.add(rowBottomBarrier);
        topAnchor = rowBarrierId.bottom;
        currentRowBarrierCount++;
      }
    }

    Widget widget =
        itemBuilder(i, currentRowIndex, currentRowUsedSpanCount - 1);
    Size? itemSize =
        itemSizeBuilder?.call(i, currentRowIndex, currentRowUsedSpanCount - 1);
    double width = itemWidth ?? itemSize!.width;
    double height = itemHeight ?? itemSize!.height;

    widgets.add(Constrained(
      child: widget,
      constraint: Constraint(
        id: itemId,
        width: width,
        height: height,
        left: width == matchParent ? null : leftAnchor,
        top: height == matchParent ? null : topAnchor,
        zIndex: zIndex,
        translate: translate,
        visibility: visibility,
        margin: childMargin,
        goneMargin: childMargin,
      ),
    ));

    leftAnchor = itemId.right;
    for (int i = 0; i < itemSpan; i++) {
      currentSpanSlot[currentRowUsedSpanCount - i] = itemId;
    }
  }

  if (!rightChildIds.contains(allChildIds.last)) {
    rightChildIds.add(allChildIds.last);
  }

  Barrier leftBarrier = Barrier(
    id: ConstraintId(id.id + '_left_barrier'),
    direction: BarrierDirection.left,
    referencedIds: leftChildIds,
  );

  Barrier topBarrier = Barrier(
    id: ConstraintId(id.id + '_top_barrier'),
    direction: BarrierDirection.top,
    referencedIds: topChildIds,
  );

  Barrier rightBarrier = Barrier(
    id: ConstraintId(id.id + '_right_barrier'),
    direction: BarrierDirection.right,
    referencedIds: rightChildIds,
  );

  Barrier bottomBarrier = Barrier(
    id: ConstraintId(id.id + '_bottom_barrier'),
    direction: BarrierDirection.bottom,
    referencedIds: bottomChildIds,
  );

  widgets.add(leftBarrier);
  widgets.add(topBarrier);
  widgets.add(rightBarrier);
  widgets.add(bottomBarrier);

  widgets.add(const SizedBox().applyConstraint(
    id: id,
    size: matchConstraint,
    left: leftBarrier.id.left,
    top: topBarrier.id.top,
    right: rightBarrier.id.right,
    bottom: bottomBarrier.id.bottom,
    zIndex: -1,
    translate: translate,
    translateConstraint: translateConstraint,
    visibility: invisible,
  ));

  return widgets;
}

/// Not completed
List<Widget> horizontalChain({
  required _Align left,
  required _Align right,
  ChainStyle chainStyle = ChainStyle.spread,
  required List<Constrained> chainList,
}) {
  assert(chainList.length > 1,
      'The number of child elements in the chain must be > 1.');
  List<Widget> widgetList = [];
  Constrained? last;
  for (int i = 0; i < chainList.length; i++) {
    Constrained current = chainList[i];
    assert(current.constraint.left == null && current.constraint.right == null,
        'Elements in the horizontal chain can not have horizontal constraints.');
    assert(current.constraint.width != matchParent,
        'Elements in the chain cannot have width set to match_parent.');
    if (i == 0) {
      current.constraint.left = left;
    } else {
      if (i == chainList.length - 1) {
        current.constraint.right = right;
      }

      if (chainStyle == ChainStyle.spread) {
      } else if (chainStyle == ChainStyle.spreadInside) {
      } else {
        // packed
      }

      ConstraintId guidelineId = ConstraintId(
          'internal_horizontal_chain_guideline_$i@${chainList[0].constraint.hashCode}');
      Guideline guideline = Guideline(
        id: guidelineId,
        horizontal: false,
        guidelinePercent: 0.5,
      );

      widgetList.add(guideline);
      last!.constraint.right = guidelineId.left;
      current.constraint.left = guidelineId.right;
    }
    widgetList.add(current);
    last = current;
  }
  return widgetList;
}

/// Not completed
List<Widget> verticalChain({
  _Align? top,
  _Align? bottom,
  ConstraintId? centerVerticalTo,
  required List<Constrained> chainList,
}) {
  assert(chainList.length > 1,
      'The number of child elements in the chain must be > 1.');
  return [];
}

/// Wrapper constraints design for simplicity of use, it will eventually convert to base constraints.
const Object _wrapperConstraint = Object();
const Object _baseConstraint = Object();

extension ConstrainedWidgetsExt on Widget {
  Constrained applyConstraint({
    ConstraintId? id,
    double width = wrapContent,
    double height = wrapContent,
    double? size,
    @_baseConstraint _Align? left,
    @_baseConstraint _Align? top,
    @_baseConstraint _Align? right,
    @_baseConstraint _Align? bottom,
    @_baseConstraint _Align? baseline,
    EdgeInsets clickPadding = EdgeInsets.zero,
    CLVisibility visibility = visible,
    bool percentageMargin = false,
    EdgeInsets margin = EdgeInsets.zero,
    EdgeInsets goneMargin = EdgeInsets.zero,
    TextBaseline textBaseline = TextBaseline.alphabetic,
    int? zIndex, // default is child index
    Offset translate = Offset.zero,
    bool translateConstraint = false,
    double widthPercent = 1,
    double heightPercent = 1,
    PercentageAnchor widthPercentageAnchor = PercentageAnchor.constraint,
    PercentageAnchor heightPercentageAnchor = PercentageAnchor.constraint,
    double horizontalBias = 0.5,
    double verticalBias = 0.5,
    @_wrapperConstraint ConstraintId? topLeftTo,
    @_wrapperConstraint ConstraintId? topCenterTo,
    @_wrapperConstraint ConstraintId? topRightTo,
    @_wrapperConstraint ConstraintId? centerLeftTo,
    @_wrapperConstraint ConstraintId? centerTo,
    @_wrapperConstraint ConstraintId? centerRightTo,
    @_wrapperConstraint ConstraintId? bottomLeftTo,
    @_wrapperConstraint ConstraintId? bottomCenterTo,
    @_wrapperConstraint ConstraintId? bottomRightTo,
    @_wrapperConstraint ConstraintId? centerHorizontalTo,
    @_wrapperConstraint ConstraintId? centerVerticalTo,
    @_wrapperConstraint ConstraintId? outTopLeftTo,
    @_wrapperConstraint ConstraintId? outTopCenterTo,
    @_wrapperConstraint ConstraintId? outTopRightTo,
    @_wrapperConstraint ConstraintId? outCenterLeftTo,
    @_wrapperConstraint ConstraintId? outCenterRightTo,
    @_wrapperConstraint ConstraintId? outBottomLeftTo,
    @_wrapperConstraint ConstraintId? outBottomCenterTo,
    @_wrapperConstraint ConstraintId? outBottomRightTo,
    @_wrapperConstraint ConstraintId? centerTopLeftTo,
    @_wrapperConstraint ConstraintId? centerTopCenterTo,
    @_wrapperConstraint ConstraintId? centerTopRightTo,
    @_wrapperConstraint ConstraintId? centerCenterLeftTo,
    @_wrapperConstraint ConstraintId? centerCenterRightTo,
    @_wrapperConstraint ConstraintId? centerBottomLeftTo,
    @_wrapperConstraint ConstraintId? centerBottomCenterTo,
    @_wrapperConstraint ConstraintId? centerBottomRightTo,
    OnLayoutCallback? callback,
    double chainWeight = 1,
    bool percentageTranslate = false,
    double minWidth = 0,
    double maxWidth = matchParent,
    double minHeight = 0,
    double maxHeight = matchParent,
    double? widthHeightRatio,
    bool? ratioBaseOnWidth,
    int? eIndex,
    PinnedInfo? pinnedInfo,
  }) {
    return Constrained(
      key: key,
      constraint: Constraint(
        id: id,
        width: width,
        height: height,
        size: size,
        left: left,
        top: top,
        right: right,
        bottom: bottom,
        baseline: baseline,
        clickPadding: clickPadding,
        visibility: visibility,
        percentageMargin: percentageMargin,
        margin: margin,
        goneMargin: goneMargin,
        textBaseline: textBaseline,
        zIndex: zIndex,
        translate: translate,
        translateConstraint: translateConstraint,
        widthPercent: widthPercent,
        heightPercent: heightPercent,
        widthPercentageAnchor: widthPercentageAnchor,
        heightPercentageAnchor: heightPercentageAnchor,
        horizontalBias: horizontalBias,
        verticalBias: verticalBias,
        topLeftTo: topLeftTo,
        topCenterTo: topCenterTo,
        topRightTo: topRightTo,
        centerLeftTo: centerLeftTo,
        centerTo: centerTo,
        centerRightTo: centerRightTo,
        bottomLeftTo: bottomLeftTo,
        bottomCenterTo: bottomCenterTo,
        bottomRightTo: bottomRightTo,
        centerHorizontalTo: centerHorizontalTo,
        centerVerticalTo: centerVerticalTo,
        callback: callback,
        chainWeight: chainWeight,
        percentageTranslate: percentageTranslate,
        minWidth: minWidth,
        maxWidth: maxWidth,
        minHeight: minHeight,
        maxHeight: maxHeight,
        widthHeightRatio: widthHeightRatio,
        ratioBaseOnWidth: ratioBaseOnWidth,
        outTopLeftTo: outTopLeftTo,
        outTopCenterTo: outTopCenterTo,
        outTopRightTo: outTopRightTo,
        outCenterLeftTo: outCenterLeftTo,
        outCenterRightTo: outCenterRightTo,
        outBottomLeftTo: outBottomLeftTo,
        outBottomCenterTo: outBottomCenterTo,
        outBottomRightTo: outBottomRightTo,
        centerTopLeftTo: centerTopLeftTo,
        centerTopCenterTo: centerTopCenterTo,
        centerTopRightTo: centerTopRightTo,
        centerCenterLeftTo: centerCenterLeftTo,
        centerCenterRightTo: centerCenterRightTo,
        centerBottomLeftTo: centerBottomLeftTo,
        centerBottomCenterTo: centerBottomCenterTo,
        centerBottomRightTo: centerBottomRightTo,
        eIndex: eIndex,
        pinnedInfo: pinnedInfo,
      ),
      child: this,
    );
  }

  Constrained apply({
    required Constraint constraint,
  }) {
    return Constrained(
      key: key,
      constraint: constraint,
      child: this,
    );
  }

  UnConstrained applyConstraintId({
    required ConstraintId id,
  }) {
    return UnConstrained(
      key: key,
      id: id,
      child: this,
    );
  }

  /// When the layout is complex, if the child elements need to be repainted frequently, it
  /// is recommended to use RepaintBoundary to improve performance.
  RepaintBoundary offPaint() {
    return RepaintBoundary(
      key: key,
      child: this,
    );
  }

  /// If you can't declare a child element as const and it won't change, you can use OffBuildWidget
  /// to avoid the rebuilding of the child element.
  OffBuildWidget offBuild({
    required String id,
  }) {
    return OffBuildWidget(
      key: key,
      id: id,
      child: this,
    );
  }

  Widget debugWrap([Color? color]) {
    return Center(
      child: Container(
        color: color ?? Colors.black,
        child: this,
      ),
    );
  }
}

class OffBuildWidget extends StatelessWidget {
  final String id;
  final Widget child;

  const OffBuildWidget({
    Key? key,
    required this.id,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return child;
  }

  @override
  // ignore: invalid_override_of_non_virtual_member
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OffBuildWidget &&
          runtimeType == other.runtimeType &&
          id == (other).id;

  @override
  // ignore: invalid_override_of_non_virtual_member
  int get hashCode => id.hashCode;
}

bool _debugEnsureNotEmptyString(String name, String? value) {
  if (value != null && value.trim().isEmpty) {
    throw ConstraintLayoutException(
        '$name can be null, but not an empty string.');
  }
  return true;
}

bool _debugEnsurePercent(String name, double? percent) {
  if (percent == null || percent < 0 || percent > 1) {
    throw ConstraintLayoutException('$name is between [0,1].');
  }
  return true;
}

bool _debugEnsureNegativePercent(String name, double? percent) {
  if (percent == null || percent < -1 || percent > 1) {
    throw ConstraintLayoutException('$name is between [-1,1].');
  }
  return true;
}

final ConstraintId parent = ConstraintId('parent');
const double matchConstraint = -3.1415926;
const double matchParent = -2.7182818;
const double wrapContent = -0.6180339;
const CLVisibility visible = CLVisibility.visible;
const CLVisibility gone = CLVisibility.gone;
const CLVisibility invisible = CLVisibility.invisible;

enum CLVisibility {
  visible,
  gone,
  invisible,
}

enum ChainStyle {
  spread,
  spreadInside,
  packet,
}

enum BarrierDirection {
  left,
  top,
  right,
  bottom,
}

enum PercentageAnchor {
  constraint,
  parent,
}

class ConstraintId {
  String id;
  double? _leftMargin;
  double? _topMargin;
  double? _rightMargin;
  double? _bottomMargin;
  double? _leftGoneMargin;
  double? _topGoneMargin;
  double? _rightGoneMargin;
  double? _bottomGoneMargin;

  _ConstrainedNode? contextCacheNode;
  int? contextHash;

  ConstraintId(this.id);

  @protected
  ConstraintId copy() {
    return ConstraintId(id);
  }

  bool _isMarginSet() {
    return _leftMargin != null ||
        _topMargin != null ||
        _rightMargin != null ||
        _bottomMargin != null ||
        _leftGoneMargin != null ||
        _topGoneMargin != null ||
        _rightGoneMargin != null ||
        _bottomGoneMargin != null;
  }

  ConstraintId leftMargin(double margin) {
    if (_isMarginSet()) {
      _leftMargin = margin;
      return this;
    } else {
      return copy().._leftMargin = margin;
    }
  }

  ConstraintId topMargin(double margin) {
    if (_isMarginSet()) {
      _topMargin = margin;
      return this;
    } else {
      return copy().._topMargin = margin;
    }
  }

  ConstraintId rightMargin(double margin) {
    if (_isMarginSet()) {
      _rightMargin = margin;
      return this;
    } else {
      return copy().._rightMargin = margin;
    }
  }

  ConstraintId bottomMargin(double margin) {
    if (_isMarginSet()) {
      _bottomMargin = margin;
      return this;
    } else {
      return copy().._bottomMargin = margin;
    }
  }

  ConstraintId leftGoneMargin(double margin) {
    if (_isMarginSet()) {
      _leftGoneMargin = margin;
      return this;
    } else {
      return copy().._leftGoneMargin = margin;
    }
  }

  ConstraintId topGoneMargin(double margin) {
    if (_isMarginSet()) {
      _topGoneMargin = margin;
      return this;
    } else {
      return copy().._topGoneMargin = margin;
    }
  }

  ConstraintId rightGoneMargin(double margin) {
    if (_isMarginSet()) {
      _rightGoneMargin = margin;
      return this;
    } else {
      return copy().._rightGoneMargin = margin;
    }
  }

  ConstraintId bottomGoneMargin(double margin) {
    if (_isMarginSet()) {
      _bottomGoneMargin = margin;
      return this;
    } else {
      return copy().._bottomGoneMargin = margin;
    }
  }

  _ConstrainedNode? getCacheNode(int hash) {
    if (contextHash == hash) {
      return contextCacheNode!;
    }
    return null;
  }

  void setCacheNode(int hash, _ConstrainedNode node) {
    contextHash = hash;
    contextCacheNode = node;
  }

  late final _Align left = _Align(this, _AlignType.left)
    .._margin = _leftMargin
    .._goneMargin = _leftGoneMargin;

  late final _Align top = _Align(this, _AlignType.top)
    .._margin = _topMargin
    .._goneMargin = _topGoneMargin;

  late final _Align right = _Align(this, _AlignType.right)
    .._margin = _rightMargin
    .._goneMargin = _rightGoneMargin;

  late final _Align bottom = _Align(this, _AlignType.bottom)
    .._margin = _bottomMargin
    .._goneMargin = _bottomGoneMargin;

  late final _Align baseline = _Align(this, _AlignType.baseline)
    .._margin = _bottomMargin
    .._goneMargin = _bottomGoneMargin;

  late final _Align _leftReverse = _Align(this, _AlignType.left)
    .._margin = _rightMargin
    .._goneMargin = _rightGoneMargin;

  late final _Align _topReverse = _Align(this, _AlignType.top)
    .._margin = _bottomMargin
    .._goneMargin = _bottomGoneMargin;

  late final _Align _rightReverse = _Align(this, _AlignType.right)
    .._margin = _leftMargin
    .._goneMargin = _leftGoneMargin;

  late final _Align _bottomReverse = _Align(this, _AlignType.bottom)
    .._margin = _topMargin
    .._goneMargin = _topGoneMargin;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! ConstraintId) {
      return false;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return (other).id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }

  @override
  String toString() {
    return 'ConstraintId{name: $id}';
  }
}

class _IndexConstraintId extends ConstraintId {
  final int siblingIndex;

  _IndexConstraintId(this.siblingIndex)
      : super('parent.children[$siblingIndex]');

  @override
  ConstraintId copy() {
    return _IndexConstraintId(siblingIndex);
  }
}

ConstraintId rId(int childIndex) {
  assert(childIndex >= 0);
  return _IndexConstraintId(childIndex);
}

class _RelativeConstraintId extends ConstraintId {
  final int siblingIndexOffset;

  _RelativeConstraintId(this.siblingIndexOffset) : super('$siblingIndexOffset');

  @override
  ConstraintId copy() {
    return _RelativeConstraintId(siblingIndexOffset);
  }
}

ConstraintId sId(int siblingIndexOffset) {
  assert(siblingIndexOffset != 0);
  return _RelativeConstraintId(siblingIndexOffset);
}

ConstraintId cId(String id) {
  return ConstraintId(id);
}

class _Align {
  ConstraintId id;
  _AlignType type;
  double? _margin;
  double? _goneMargin;

  _Align(this.id, this.type);

  _Align margin(double margin) {
    if (_margin != null || _goneMargin != null) {
      _margin = margin;
      return this;
    } else {
      return _Align(id, type).._margin = margin;
    }
  }

  _Align goneMargin(double goneMargin) {
    if (_margin != null || _goneMargin != null) {
      _goneMargin = goneMargin;
      return this;
    } else {
      return _Align(id, type).._goneMargin = goneMargin;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Align &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type;

  @override
  int get hashCode => id.hashCode ^ type.hashCode;
}

typedef OnLayoutCallback = void Function(RenderObject renderObject, Rect rect);

class ConstraintDefine {
  final ConstraintId? id;

  ConstraintDefine(this.id)
      : assert(id is! _IndexConstraintId),
        assert(id is! _RelativeConstraintId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstraintDefine &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum PinnedType {
  absolute,
  percent,
}

class PinnedPos {
  double xOffset;
  PinnedType xType;
  double yOffset;
  PinnedType yType;

  PinnedPos(this.xOffset, this.xType, this.yOffset, this.yType);

  void checkBounds(double value, PinnedType pinnedType, double base) {
    if (pinnedType == PinnedType.absolute) {
      assert(value >= 0 && value <= base);
    } else {
      assert(value >= 0 && value <= 1);
    }
  }

  Offset resolve(Size size) {
    assert(() {
      checkBounds(xOffset, xType, size.width);
      checkBounds(yOffset, yType, size.height);
      return true;
    }());
    double x;
    double y;
    if (xType == PinnedType.absolute) {
      x = xOffset;
    } else {
      x = xOffset * size.width;
    }
    if (yType == PinnedType.absolute) {
      y = yOffset;
    } else {
      y = yOffset * size.height;
    }
    return Offset(x, y);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PinnedPos &&
          runtimeType == other.runtimeType &&
          xOffset == other.xOffset &&
          xType == other.xType &&
          yOffset == other.yOffset &&
          yType == other.yType;

  @override
  int get hashCode =>
      xOffset.hashCode ^ xType.hashCode ^ yOffset.hashCode ^ yType.hashCode;
}

class PinnedInfo {
  /// [0,360]
  int rotateDegree;
  ConstraintId anchorId;
  PinnedPos selfPos;
  PinnedPos targetPos;

  PinnedInfo(
    this.anchorId,
    this.selfPos,
    this.targetPos, {
    this.rotateDegree = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PinnedInfo &&
          runtimeType == other.runtimeType &&
          rotateDegree == other.rotateDegree &&
          anchorId == other.anchorId &&
          selfPos == other.selfPos &&
          targetPos == other.targetPos;

  @override
  int get hashCode =>
      rotateDegree.hashCode ^
      anchorId.hashCode ^
      selfPos.hashCode ^
      targetPos.hashCode;
}

class ConstraintVersion {
  int _constraintsVersion = 1;
  int _layoutVersion = 1;
  int _paintVersion = 1;
  int _paintingOrderVersion = 1;
  int _eventOrderVersion = 1;

  ConstraintVersion incConstraintsVersion() {
    _constraintsVersion++;
    return this;
  }

  ConstraintVersion incLayoutVersion() {
    _layoutVersion++;
    return this;
  }

  ConstraintVersion incPaintVersion() {
    _paintVersion++;
    return this;
  }

  ConstraintVersion incPaintingOrderVersion() {
    _paintingOrderVersion++;
    _eventOrderVersion++;
    return this;
  }

  ConstraintVersion incEventOrderVersion() {
    _eventOrderVersion++;
    return this;
  }

  ConstraintVersion copy() {
    return ConstraintVersion()
      .._constraintsVersion = _constraintsVersion
      .._layoutVersion = _layoutVersion
      .._paintVersion = _paintVersion
      .._paintingOrderVersion = _paintingOrderVersion
      .._eventOrderVersion = _eventOrderVersion;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstraintVersion &&
          runtimeType == other.runtimeType &&
          _constraintsVersion == other._constraintsVersion &&
          _layoutVersion == other._layoutVersion &&
          _paintVersion == other._paintVersion &&
          _paintingOrderVersion == other._paintingOrderVersion &&
          _eventOrderVersion == other._eventOrderVersion;

  @override
  int get hashCode =>
      _constraintsVersion.hashCode ^
      _layoutVersion.hashCode ^
      _paintVersion.hashCode ^
      _paintingOrderVersion.hashCode ^
      _eventOrderVersion.hashCode;
}

class Constraint extends ConstraintDefine {
  /// 'wrap_content'、'match_parent'、'match_constraint'、'48, etc'
  /// 'match_parent' will be converted to the base constraints
  final double width;
  final double height;

  /// When size is non-null, both width and height are set to size
  final double? size;

  /// Expand the click area without changing the actual size
  final EdgeInsets clickPadding;

  final CLVisibility visibility;

  /// Both margin and goneMargin can be negative
  final bool percentageMargin;
  final EdgeInsets margin;
  final EdgeInsets goneMargin;

  /// These are the base constraints constraint on sibling id or parent
  /// The essence of constraints is alignment
  @_baseConstraint
  _Align? left;
  @_baseConstraint
  _Align? top;
  @_baseConstraint
  _Align? right;
  @_baseConstraint
  _Align? bottom;
  @_baseConstraint
  _Align? baseline;

  /// When setting baseline alignment, height must be wrap_content or fixed size, other vertical constraints will be illegal.
  /// Warning: Due to a bug in the flutter framework, baseline alignment may not take effect in debug mode
  /// See https:///github.com/flutter/flutter/issues/101179

  final TextBaseline textBaseline;
  final int? zIndex;
  final Offset translate;

  /// When translate, whether to translate elements that depend on itself
  final bool translateConstraint;

  /// Only takes effect when width is matchConstraint
  final double widthPercent;

  /// Only takes effect when height is matchConstraint
  final double heightPercent;

  final PercentageAnchor widthPercentageAnchor;

  final PercentageAnchor heightPercentageAnchor;

  /// Only takes effect if both left and right constraints exist
  final double horizontalBias;

  /// Only takes effect if both top and bottom constraints exist
  final double verticalBias;

  /// These are wrapper constraints for simplicity of use, which will eventually convert to base constraints.
  @_wrapperConstraint
  final ConstraintId? topLeftTo;
  @_wrapperConstraint
  final ConstraintId? topCenterTo;
  @_wrapperConstraint
  final ConstraintId? topRightTo;
  @_wrapperConstraint
  final ConstraintId? centerLeftTo;
  @_wrapperConstraint
  final ConstraintId? centerTo;
  @_wrapperConstraint
  final ConstraintId? centerRightTo;
  @_wrapperConstraint
  final ConstraintId? bottomLeftTo;
  @_wrapperConstraint
  final ConstraintId? bottomCenterTo;
  @_wrapperConstraint
  final ConstraintId? bottomRightTo;
  @_wrapperConstraint
  final ConstraintId? centerHorizontalTo;
  @_wrapperConstraint
  final ConstraintId? centerVerticalTo;
  @_wrapperConstraint
  final ConstraintId? outTopLeftTo;
  @_wrapperConstraint
  final ConstraintId? outTopCenterTo;
  @_wrapperConstraint
  final ConstraintId? outTopRightTo;
  @_wrapperConstraint
  final ConstraintId? outCenterLeftTo;
  @_wrapperConstraint
  final ConstraintId? outCenterRightTo;
  @_wrapperConstraint
  final ConstraintId? outBottomLeftTo;
  @_wrapperConstraint
  final ConstraintId? outBottomCenterTo;
  @_wrapperConstraint
  final ConstraintId? outBottomRightTo;
  @_wrapperConstraint
  final ConstraintId? centerTopLeftTo;
  @_wrapperConstraint
  final ConstraintId? centerTopCenterTo;
  @_wrapperConstraint
  final ConstraintId? centerTopRightTo;
  @_wrapperConstraint
  final ConstraintId? centerCenterLeftTo;
  @_wrapperConstraint
  final ConstraintId? centerCenterRightTo;
  @_wrapperConstraint
  final ConstraintId? centerBottomLeftTo;
  @_wrapperConstraint
  final ConstraintId? centerBottomCenterTo;
  @_wrapperConstraint
  final ConstraintId? centerBottomRightTo;

  final OnLayoutCallback? callback;
  final double chainWeight;
  final bool percentageTranslate;

  /// Only takes effect when width is wrapContent
  final double minWidth;
  final double maxWidth;

  /// Only takes effect when height is wrapContent
  final double minHeight;
  final double maxHeight;

  /// Only takes effect if the size of one side is matchConstraint and the size of the other side can be
  /// inferred (fixed size, matchParent, matchConstraint with two constraints)
  final double? widthHeightRatio;

  /// By default, ConstraintLayout will automatically decide which side to base on and
  /// calculate the size of the other side based on widthHeightRatio. But if both sides
  /// are matchConstraint, it cannot be determined automatically. At this point, you need
  /// to specify the ratioBaseOnWidth parameter. The default value of null means automatically decide
  final bool? ratioBaseOnWidth;

  final int? eIndex;

  final PinnedInfo? pinnedInfo;

  Constraint({
    ConstraintId? id,
    this.width = wrapContent,
    this.height = wrapContent,
    this.size,
    @_baseConstraint this.left,
    @_baseConstraint this.top,
    @_baseConstraint this.right,
    @_baseConstraint this.bottom,
    @_baseConstraint this.baseline,
    this.clickPadding = EdgeInsets.zero,
    this.visibility = visible,
    this.percentageMargin = false,
    this.margin = EdgeInsets.zero,
    this.goneMargin = EdgeInsets.zero,
    this.textBaseline = TextBaseline.alphabetic,
    this.zIndex, // default is child index
    this.translate = Offset.zero,
    this.translateConstraint = false,
    this.widthPercent = 1,
    this.heightPercent = 1,
    this.widthPercentageAnchor = PercentageAnchor.constraint,
    this.heightPercentageAnchor = PercentageAnchor.constraint,
    this.horizontalBias = 0.5,
    this.verticalBias = 0.5,
    @_wrapperConstraint this.topLeftTo,
    @_wrapperConstraint this.topCenterTo,
    @_wrapperConstraint this.topRightTo,
    @_wrapperConstraint this.centerLeftTo,
    @_wrapperConstraint this.centerTo,
    @_wrapperConstraint this.centerRightTo,
    @_wrapperConstraint this.bottomLeftTo,
    @_wrapperConstraint this.bottomCenterTo,
    @_wrapperConstraint this.bottomRightTo,
    @_wrapperConstraint this.centerHorizontalTo,
    @_wrapperConstraint this.centerVerticalTo,
    @_wrapperConstraint this.outTopLeftTo,
    @_wrapperConstraint this.outTopCenterTo,
    @_wrapperConstraint this.outTopRightTo,
    @_wrapperConstraint this.outCenterLeftTo,
    @_wrapperConstraint this.outCenterRightTo,
    @_wrapperConstraint this.outBottomLeftTo,
    @_wrapperConstraint this.outBottomCenterTo,
    @_wrapperConstraint this.outBottomRightTo,
    @_wrapperConstraint this.centerTopLeftTo,
    @_wrapperConstraint this.centerTopCenterTo,
    @_wrapperConstraint this.centerTopRightTo,
    @_wrapperConstraint this.centerCenterLeftTo,
    @_wrapperConstraint this.centerCenterRightTo,
    @_wrapperConstraint this.centerBottomLeftTo,
    @_wrapperConstraint this.centerBottomCenterTo,
    @_wrapperConstraint this.centerBottomRightTo,
    this.callback,
    this.chainWeight = 1,
    this.percentageTranslate = false,
    this.minWidth = 0,
    this.maxWidth = matchParent,
    this.minHeight = 0,
    this.maxHeight = matchParent,
    this.widthHeightRatio,
    this.ratioBaseOnWidth,
    this.eIndex,
    this.pinnedInfo,
  }) : super(id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is Constraint &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height &&
          size == other.size &&
          clickPadding == other.clickPadding &&
          visibility == other.visibility &&
          percentageMargin == other.percentageMargin &&
          margin == other.margin &&
          goneMargin == other.goneMargin &&
          left == other.left &&
          top == other.top &&
          right == other.right &&
          bottom == other.bottom &&
          baseline == other.baseline &&
          textBaseline == other.textBaseline &&
          zIndex == other.zIndex &&
          translate == other.translate &&
          translateConstraint == other.translateConstraint &&
          widthPercent == other.widthPercent &&
          heightPercent == other.heightPercent &&
          widthPercentageAnchor == other.widthPercentageAnchor &&
          heightPercentageAnchor == other.heightPercentageAnchor &&
          horizontalBias == other.horizontalBias &&
          verticalBias == other.verticalBias &&
          topLeftTo == other.topLeftTo &&
          topCenterTo == other.topCenterTo &&
          topRightTo == other.topRightTo &&
          centerLeftTo == other.centerLeftTo &&
          centerTo == other.centerTo &&
          centerRightTo == other.centerRightTo &&
          bottomLeftTo == other.bottomLeftTo &&
          bottomCenterTo == other.bottomCenterTo &&
          bottomRightTo == other.bottomRightTo &&
          centerHorizontalTo == other.centerHorizontalTo &&
          centerVerticalTo == other.centerVerticalTo &&
          outTopLeftTo == other.outTopLeftTo &&
          outTopCenterTo == other.outTopCenterTo &&
          outTopRightTo == other.outTopRightTo &&
          outCenterLeftTo == other.outCenterLeftTo &&
          outCenterRightTo == other.outCenterRightTo &&
          outBottomLeftTo == other.outBottomLeftTo &&
          outBottomCenterTo == other.outBottomCenterTo &&
          outBottomRightTo == other.outBottomRightTo &&
          centerTopLeftTo == other.centerTopLeftTo &&
          centerTopCenterTo == other.centerTopCenterTo &&
          centerTopRightTo == other.centerTopRightTo &&
          centerCenterLeftTo == other.centerCenterLeftTo &&
          centerCenterRightTo == other.centerCenterRightTo &&
          centerBottomLeftTo == other.centerBottomLeftTo &&
          centerBottomCenterTo == other.centerBottomCenterTo &&
          centerBottomRightTo == other.centerBottomRightTo &&
          callback == other.callback &&
          percentageTranslate == other.percentageTranslate &&
          minWidth == other.minWidth &&
          maxWidth == other.maxWidth &&
          minHeight == other.minHeight &&
          maxHeight == other.maxHeight &&
          widthHeightRatio == other.widthHeightRatio &&
          ratioBaseOnWidth == other.ratioBaseOnWidth &&
          eIndex == other.eIndex &&
          pinnedInfo == other.pinnedInfo;

  @override
  int get hashCode =>
      super.hashCode ^
      width.hashCode ^
      height.hashCode ^
      size.hashCode ^
      clickPadding.hashCode ^
      visibility.hashCode ^
      percentageMargin.hashCode ^
      margin.hashCode ^
      goneMargin.hashCode ^
      left.hashCode ^
      top.hashCode ^
      right.hashCode ^
      bottom.hashCode ^
      baseline.hashCode ^
      textBaseline.hashCode ^
      zIndex.hashCode ^
      translate.hashCode ^
      translateConstraint.hashCode ^
      widthPercent.hashCode ^
      heightPercent.hashCode ^
      widthPercentageAnchor.hashCode ^
      heightPercentageAnchor.hashCode ^
      horizontalBias.hashCode ^
      verticalBias.hashCode ^
      topLeftTo.hashCode ^
      topCenterTo.hashCode ^
      topRightTo.hashCode ^
      centerLeftTo.hashCode ^
      centerTo.hashCode ^
      centerRightTo.hashCode ^
      bottomLeftTo.hashCode ^
      bottomCenterTo.hashCode ^
      bottomRightTo.hashCode ^
      centerHorizontalTo.hashCode ^
      centerVerticalTo.hashCode ^
      outTopLeftTo.hashCode ^
      outTopCenterTo.hashCode ^
      outTopRightTo.hashCode ^
      outCenterLeftTo.hashCode ^
      outCenterRightTo.hashCode ^
      outBottomLeftTo.hashCode ^
      outBottomCenterTo.hashCode ^
      outBottomRightTo.hashCode ^
      centerTopLeftTo.hashCode ^
      centerTopCenterTo.hashCode ^
      centerTopRightTo.hashCode ^
      centerCenterLeftTo.hashCode ^
      centerCenterRightTo.hashCode ^
      centerBottomLeftTo.hashCode ^
      centerBottomCenterTo.hashCode ^
      centerBottomRightTo.hashCode ^
      callback.hashCode ^
      percentageTranslate.hashCode ^
      minWidth.hashCode ^
      maxWidth.hashCode ^
      minHeight.hashCode ^
      maxHeight.hashCode ^
      widthHeightRatio.hashCode ^
      ratioBaseOnWidth.hashCode ^
      eIndex.hashCode ^
      pinnedInfo.hashCode;

  bool checkSize(double size) {
    if (size == matchParent || size == wrapContent || size == matchConstraint) {
      return true;
    } else {
      if (size == double.infinity || size < 0) {
        throw ConstraintLayoutException(
            'width or height can not be infinity or negative.');
      }
      return true;
    }
  }

  bool validate() {
    assert(checkSize(width));
    assert(checkSize(height));
    assert(size == null || checkSize(size!));
    assert(left == null ||
        (left!.type == _AlignType.left || left!.type == _AlignType.right));
    assert(top == null ||
        (top!.type == _AlignType.top || top!.type == _AlignType.bottom));
    assert(right == null ||
        (right!.type == _AlignType.left || right!.type == _AlignType.right));
    assert(bottom == null ||
        (bottom!.type == _AlignType.top || bottom!.type == _AlignType.bottom));
    assert(baseline == null ||
        (baseline!.type == _AlignType.top ||
            baseline!.type == _AlignType.bottom ||
            baseline!.type == _AlignType.baseline));
    assert(_debugEnsurePercent('widthPercent', widthPercent));
    assert(_debugEnsurePercent('heightPercent', heightPercent));
    assert(_debugEnsurePercent('horizontalBias', horizontalBias));
    assert(_debugEnsurePercent('verticalBias', verticalBias));
    assert(!percentageMargin ||
        _debugEnsureNegativePercent('leftMargin', margin.left));
    assert(!percentageMargin ||
        _debugEnsureNegativePercent('topMargin', margin.top));
    assert(!percentageMargin ||
        _debugEnsureNegativePercent('rightMargin', margin.right));
    assert(!percentageMargin ||
        _debugEnsureNegativePercent('bottomMargin', margin.bottom));
    assert(!percentageMargin ||
        _debugEnsureNegativePercent('leftGoneMargin', goneMargin.left));
    assert(!percentageMargin ||
        _debugEnsureNegativePercent('topGoneMargin', goneMargin.top));
    assert(!percentageMargin ||
        _debugEnsureNegativePercent('rightGoneMargin', goneMargin.right));
    assert(!percentageMargin ||
        _debugEnsureNegativePercent('bottomGoneMargin', goneMargin.bottom));
    assert(!percentageTranslate ||
        _debugEnsureNegativePercent('xTranslate', translate.dx));
    assert(!percentageTranslate ||
        _debugEnsureNegativePercent('yTranslate', translate.dy));
    assert(minWidth >= 0);
    assert(maxWidth == matchParent || maxWidth >= minWidth);
    assert(minHeight >= 0);
    assert(maxHeight == matchParent || maxHeight >= minHeight);
    assert(widthHeightRatio == null || widthHeightRatio! > 0);
    return true;
  }

  static int getMinimalConstraintCount(double size) {
    if (size == matchParent) {
      return 0;
    } else if (size == wrapContent || size >= 0) {
      return 1;
    } else {
      return 2;
    }
  }

  void applyTo(RenderObject renderObject) {
    _Align? left = this.left;
    _Align? top = this.top;
    _Align? right = this.right;
    _Align? bottom = this.bottom;
    _Align? baseline = this.baseline;

    double width = this.width;
    double height = this.height;
    if (size != null) {
      width = size!;
      height = size!;
    }

    /// Convert wrapper constraints first

    if (topLeftTo != null) {
      left = topLeftTo!.left;
      top = topLeftTo!.top;
    }

    if (topCenterTo != null) {
      left = topCenterTo!.left;
      right = topCenterTo!.right;
      top = topCenterTo!.top;
    }

    if (topRightTo != null) {
      top = topRightTo!.top;
      right = topRightTo!.right;
    }

    if (centerLeftTo != null) {
      left = centerLeftTo!.left;
      top = centerLeftTo!.top;
      bottom = centerLeftTo!.bottom;
    }

    if (centerTo != null) {
      left = centerTo!.left;
      right = centerTo!.right;
      top = centerTo!.top;
      bottom = centerTo!.bottom;
    }

    if (centerRightTo != null) {
      right = centerRightTo!.right;
      top = centerRightTo!.top;
      bottom = centerRightTo!.bottom;
    }

    if (bottomLeftTo != null) {
      left = bottomLeftTo!.left;
      bottom = bottomLeftTo!.bottom;
    }

    if (bottomCenterTo != null) {
      left = bottomCenterTo!.left;
      right = bottomCenterTo!.right;
      bottom = bottomCenterTo!.bottom;
    }

    if (bottomRightTo != null) {
      right = bottomRightTo!.right;
      bottom = bottomRightTo!.bottom;
    }

    if (centerHorizontalTo != null) {
      left = centerHorizontalTo!.left;
      right = centerHorizontalTo!.right;
    }

    if (centerVerticalTo != null) {
      top = centerVerticalTo!.top;
      bottom = centerVerticalTo!.bottom;
    }

    if (outTopLeftTo != null) {
      right = outTopLeftTo!._leftReverse;
      bottom = outTopLeftTo!._topReverse;
    }

    if (outTopCenterTo != null) {
      left = outTopCenterTo!.left;
      right = outTopCenterTo!.right;
      bottom = outTopCenterTo!._topReverse;
    }

    if (outTopRightTo != null) {
      left = outTopRightTo!._rightReverse;
      bottom = outTopRightTo!._topReverse;
    }

    if (outCenterLeftTo != null) {
      top = outCenterLeftTo!.top;
      bottom = outCenterLeftTo!.bottom;
      right = outCenterLeftTo!._leftReverse;
    }

    if (outCenterRightTo != null) {
      top = outCenterRightTo!.top;
      bottom = outCenterRightTo!.bottom;
      left = outCenterRightTo!._rightReverse;
    }

    if (outBottomLeftTo != null) {
      right = outBottomLeftTo!._leftReverse;
      top = outBottomLeftTo!._bottomReverse;
    }

    if (outBottomCenterTo != null) {
      left = outBottomCenterTo!.left;
      right = outBottomCenterTo!.right;
      top = outBottomCenterTo!._bottomReverse;
    }

    if (outBottomRightTo != null) {
      left = outBottomRightTo!._rightReverse;
      top = outBottomRightTo!._bottomReverse;
    }

    if (centerTopLeftTo != null) {
      left = centerTopLeftTo!.left;
      right = centerTopLeftTo!._leftReverse;
      top = centerTopLeftTo!.top;
      bottom = centerTopLeftTo!._topReverse;
    }

    if (centerTopCenterTo != null) {
      left = centerTopCenterTo!.left;
      right = centerTopCenterTo!.right;
      top = centerTopCenterTo!.top;
      bottom = centerTopCenterTo!._topReverse;
    }

    if (centerTopRightTo != null) {
      left = centerTopRightTo!._rightReverse;
      right = centerTopRightTo!.right;
      top = centerTopRightTo!.top;
      bottom = centerTopRightTo!._topReverse;
    }

    if (centerCenterLeftTo != null) {
      left = centerCenterLeftTo!.left;
      right = centerCenterLeftTo!._leftReverse;
      top = centerCenterLeftTo!.top;
      bottom = centerCenterLeftTo!.bottom;
    }

    if (centerCenterRightTo != null) {
      left = centerCenterRightTo!._rightReverse;
      right = centerCenterRightTo!.right;
      top = centerCenterRightTo!.top;
      bottom = centerCenterRightTo!.bottom;
    }

    if (centerBottomLeftTo != null) {
      left = centerBottomLeftTo!.left;
      right = centerBottomLeftTo!._leftReverse;
      top = centerBottomLeftTo!._bottomReverse;
      bottom = centerBottomLeftTo!.bottom;
    }

    if (centerBottomCenterTo != null) {
      left = centerBottomCenterTo!.left;
      right = centerBottomCenterTo!.right;
      top = centerBottomCenterTo!._bottomReverse;
      bottom = centerBottomCenterTo!.bottom;
    }

    if (centerBottomRightTo != null) {
      left = centerBottomRightTo!._rightReverse;
      right = centerBottomRightTo!.right;
      top = centerBottomRightTo!._bottomReverse;
      bottom = centerBottomRightTo!.bottom;
    }

    EdgeInsets margin = this.margin;
    EdgeInsets goneMargin = this.goneMargin;

    if (left != null) {
      if (left._margin != null) {
        margin = margin.add(EdgeInsets.only(
          left: left._margin!,
        )) as EdgeInsets;
      }
      if (left._goneMargin != null) {
        goneMargin = goneMargin.add(EdgeInsets.only(
          left: left._goneMargin!,
        )) as EdgeInsets;
      }
    }

    if (top != null) {
      if (top._margin != null) {
        margin = margin.add(EdgeInsets.only(
          top: top._margin!,
        )) as EdgeInsets;
      }
      if (top._goneMargin != null) {
        goneMargin = goneMargin.add(EdgeInsets.only(
          top: top._goneMargin!,
        )) as EdgeInsets;
      }
    }

    if (right != null) {
      if (right._margin != null) {
        margin = margin.add(EdgeInsets.only(
          right: right._margin!,
        )) as EdgeInsets;
      }
      if (right._goneMargin != null) {
        goneMargin = goneMargin.add(EdgeInsets.only(
          right: right._goneMargin!,
        )) as EdgeInsets;
      }
    }

    if (bottom != null) {
      if (bottom._margin != null) {
        margin = margin.add(EdgeInsets.only(
          bottom: bottom._margin!,
        )) as EdgeInsets;
      }
      if (bottom._goneMargin != null) {
        goneMargin = goneMargin.add(EdgeInsets.only(
          bottom: bottom._goneMargin!,
        )) as EdgeInsets;
      }
    }

    if (baseline != null) {
      if (baseline._margin != null) {
        margin = margin.add(EdgeInsets.only(
          bottom: baseline._margin!,
        )) as EdgeInsets;
      }
      if (baseline._goneMargin != null) {
        goneMargin = goneMargin.add(EdgeInsets.only(
          bottom: baseline._goneMargin!,
        )) as EdgeInsets;
      }
    }

    /// Convert wrapper constraints finish

    /// Constraint priority: matchParent > wrapper constraints > base constraints
    if (width == matchParent) {
      assert(() {
        if (left != null || right != null) {
          throw ConstraintLayoutException(
              'When setting the width to match_parent for child with id $id, there is no need to set left or right constraint.');
        }
        return true;
      }());
      left = parent.left;
      right = parent.right;
    }

    if (height == matchParent) {
      assert(() {
        if (top != null || bottom != null || baseline != null) {
          throw ConstraintLayoutException(
              'When setting the height to match_parent for child with id $id, there is no need to set top or bottom or baseline constraint.');
        }
        return true;
      }());
      top = parent.top;
      bottom = parent.bottom;
      baseline = null;
    }

    _ConstraintBoxData parentData =
        renderObject.parentData! as _ConstraintBoxData;
    parentData.clickPadding = clickPadding;
    parentData.callback = callback;

    if ((renderObject.parent as _ConstraintRenderBox)._constraintVersion !=
        null) {
      parentData.id = id;
      parentData.width = width;
      parentData.height = height;
      parentData.visibility = visibility;
      parentData.percentageMargin = percentageMargin;
      parentData.margin = margin;
      parentData.goneMargin = goneMargin;
      parentData.left = left;
      parentData.right = right;
      parentData.top = top;
      parentData.bottom = bottom;
      parentData.baseline = baseline;
      parentData.textBaseline = textBaseline;
      parentData.zIndex = zIndex;
      parentData.translateConstraint = translateConstraint;
      parentData.translate = translate;
      parentData.widthPercent = widthPercent;
      parentData.heightPercent = heightPercent;
      parentData.widthPercentageAnchor = widthPercentageAnchor;
      parentData.heightPercentageAnchor = heightPercentageAnchor;
      parentData.horizontalBias = horizontalBias;
      parentData.verticalBias = verticalBias;
      parentData.percentageTranslate = percentageTranslate;
      parentData.minWidth = minWidth;
      parentData.maxWidth = maxWidth;
      parentData.minHeight = minHeight;
      parentData.maxHeight = maxHeight;
      parentData.widthHeightRatio = widthHeightRatio;
      parentData.ratioBaseOnWidth = ratioBaseOnWidth;
      parentData.eIndex = eIndex;
      parentData.pinnedInfo = pinnedInfo;
      return;
    }

    bool needsLayout = false;
    bool needsPaint = false;
    bool needsReorderPaintingOrder = false;
    bool needsReorderEventOrder = false;
    bool needsRecalculateConstraints = false;

    if (parentData.id != id) {
      parentData.id = id;
      needsRecalculateConstraints = true;
      needsLayout = true;
    }

    if (parentData.width != width) {
      needsRecalculateConstraints = true;
      if (parentData.width != null) {
        if (getMinimalConstraintCount(parentData.width!) ==
            getMinimalConstraintCount(width)) {
          needsRecalculateConstraints = false;
        }
      }
      parentData.width = width;
      needsLayout = true;
    }

    if (parentData.height != height) {
      needsRecalculateConstraints = true;
      if (parentData.height != null) {
        if (getMinimalConstraintCount(parentData.height!) ==
            getMinimalConstraintCount(height)) {
          needsRecalculateConstraints = false;
        }
      }
      parentData.height = height;
      needsLayout = true;
    }

    if (parentData.visibility != visibility) {
      if (parentData.visibility == gone || visibility == gone) {
        needsLayout = true;
      } else {
        needsPaint = true;
      }
      parentData.visibility = visibility;
    }

    if (parentData.percentageMargin != percentageMargin) {
      parentData.percentageMargin = percentageMargin;
      needsLayout = true;
    }

    if (parentData.margin != margin) {
      parentData.margin = margin;
      needsLayout = true;
    }

    if (parentData.goneMargin != goneMargin) {
      parentData.goneMargin = goneMargin;
      needsLayout = true;
    }

    if (parentData.left != left) {
      parentData.left = left;
      needsRecalculateConstraints = true;
      needsLayout = true;
    }

    if (parentData.right != right) {
      parentData.right = right;
      needsRecalculateConstraints = true;
      needsLayout = true;
    }

    if (parentData.top != top) {
      parentData.top = top;
      needsRecalculateConstraints = true;
      needsLayout = true;
    }

    if (parentData.bottom != bottom) {
      parentData.bottom = bottom;
      needsRecalculateConstraints = true;
      needsLayout = true;
    }

    if (parentData.baseline != baseline) {
      parentData.baseline = baseline;
      needsRecalculateConstraints = true;
      needsLayout = true;
    }

    if (parentData.textBaseline != textBaseline) {
      parentData.textBaseline = textBaseline;
      needsLayout = true;
    }

    if (parentData.zIndex != zIndex) {
      parentData.zIndex = zIndex;
      needsReorderPaintingOrder = true;
      needsReorderEventOrder = true;
      needsPaint = true;
    }

    if (parentData.translateConstraint != translateConstraint) {
      parentData.translateConstraint = translateConstraint;
      needsLayout = true;
    }

    if (parentData.translate != translate) {
      parentData.translate = translate;
      if (translateConstraint) {
        needsLayout = true;
      } else {
        needsPaint = true;
      }
    }

    if (parentData.widthPercent != widthPercent) {
      parentData.widthPercent = widthPercent;
      needsLayout = true;
    }

    if (parentData.heightPercent != heightPercent) {
      parentData.heightPercent = heightPercent;
      needsLayout = true;
    }

    if (parentData.widthPercentageAnchor != widthPercentageAnchor) {
      parentData.widthPercentageAnchor = widthPercentageAnchor;
      needsLayout = true;
    }

    if (parentData.heightPercentageAnchor != heightPercentageAnchor) {
      parentData.heightPercentageAnchor = heightPercentageAnchor;
      needsLayout = true;
    }

    if (parentData.horizontalBias != horizontalBias) {
      parentData.horizontalBias = horizontalBias;
      needsLayout = true;
    }

    if (parentData.verticalBias != verticalBias) {
      parentData.verticalBias = verticalBias;
      needsLayout = true;
    }

    if (parentData.percentageTranslate != percentageTranslate) {
      parentData.percentageTranslate = percentageTranslate;
      needsPaint = true;
    }

    if (parentData.minWidth != minWidth) {
      parentData.minWidth = minWidth;
      needsLayout = true;
    }

    if (parentData.maxWidth != maxWidth) {
      parentData.maxWidth = maxWidth;
      needsLayout = true;
    }

    if (parentData.minHeight != minHeight) {
      parentData.minHeight = minHeight;
      needsLayout = true;
    }

    if (parentData.maxHeight != maxHeight) {
      parentData.maxHeight = maxHeight;
      needsLayout = true;
    }

    if (parentData.widthHeightRatio != widthHeightRatio) {
      parentData.widthHeightRatio = widthHeightRatio;
      needsLayout = true;
    }

    if (parentData.ratioBaseOnWidth != ratioBaseOnWidth) {
      parentData.ratioBaseOnWidth = ratioBaseOnWidth;
      needsLayout = true;
    }

    if (parentData.eIndex != eIndex) {
      parentData.eIndex = eIndex;
      needsReorderEventOrder = true;
    }

    if (parentData.pinnedInfo != pinnedInfo) {
      if (parentData.pinnedInfo == null || pinnedInfo == null) {
        needsRecalculateConstraints = true;
        needsLayout = true;
      } else {
        if (parentData.pinnedInfo!.anchorId != pinnedInfo!.anchorId) {
          needsRecalculateConstraints = true;
          needsLayout = true;
        } else if (parentData.pinnedInfo!.selfPos != pinnedInfo!.selfPos ||
            parentData.pinnedInfo!.targetPos != pinnedInfo!.targetPos) {
          needsLayout = true;
        } else if (parentData.pinnedInfo!.rotateDegree !=
            pinnedInfo!.rotateDegree) {
          needsPaint = true;
        }
      }
      parentData.pinnedInfo = pinnedInfo;
    }

    if (needsLayout) {
      AbstractNode? targetParent = renderObject.parent;
      if (needsRecalculateConstraints) {
        if (targetParent is _ConstraintRenderBox) {
          targetParent.markNeedsRecalculateConstraints();
        }
      }
      if (targetParent is RenderObject) {
        targetParent.markNeedsLayout();
      }
    } else {
      if (needsReorderPaintingOrder) {
        AbstractNode? targetParent = renderObject.parent;
        if (targetParent is _ConstraintRenderBox) {
          targetParent.needsReorderPaintingOrder = true;
        }
      }
      if (needsReorderEventOrder) {
        AbstractNode? targetParent = renderObject.parent;
        if (targetParent is _ConstraintRenderBox) {
          targetParent.needsReorderEventOrder = true;
        }
      }
      if (needsPaint) {
        AbstractNode? targetParent = renderObject.parent;
        if (targetParent is RenderObject) {
          targetParent.markNeedsPaint();
        }
      }
    }
  }
}

enum _AlignType {
  left,
  right,
  top,
  bottom,
  baseline,
}

class _ConstraintBoxData extends ContainerBoxParentData<RenderBox> {
  ConstraintId? id;
  double? width;
  double? height;
  EdgeInsets? clickPadding;
  CLVisibility? visibility;
  bool? percentageMargin;
  EdgeInsets? margin;
  EdgeInsets? goneMargin;
  _Align? left;
  _Align? top;
  _Align? right;
  _Align? bottom;
  _Align? baseline;
  TextBaseline? textBaseline;
  int? zIndex;
  Offset? translate;
  bool? translateConstraint;
  double? widthPercent;
  double? heightPercent;
  PercentageAnchor? widthPercentageAnchor;
  PercentageAnchor? heightPercentageAnchor;
  double? horizontalBias;
  double? verticalBias;
  OnLayoutCallback? callback;
  bool? percentageTranslate;
  double? minWidth;
  double? maxWidth;
  double? minHeight;
  double? maxHeight;
  double? widthHeightRatio;
  bool? ratioBaseOnWidth;
  int? eIndex;
  PinnedInfo? pinnedInfo;

  // for internal use
  late Map<ConstraintId, _ConstrainedNode> _constrainedNodeMap;
  BarrierDirection? _direction;
  List<ConstraintId>? _referencedIds;
  bool _isGuideline = false;
  bool _isBarrier = false;
  Size? _helperSize;
}

class Constrained extends ParentDataWidget<_ConstraintBoxData> {
  final Constraint constraint;

  const Constrained({
    Key? key,
    required Widget child,
    required this.constraint,
  })  : assert(child is! Constrained,
            'Constrained can not be wrapped with Constrained.'),
        assert(child is! UnConstrained,
            'UnConstrained can not be wrapped with Constrained.'),
        assert(child is! Guideline,
            'Guideline can not be wrapped with Constrained.'),
        assert(
            child is! Barrier, 'Barrier can not be wrapped with Constrained.'),
        super(
          key: key,
          child: child,
        );

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parent is _ConstraintRenderBox);
    assert(constraint.validate());
    constraint.applyTo(renderObject);
  }

  @override
  Type get debugTypicalAncestorWidgetClass {
    return ConstraintLayout;
  }
}

class UnConstrained extends ParentDataWidget<_ConstraintBoxData> {
  final ConstraintId id;

  const UnConstrained({
    Key? key,
    required this.id,
    required Widget child,
  })  : assert(child is! UnConstrained,
            'UnConstrained can not be wrapped with UnConstrained.'),
        assert(child is! Constrained,
            'Constrained can not be wrapped with UnConstrained.'),
        assert(child is! Guideline,
            'Guideline can not be wrapped with UnConstrained.'),
        assert(child is! Barrier,
            'Barrier can not be wrapped with UnConstrained.'),
        super(
          key: key,
          child: child,
        );

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parent is _ConstraintRenderBox);
    List<ConstraintDefine>? childConstraints =
        (renderObject.parent as _ConstraintRenderBox)._childConstraints;
    assert(childConstraints != null,
        'Can not find Constraint for child with id $id.');
    Iterable<ConstraintDefine> constraintIterable =
        childConstraints!.where((element) => element.id == id);
    assert(constraintIterable.isNotEmpty,
        'Can not find Constraint for child with id $id.');
    assert(constraintIterable.length == 1, 'Duplicate id in childConstraints.');
    assert(constraintIterable.first is Constraint);
    Constraint constraint = constraintIterable.first as Constraint;
    assert(constraint.validate());
    constraint.applyTo(renderObject);
  }

  @override
  Type get debugTypicalAncestorWidgetClass {
    return ConstraintLayout;
  }
}

class _ConstraintRenderBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ConstraintBoxData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ConstraintBoxData> {
  List<ConstraintDefine>? _childConstraints;
  late bool _debugShowGuideline;
  late bool _debugShowClickArea;
  late bool _debugPrintConstraints;
  late bool _debugPrintLayoutTime;
  late bool _debugCheckConstraints;
  late bool _releasePrintLayoutTime;
  String? _debugName;
  late bool _debugShowZIndex;
  late bool _debugShowChildDepth;

  late double _width;
  late double _height;
  ConstraintVersion? _constraintVersion;

  bool _needsRecalculateConstraints = true;
  bool _needsReorderPaintingOrder = true;
  bool _needsReorderEventOrder = true;
  int _buildNodeTreesCount = 0;
  final Map<ConstraintId, _ConstrainedNode> _helperNodeMap = HashMap();

  /// For layout
  late List<_ConstrainedNode> _layoutOrderList;

  /// For paint
  late List<_ConstrainedNode> _paintingOrderList;

  /// For event dispatch
  late List<_ConstrainedNode> _eventOrderList;

  static const int maxTimeUsage = 20;
  Queue<int> constraintCalculationTimeUsage = Queue();
  Queue<int> layoutTimeUsage = Queue();
  Queue<int> paintTimeUsage = Queue();

  set childConstraints(List<ConstraintDefine>? value) {
    bool isSameList = true;
    if (_childConstraints == null && value == null) {
      // do nothing
    } else if (_childConstraints == null) {
      isSameList = false;
    } else if (value == null) {
      isSameList = false;
    } else {
      if (_childConstraints!.length != value.length) {
        isSameList = false;
      } else {
        for (int i = 0; i < _childConstraints!.length; i++) {
          if (_childConstraints![i] != value[i]) {
            isSameList = false;
            break;
          }
        }
      }
    }
    if (!isSameList) {
      _childConstraints = value;
      _helperNodeMap.clear();
      for (final element in _childConstraints ?? []) {
        if (element is GuidelineDefine) {
          _ConstraintBoxData constraintBoxData = _ConstraintBoxData();
          _HelperBox.initParentData(constraintBoxData);
          _GuidelineRenderBox.initParentData(
            constraintBoxData,
            id: element.id!,
            horizontal: element.horizontal,
            guidelineBegin: element.guidelineBegin,
            guidelineEnd: element.guidelineEnd,
            guidelinePercent: element.guidelinePercent,
          );
          _ConstrainedNode constrainedNode = _ConstrainedNode()
            ..nodeId = element.id!
            ..parentData = constraintBoxData
            ..index = -1
            ..depth = 1;
          _helperNodeMap[element.id!] = constrainedNode;
        } else if (element is BarrierDefine) {
          _ConstraintBoxData constraintBoxData = _ConstraintBoxData();
          _HelperBox.initParentData(constraintBoxData);
          _BarrierRenderBox.initParentData(
            constraintBoxData,
            id: element.id!,
            direction: element.direction,
            referencedIds: element.referencedIds,
          );
          _ConstrainedNode constrainedNode = _ConstrainedNode()
            ..nodeId = element.id!
            ..parentData = constraintBoxData
            ..index = -1;
          _helperNodeMap[element.id!] = constrainedNode;
        }
      }
      markNeedsRecalculateConstraints();
      markNeedsLayout();
    }
  }

  set debugShowGuideline(bool value) {
    if (_debugShowGuideline != value) {
      _debugShowGuideline = value;
      markNeedsPaint();
    }
  }

  set debugShowClickArea(bool value) {
    if (_debugShowClickArea != value) {
      _debugShowClickArea = value;
      markNeedsPaint();
    }
  }

  set debugPrintConstraints(bool value) {
    if (_debugPrintConstraints != value) {
      _debugPrintConstraints = value;
      if (value) {
        markNeedsRecalculateConstraints();
      }
      markNeedsLayout();
    }
  }

  set debugPrintLayoutTime(bool value) {
    if (_debugPrintLayoutTime != value) {
      _debugPrintLayoutTime = value;
      markNeedsLayout();
    }
  }

  set debugCheckConstraints(bool value) {
    if (_debugCheckConstraints != value) {
      _debugCheckConstraints = value;
      if (value) {
        markNeedsRecalculateConstraints();
      }
      markNeedsLayout();
    }
  }

  set releasePrintLayoutTime(bool value) {
    if (_releasePrintLayoutTime != value) {
      _releasePrintLayoutTime = value;
      markNeedsLayout();
    }
  }

  set debugName(String? value) {
    if (_debugName != value) {
      _debugName = value;
      if (value != null) {
        markNeedsRecalculateConstraints();
      }
      markNeedsLayout();
    }
  }

  set debugShowZIndex(bool value) {
    if (_debugShowZIndex != value) {
      _debugShowZIndex = value;
      markNeedsPaint();
    }
  }

  set debugShowChildDepth(bool value) {
    if (_debugShowChildDepth != value) {
      _debugShowChildDepth = value;
      markNeedsPaint();
    }
  }

  set needsReorderPaintingOrder(bool value) {
    if (_needsReorderPaintingOrder != value) {
      _needsReorderPaintingOrder = value;
      markNeedsPaint();
    }
  }

  set needsReorderEventOrder(bool value) {
    if (_needsReorderEventOrder != value) {
      _needsReorderEventOrder = value;
    }
  }

  set width(double value) {
    if (_width != value) {
      if (_width == wrapContent || value == wrapContent) {
        markNeedsRecalculateConstraints();
      }
      _width = value;
      markNeedsLayout();
    }
  }

  set height(double value) {
    if (_height != value) {
      if (_height == wrapContent || value == wrapContent) {
        markNeedsRecalculateConstraints();
      }
      _height = value;
      markNeedsLayout();
    }
  }

  set constraintVersion(ConstraintVersion? value) {
    if (_constraintVersion == null || value == null) {
      markNeedsRecalculateConstraints();
      markNeedsLayout();
    } else {
      if (_constraintVersion!._constraintsVersion !=
          value._constraintsVersion) {
        markNeedsRecalculateConstraints();
        markNeedsLayout();
      } else {
        if (_constraintVersion!._layoutVersion != value._layoutVersion) {
          markNeedsLayout();
        }
        if (_constraintVersion!._paintingOrderVersion !=
            value._paintingOrderVersion) {
          needsReorderPaintingOrder = true;
        }
        if (_constraintVersion!._paintVersion != value._paintVersion) {
          markNeedsPaint();
        }
        if (_constraintVersion!._eventOrderVersion !=
            value._eventOrderVersion) {
          needsReorderEventOrder = true;
        }
      }
    }
    _constraintVersion = value;
  }

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! _ConstraintBoxData) {
      child.parentData = _ConstraintBoxData();

      /// Do not do special treatment for built-in components, treat them as ordinary
      /// child elements, but have a size of 0 and are gone
      if (child is _HelperBox) {
        child.updateParentData();
      }
    }
  }

  /// Make sure the id of the child elements is not repeated
  /// Make sure every id that is relied on is valid
  void _debugCheckIds() {
    RenderBox? child = firstChild;
    Set<ConstraintId> idSet = HashSet();
    idSet.add(parent);
    if (_helperNodeMap.isNotEmpty) {
      for (final element in _helperNodeMap.keys) {
        if (!idSet.add(element)) {
          throw ConstraintLayoutException('Duplicate id in ConstraintLayout.');
        }
      }
    }

    Set<ConstraintId> constraintsIdSet = HashSet();
    while (child != null) {
      _ConstraintBoxData childParentData =
          child.parentData as _ConstraintBoxData;

      if (childParentData.width == null) {
        throw ConstraintLayoutException(
            'Must provide Constraint for child elements, try use Constrained widget.');
      }

      if (childParentData.id != null) {
        if (!idSet.add(childParentData.id!)) {
          throw ConstraintLayoutException('Duplicate id in ConstraintLayout.');
        }
      }
      if (childParentData.left != null) {
        constraintsIdSet.add(childParentData.left!.id);
      }
      if (childParentData.top != null) {
        constraintsIdSet.add(childParentData.top!.id);
      }
      if (childParentData.right != null) {
        constraintsIdSet.add(childParentData.right!.id);
      }
      if (childParentData.bottom != null) {
        constraintsIdSet.add(childParentData.bottom!.id);
      }
      if (childParentData.baseline != null) {
        constraintsIdSet.add(childParentData.baseline!.id);
      }
      if (child is _BarrierRenderBox) {
        constraintsIdSet.addAll(childParentData._referencedIds!);
      }
      if (childParentData.pinnedInfo != null) {
        constraintsIdSet.add(childParentData.pinnedInfo!.anchorId);
      }
      child = childParentData.nextSibling;
    }

    /// All ids referenced by Barrier must be defined
    for (final element in _helperNodeMap.values) {
      if (element.isBarrier) {
        constraintsIdSet.addAll(element.referencedIds!);
      }
    }

    /// The id used by all constraints must be defined
    Set<ConstraintId> illegalIdSet = constraintsIdSet.difference(idSet);
    Set<_IndexConstraintId> indexIds =
        illegalIdSet.whereType<_IndexConstraintId>().toSet();
    Set<_RelativeConstraintId> relativeIds =
        illegalIdSet.whereType<_RelativeConstraintId>().toSet();
    if ((indexIds.length + relativeIds.length) != illegalIdSet.length) {
      throw ConstraintLayoutException(
          'These ids ${illegalIdSet.difference(indexIds).difference(relativeIds)} are not yet defined.');
    }
  }

  /// There should be no loop constraints
  static void _debugCheckLoopConstraints(List<_ConstrainedNode> nodeList,
      bool selfSizeConfirmed, double resolvedWidth, double resolvedHeight) {
    for (final element in nodeList) {
      try {
        element.getDepth(selfSizeConfirmed, resolvedWidth, resolvedHeight);
      } on StackOverflowError catch (_) {
        throw ConstraintLayoutException(
            'There are some loop constraints, please check the code. For layout performance considerations, constraints are always one-way, and there should be no two child elements directly or indirectly restrain each other. Each constraint should describe exactly where the child elements are located. Use Guideline to break loop constraints.');
      }
    }
  }

  /// Each child element must have complete constraints both horizontally and vertically
  static void _debugCheckConstraintsIntegrity(List<_ConstrainedNode> nodeList) {
    for (final element in nodeList) {
      if (element.pinnedInfo != null) {
        if (element.width != wrapContent && element.width < 0) {
          throw ConstraintLayoutException(
              'When setting pinnedInfo, width and height must be wrapContent or fixed size.');
        }
        if (element.height != wrapContent && element.height < 0) {
          throw ConstraintLayoutException(
              'When setting pinnedInfo, width and height must be wrapContent or fixed size.');
        }
        continue;
      }

      /// Check constraint integrity in the horizontal direction
      if (element.width == wrapContent || element.width >= 0) {
        if (element.leftConstraint == null && element.rightConstraint == null) {
          throw ConstraintLayoutException(
              'Need to set a left or right constraint for ${element.nodeId}.');
        }
      } else if (element.width == matchConstraint) {
        if (element.widthHeightRatio == null) {
          if (element.widthPercentageAnchor == PercentageAnchor.constraint) {
            if (element.leftConstraint == null ||
                element.rightConstraint == null) {
              throw ConstraintLayoutException(
                  'Need to set left and right constraints for ${element.nodeId}.');
            }
          } else {
            if (element.leftConstraint == null &&
                element.rightConstraint == null) {
              throw ConstraintLayoutException(
                  'Need to set a left or right constraint for ${element.nodeId}.');
            }
          }
        } else {
          if (element.leftConstraint == null &&
              element.rightConstraint == null) {
            throw ConstraintLayoutException(
                'Need to set a left or right constraint for ${element.nodeId}.');
          }
        }
      }

      /// Check constraint integrity in the vertical direction
      if (element.height == wrapContent || element.height >= 0) {
        int verticalConstraintCount = (element.topConstraint == null ? 0 : 1) +
            (element.bottomConstraint == null ? 0 : 1) +
            (element.baselineConstraint == null ? 0 : 10);
        if (verticalConstraintCount == 0) {
          throw ConstraintLayoutException(
              'Need to set a top or bottom or baseline constraint for ${element.nodeId}.');
        } else if (verticalConstraintCount > 10) {
          throw ConstraintLayoutException(
              'When the baseline constraint is set, the top or bottom constraint can not be set for ${element.nodeId}.');
        }
      } else if (element.height == matchConstraint) {
        if (element.baselineConstraint != null) {
          throw ConstraintLayoutException(
              'When setting a baseline constraint for ${element.nodeId}, its height must be fixed or wrap_content.');
        }
        if (element.widthHeightRatio == null) {
          if (element.heightPercentageAnchor == PercentageAnchor.constraint) {
            if (element.topConstraint == null ||
                element.bottomConstraint == null) {
              throw ConstraintLayoutException(
                  'Need to set both top and bottom constraints for ${element.nodeId}.');
            }
          } else {
            if (element.topConstraint == null &&
                element.bottomConstraint == null) {
              throw ConstraintLayoutException(
                  'Need to set a top or bottom constraints for ${element.nodeId}.');
            }
          }
        } else {
          if (element.topConstraint == null &&
              element.bottomConstraint == null) {
            throw ConstraintLayoutException(
                'Need to set a top or bottom constraints for ${element.nodeId}.');
          }
        }
      } else {
        /// match_parent
        if (element.baselineConstraint != null) {
          throw ConstraintLayoutException(
              'When setting a baseline constraint for ${element.nodeId}, its height must be fixed or wrap_content.');
        }
      }

      if (element.widthHeightRatio != null) {
        if (element.widthIsExact && element.heightIsExact) {
          if (element.width == matchConstraint &&
              element.height == matchConstraint) {
            if (element.ratioBaseOnWidth == null) {
              throw ConstraintLayoutException(
                  'When setting widthHeightRatio for ${element.nodeId}, ratioBaseOnWidth is required.');
            }
          }
        } else if (!element.widthIsExact && !element.heightIsExact) {
          throw ConstraintLayoutException(
              'When setting widthHeightRatio for ${element.nodeId}, one side needs full constraints.');
        } else if (element.widthIsExact) {
          if (element.height != matchConstraint) {
            throw ConstraintLayoutException(
                'When setting widthHeightRatio for ${element.nodeId}, width is exact, height must be matchConstraint.');
          }
        } else {
          if (element.width != matchConstraint) {
            throw ConstraintLayoutException(
                'When setting widthHeightRatio for ${element.nodeId}, height is exact, width must be matchConstraint.');
          }
        }
      }
    }
  }

  Map<ConstraintId, _ConstrainedNode> _buildConstrainedNodeTrees(
      bool selfSizeConfirmed) {
    Map<ConstraintId, _ConstrainedNode> nodesMap = {};
    _buildNodeTreesCount++;
    _ConstrainedNode parentNode = _ConstrainedNode()
      ..nodeId = parent
      ..depth = selfSizeConfirmed ? 0 : childCount + 1
      ..notLaidOut = false;
    if (!selfSizeConfirmed) {
      nodesMap[parent] = parentNode;
    }

    _ConstrainedNode _getConstrainedNodeForChild(ConstraintId id,
        [int? childIndex]) {
      if (id == parent) {
        return parentNode;
      }

      if (id is _RelativeConstraintId) {
        int targetIndex = childIndex! + id.siblingIndexOffset;
        id = _IndexConstraintId(targetIndex);
      }

      _ConstrainedNode? node;
      int? contextHash;
      if (id.runtimeType == ConstraintId) {
        /// Fewer reads to nodesMap for faster constraint building
        contextHash = _buildNodeTreesCount ^ hashCode;
        node = id.getCacheNode(contextHash);
        if (node != null) {
          return node;
        }
      }

      node = nodesMap[id];
      if (node == null) {
        node = _ConstrainedNode()..nodeId = id;
        nodesMap[id] = node;
      }

      if (id.runtimeType == ConstraintId) {
        id.setCacheNode(contextHash!, node);
      }

      return node;
    }

    if (_helperNodeMap.isNotEmpty) {
      nodesMap.addAll(_helperNodeMap);
      for (final element in _helperNodeMap.values) {
        if (element.parentData.left != null) {
          element.leftConstraint =
              _getConstrainedNodeForChild(element.parentData.left!.id);
          element.leftAlignType = element.parentData.left!.type;
        }

        if (element.parentData.top != null) {
          element.topConstraint =
              _getConstrainedNodeForChild(element.parentData.top!.id);
          element.topAlignType = element.parentData.top!.type;
        }

        if (element.parentData.right != null) {
          element.rightConstraint =
              _getConstrainedNodeForChild(element.parentData.right!.id);
          element.rightAlignType = element.parentData.right!.type;
        }

        if (element.parentData.bottom != null) {
          element.bottomConstraint =
              _getConstrainedNodeForChild(element.parentData.bottom!.id);
          element.bottomAlignType = element.parentData.bottom!.type;
        }

        if (element.isBarrier) {
          element.parentData._constrainedNodeMap = nodesMap;
        }
      }
    }

    RenderBox? child = firstChild;
    int childIndex = -1;
    while (child != null) {
      childIndex++;
      _ConstraintBoxData childParentData =
          child.parentData as _ConstraintBoxData;
      childParentData._constrainedNodeMap = nodesMap;

      _ConstrainedNode currentNode = _getConstrainedNodeForChild(
          childParentData.id ?? _IndexConstraintId(childIndex));
      currentNode.parentData = childParentData;
      currentNode.index = childIndex;
      currentNode.renderBox = child;

      if (childParentData.left != null) {
        currentNode.leftConstraint =
            _getConstrainedNodeForChild(childParentData.left!.id, childIndex);
        currentNode.leftAlignType = childParentData.left!.type;
      }

      if (childParentData.top != null) {
        currentNode.topConstraint =
            _getConstrainedNodeForChild(childParentData.top!.id, childIndex);
        currentNode.topAlignType = childParentData.top!.type;
      }

      if (childParentData.right != null) {
        currentNode.rightConstraint =
            _getConstrainedNodeForChild(childParentData.right!.id, childIndex);
        currentNode.rightAlignType = childParentData.right!.type;
      }

      if (childParentData.bottom != null) {
        currentNode.bottomConstraint =
            _getConstrainedNodeForChild(childParentData.bottom!.id, childIndex);
        currentNode.bottomAlignType = childParentData.bottom!.type;
      }

      if (childParentData.baseline != null) {
        currentNode.baselineConstraint = _getConstrainedNodeForChild(
            childParentData.baseline!.id, childIndex);
        currentNode.baselineAlignType = childParentData.baseline!.type;
      }

      if (childParentData.pinnedInfo != null) {
        currentNode.pinnedConstraint = _getConstrainedNodeForChild(
            childParentData.pinnedInfo!.anchorId, childIndex);
      }

      child = childParentData.nextSibling;
    }

    return nodesMap;
  }

  @override
  void adoptChild(covariant RenderObject child) {
    super.adoptChild(child);
    markNeedsRecalculateConstraints();
  }

  @override
  void dropChild(covariant RenderObject child) {
    super.dropChild(child);
    markNeedsRecalculateConstraints();
  }

  void markNeedsRecalculateConstraints() {
    _needsRecalculateConstraints = true;
    _needsReorderPaintingOrder = true;
    _needsReorderEventOrder = true;
  }

  static void insertionSort<E>(List<E> a, int Function(E a, E b) compare) {
    for (int i = 1, lastIndex = a.length - 1; i <= lastIndex; i++) {
      var el = a[i];
      int j = i;
      while ((j > 0) && (compare(a[j - 1], el) > 0)) {
        a[j] = a[j - 1];
        j--;
      }
      a[j] = el;
    }
  }

  @override
  void performLayout() {
    Stopwatch? stopwatch;
    if (_releasePrintLayoutTime && kReleaseMode) {
      stopwatch = Stopwatch()..start();
    }
    assert(() {
      if (_debugPrintLayoutTime) {
        stopwatch = Stopwatch()..start();
      }
      return true;
    }());

    double resolvedWidth;
    if (_width >= 0) {
      resolvedWidth = constraints.constrainWidth(_width);
    } else {
      if (_width == matchParent) {
        if (constraints.maxWidth == double.infinity) {
          resolvedWidth = wrapContent;
        } else {
          resolvedWidth = constraints.maxWidth;
        }
      } else {
        resolvedWidth = wrapContent;
      }
    }

    double resolvedHeight;
    if (_height >= 0) {
      resolvedHeight = constraints.constrainHeight(_height);
    } else {
      if (_height == matchParent) {
        if (constraints.maxHeight == double.infinity) {
          resolvedHeight = wrapContent;
        } else {
          resolvedHeight = constraints.maxHeight;
        }
      } else {
        resolvedHeight = wrapContent;
      }
    }

    bool selfSizeConfirmed = false;
    if (resolvedWidth != wrapContent && resolvedHeight != wrapContent) {
      size = Size(resolvedWidth, resolvedHeight);
      selfSizeConfirmed = true;
    } else if (resolvedWidth != wrapContent) {
      size = Size(resolvedWidth, constraints.minHeight);
    } else if (resolvedHeight != wrapContent) {
      size = Size(constraints.minWidth, resolvedHeight);
    }

    if (_needsRecalculateConstraints) {
      Stopwatch? constraintCalculationWatch;
      if (stopwatch != null) {
        constraintCalculationWatch = Stopwatch()..start();
      }

      assert(() {
        if (_debugCheckConstraints) {
          _debugCheckIds();
        }
        return true;
      }());

      /// Traverse once, building the constrained node tree for each child element
      Map<ConstraintId, _ConstrainedNode> nodesMap =
          _buildConstrainedNodeTrees(selfSizeConfirmed);
      _ConstrainedNode? parentNode = nodesMap.remove(parent);

      assert(() {
        if (_debugCheckConstraints) {
          List<_ConstrainedNode> nodeList = nodesMap.values.toList();
          _debugCheckConstraintsIntegrity(nodeList);
          _debugCheckLoopConstraints(
              nodeList, selfSizeConfirmed, resolvedWidth, resolvedHeight);
        }
        return true;
      }());

      if (childCount > 20) {
        // Count sort by child depth, the complexity is O(n)
        List<List<_ConstrainedNode>> bucket =
            List.generate(childCount * 2 + 1, (_) => []);
        for (final element in nodesMap.values) {
          bucket[element.getDepth(
                  selfSizeConfirmed, resolvedWidth, resolvedHeight)]
              .add(element);
        }
        if (!selfSizeConfirmed) {
          bucket[childCount + 1].add(parentNode!);
        }
        _layoutOrderList = [];
        for (final element in bucket) {
          if (element.isNotEmpty) {
            _layoutOrderList.addAll(element);
          }
        }
      } else {
        _layoutOrderList = nodesMap.values.toList();
        if (!selfSizeConfirmed) {
          _layoutOrderList.add(parentNode!);
        }
        insertionSort<_ConstrainedNode>(_layoutOrderList, (left, right) {
          return left.getDepth(
                  selfSizeConfirmed, resolvedWidth, resolvedHeight) -
              right.getDepth(selfSizeConfirmed, resolvedWidth, resolvedHeight);
        });
      }

      // Most of the time, it is basically ordered, and the complexity is O(n)
      _paintingOrderList = nodesMap.values.toList();
      insertionSort<_ConstrainedNode>(_paintingOrderList, (left, right) {
        int result = left.zIndex - right.zIndex;
        if (result == 0) {
          result = left.index - right.index;
        }
        return result;
      });

      // Most of the time, it is basically ordered, and the complexity is O(n)
      _eventOrderList = nodesMap.values.toList();
      insertionSort<_ConstrainedNode>(_eventOrderList, (left, right) {
        int result = left.eIndex - right.eIndex;
        if (result == 0) {
          result = left.index - right.index;
        }
        return result;
      });

      assert(() {
        /// Print constraints
        if (_debugPrintConstraints) {
          debugPrint(
              'ConstraintLayout@${_debugName ?? hashCode} constraints: ' +
                  jsonEncode(_layoutOrderList.map((e) => e.toJson()).toList()));
        }
        return true;
      }());

      _needsRecalculateConstraints = false;
      _needsReorderPaintingOrder = false;
      _needsReorderEventOrder = false;

      if (constraintCalculationWatch != null) {
        constraintCalculationTimeUsage
            .add(constraintCalculationWatch.elapsedMicroseconds);
        if (constraintCalculationTimeUsage.length > maxTimeUsage) {
          constraintCalculationTimeUsage.removeFirst();
        }
      }
    }

    _layoutByConstrainedNodeTrees(
        selfSizeConfirmed, resolvedWidth, resolvedHeight);

    if (stopwatch != null) {
      layoutTimeUsage.add(stopwatch!.elapsedMicroseconds);
      if (layoutTimeUsage.length > maxTimeUsage) {
        layoutTimeUsage.removeFirst();
      }
    }
  }

  static double _getLeftInsets(
    EdgeInsets insets, [
    bool percentageMargin = false,
    double anchorWidth = 0,
  ]) {
    if (percentageMargin) {
      return anchorWidth * insets.left;
    } else {
      return insets.left;
    }
  }

  static double _getTopInsets(
    EdgeInsets insets, [
    bool percentageMargin = false,
    double anchorHeight = 0,
  ]) {
    if (percentageMargin) {
      return anchorHeight * insets.top;
    } else {
      return insets.top;
    }
  }

  static double _getRightInsets(
    EdgeInsets insets, [
    bool percentageMargin = false,
    double anchorWidth = 0,
  ]) {
    if (percentageMargin) {
      return anchorWidth * insets.right;
    } else {
      return insets.right;
    }
  }

  static double _getBottomInsets(
    EdgeInsets insets, [
    bool percentageMargin = false,
    double anchorHeight = 0,
  ]) {
    if (percentageMargin) {
      return anchorHeight * insets.bottom;
    } else {
      return insets.bottom;
    }
  }

  static double _getHorizontalInsets(
    EdgeInsets insets, [
    bool percentageMargin = false,
    double anchorWidth = 0,
  ]) {
    return _getLeftInsets(insets, percentageMargin, anchorWidth) +
        _getRightInsets(insets, percentageMargin, anchorWidth);
  }

  static double _getVerticalInsets(
    EdgeInsets insets, [
    bool percentageMargin = false,
    double anchorHeight = 0,
  ]) {
    return _getTopInsets(insets, percentageMargin, anchorHeight) +
        _getBottomInsets(insets, percentageMargin, anchorHeight);
  }

  void _layoutByConstrainedNodeTrees(
      bool selfSizeConfirmed, double resolvedWidth, double resolvedHeight) {
    for (int i = 0; i < _layoutOrderList.length; i++) {
      final _ConstrainedNode element = _layoutOrderList[i];

      if (!selfSizeConfirmed) {
        if (element.isParent()) {
          size = Size(
              resolvedWidth == wrapContent
                  ? constraints.minWidth
                  : resolvedWidth,
              resolvedHeight == wrapContent
                  ? constraints.minHeight
                  : resolvedHeight);
          double contentWidth = -double.infinity;
          double contentHeight = -double.infinity;
          for (int j = 0; j < i; j++) {
            _ConstrainedNode sizeConfirmedChild = _layoutOrderList[j];

            if (sizeConfirmedChild.laidOutLater) {
              BoxConstraints childConstraints =
                  calculateChildSize(sizeConfirmedChild, false);

              /// Helper widgets may have no RenderObject
              if (sizeConfirmedChild.renderBox != null) {
                /// Due to the design of the Flutter framework, even if a child element is gone, it still has to be laid out
                /// I don't understand why the official design is this way
                sizeConfirmedChild.renderBox!.layout(
                  childConstraints,
                  parentUsesSize: true,
                );
              }
            }

            if (sizeConfirmedChild.isBarrier) {
              if (sizeConfirmedChild.direction == BarrierDirection.top ||
                  sizeConfirmedChild.direction == BarrierDirection.bottom) {
                sizeConfirmedChild.helperSize = Size(size.width, 0);
              } else {
                sizeConfirmedChild.helperSize = Size(0, size.height);
              }
            }

            sizeConfirmedChild.offset =
                calculateChildOffset(sizeConfirmedChild);
            double childSpanWidth = sizeConfirmedChild.getMeasuredWidth();
            double childSpanHeight = sizeConfirmedChild.getMeasuredHeight();

            if (sizeConfirmedChild.leftConstraint != null &&
                sizeConfirmedChild.rightConstraint != null) {
            } else if (sizeConfirmedChild.leftConstraint != null) {
              childSpanWidth += sizeConfirmedChild.getX();
            } else if (sizeConfirmedChild.rightConstraint != null) {
              childSpanWidth += size.width - sizeConfirmedChild.getRight();
            } else {
              childSpanWidth += sizeConfirmedChild.getX();
            }

            if (sizeConfirmedChild.topConstraint != null &&
                sizeConfirmedChild.bottomConstraint != null) {
            } else if (sizeConfirmedChild.topConstraint != null) {
              childSpanHeight += sizeConfirmedChild.getY();
            } else if (sizeConfirmedChild.bottomConstraint != null) {
              childSpanHeight += size.height - sizeConfirmedChild.getBottom();
            } else {
              childSpanHeight += sizeConfirmedChild.getY();
            }

            if (childSpanWidth > contentWidth) {
              contentWidth = childSpanWidth;
            }

            if (childSpanHeight > contentHeight) {
              contentHeight = childSpanHeight;
            }
          }
          size = Size(
              resolvedWidth == wrapContent
                  ? constraints.constrainWidth(contentWidth)
                  : resolvedWidth,
              resolvedHeight == wrapContent
                  ? constraints.constrainHeight(contentHeight)
                  : resolvedHeight);
          for (int j = 0; j < i; j++) {
            _ConstrainedNode sizeConfirmedChild = _layoutOrderList[j];
            if (sizeConfirmedChild.isBarrier) {
              if (sizeConfirmedChild.direction == BarrierDirection.top ||
                  sizeConfirmedChild.direction == BarrierDirection.bottom) {
                sizeConfirmedChild.helperSize = Size(size.width, 0);
              } else {
                sizeConfirmedChild.helperSize = Size(0, size.height);
              }
            }
            sizeConfirmedChild.offset =
                calculateChildOffset(sizeConfirmedChild);
            if (sizeConfirmedChild.callback != null) {
              sizeConfirmedChild.callback!.call(
                  sizeConfirmedChild.renderBox!,
                  Rect.fromLTWH(
                      sizeConfirmedChild.getX(),
                      sizeConfirmedChild.getY(),
                      sizeConfirmedChild.getMeasuredWidth(),
                      sizeConfirmedChild.getMeasuredHeight()));
            }
          }
          selfSizeConfirmed = true;
          continue;
        }

        if (element.isBarrier) {
          element.laidOutLater = true;
          continue;
        }
        if (element.width == matchConstraint ||
            element.height == matchConstraint) {
          element.laidOutLater = true;
          continue;
        }
        if ((element.width < 0 && element.width != wrapContent) ||
            (element.height < 0 && element.height != wrapContent)) {
          if (element.leftConstraint != null) {
            if (element.leftConstraint!.laidOutLater) {
              element.laidOutLater = true;
              continue;
            }
          }
          if (element.topConstraint != null) {
            if (element.topConstraint!.laidOutLater) {
              element.laidOutLater = true;
              continue;
            }
          }
          if (element.rightConstraint != null) {
            if (element.rightConstraint!.laidOutLater) {
              element.laidOutLater = true;
              continue;
            }
          }
          if (element.bottomConstraint != null) {
            if (element.bottomConstraint!.laidOutLater) {
              element.laidOutLater = true;
              continue;
            }
          }
          if (element.baselineConstraint != null) {
            if (element.baselineConstraint!.laidOutLater) {
              element.laidOutLater = true;
              continue;
            }
          }
        }
      }

      BoxConstraints childConstraints =
          calculateChildSize(element, selfSizeConfirmed);

      /// Helper widgets may have no RenderObject
      if (element.renderBox != null) {
        /// Due to the design of the Flutter framework, even if a child element is gone, it still has to be laid out
        /// I don't understand why the official design is this way
        element.renderBox!.layout(
          childConstraints,
          parentUsesSize: true,
        );
      }

      if (selfSizeConfirmed) {
        if (element.isGuideline) {
          element.helperSize =
              Size(childConstraints.minWidth, childConstraints.minHeight);
        } else if (element.isBarrier) {
          if (element.direction == BarrierDirection.top ||
              element.direction == BarrierDirection.bottom) {
            element.helperSize = Size(size.width, 0);
          } else {
            element.helperSize = Size(0, size.height);
          }
        }

        element.offset = calculateChildOffset(element);
        if (element.callback != null) {
          element.callback!.call(
              element.renderBox!,
              Rect.fromLTWH(element.getX(), element.getY(),
                  element.getMeasuredWidth(), element.getMeasuredHeight()));
        }
      }
    }
  }

  BoxConstraints calculateChildSize(
      _ConstrainedNode node, bool selfSizeConfirmed) {
    EdgeInsets margin = node.margin;
    EdgeInsets goneMargin = node.goneMargin;

    /// Calculate child width
    double minWidth;
    double maxWidth;
    double minHeight;
    double maxHeight;
    if (node.visibility == gone) {
      minWidth = 0;
      maxWidth = 0;
      minHeight = 0;
      maxHeight = 0;
    } else {
      double width = node.width;
      if (width == wrapContent) {
        minWidth = node.minWidth;
        if (node.maxWidth == matchParent) {
          if (selfSizeConfirmed) {
            if (node.renderBox is _ConstraintRenderBox) {
              maxWidth = double.infinity;
            } else {
              maxWidth = size.width;
            }
          } else {
            maxWidth = double.infinity;
          }
        } else {
          maxWidth = node.maxWidth;
        }
      } else if (width == matchParent) {
        minWidth = size.width -
            _getHorizontalInsets(margin, node.percentageMargin, size.width);
        assert(() {
          if (_debugCheckConstraints) {
            if (minWidth < 0) {
              debugPrint(
                  'Warning: The child element with id ${node.nodeId} has a negative width');
            }
          }
          return true;
        }());
        maxWidth = minWidth;
      } else if (width == matchConstraint) {
        if (node.widthHeightRatio != null &&
            node.heightIsExact &&
            node.ratioBaseOnWidth != true) {
          /// The width needs to be calculated later based on the height
          node.widthBasedHeight = true;
          minWidth = 0;
          maxWidth = double.infinity;
        } else {
          if (node.widthPercentageAnchor == PercentageAnchor.constraint) {
            double left;
            if (node.leftAlignType == _AlignType.left) {
              left = node.leftConstraint!.getX();
            } else {
              left = node.leftConstraint!.getRight(this);
            }
            double right;
            if (node.rightAlignType == _AlignType.left) {
              right = node.rightConstraint!.getX();
            } else {
              right = node.rightConstraint!.getRight(this);
            }
            double leftMargin;
            if (node.leftConstraint!.notLaidOut) {
              leftMargin = _getLeftInsets(
                  goneMargin, node.percentageMargin, right - left);
            } else {
              leftMargin =
                  _getLeftInsets(margin, node.percentageMargin, right - left);
            }
            double rightMargin;
            if (node.rightConstraint!.notLaidOut) {
              rightMargin = _getRightInsets(
                  goneMargin, node.percentageMargin, right - left);
            } else {
              rightMargin =
                  _getRightInsets(margin, node.percentageMargin, right - left);
            }
            minWidth =
                (right - rightMargin - left - leftMargin) * node.widthPercent;
          } else {
            minWidth = (size.width -
                    _getHorizontalInsets(
                        margin, node.percentageMargin, size.width)) *
                node.widthPercent;
          }
          assert(() {
            if (_debugCheckConstraints) {
              if (minWidth < 0) {
                debugPrint(
                    'Warning: The child element with id ${node.nodeId} has a negative width');
              }
            }
            return true;
          }());
          maxWidth = minWidth;
        }
      } else {
        minWidth = width;
        maxWidth = width;
      }

      /// Calculate child height
      double height = node.height;
      if (height == wrapContent) {
        minHeight = node.minHeight;
        if (node.maxHeight == matchParent) {
          if (selfSizeConfirmed) {
            if (node.renderBox is _ConstraintRenderBox) {
              maxHeight = double.infinity;
            } else {
              maxHeight = size.height;
            }
          } else {
            maxHeight = double.infinity;
          }
        } else {
          maxHeight = node.maxHeight;
        }
      } else if (height == matchParent) {
        minHeight = size.height -
            _getVerticalInsets(margin, node.percentageMargin, size.height);
        assert(() {
          if (_debugCheckConstraints) {
            if (minHeight < 0) {
              debugPrint(
                  'Warning: The child element with id ${node.nodeId} has a negative height');
            }
          }
          return true;
        }());
        maxHeight = minHeight;
      } else if (height == matchConstraint) {
        if (node.widthHeightRatio != null &&
            node.widthIsExact &&
            node.ratioBaseOnWidth != false) {
          /// The height needs to be calculated later based on the width
          /// minWidth == maxWidth
          minHeight = minWidth / node.widthHeightRatio!;
          maxHeight = minHeight;
        } else {
          if (node.heightPercentageAnchor == PercentageAnchor.constraint) {
            double top;
            if (node.topAlignType == _AlignType.top) {
              top = node.topConstraint!.getY();
            } else {
              top = node.topConstraint!.getBottom(this);
            }
            double bottom;
            if (node.bottomAlignType == _AlignType.top) {
              bottom = node.bottomConstraint!.getY();
            } else {
              bottom = node.bottomConstraint!.getBottom(this);
            }
            double topMargin;
            if (node.topConstraint!.notLaidOut) {
              topMargin = _getTopInsets(
                  goneMargin, node.percentageMargin, bottom - top);
            } else {
              topMargin =
                  _getTopInsets(margin, node.percentageMargin, bottom - top);
            }
            double bottomMargin;
            if (node.bottomConstraint!.notLaidOut) {
              bottomMargin = _getBottomInsets(
                  goneMargin, node.percentageMargin, bottom - top);
            } else {
              bottomMargin =
                  _getBottomInsets(margin, node.percentageMargin, bottom - top);
            }
            minHeight =
                (bottom - bottomMargin - top - topMargin) * node.heightPercent;
          } else {
            minHeight = (size.height -
                    _getVerticalInsets(
                        margin, node.percentageMargin, size.height)) *
                node.heightPercent;
          }
          assert(() {
            if (_debugCheckConstraints) {
              if (minHeight < 0) {
                debugPrint(
                    'Warning: The child element with id ${node.nodeId} has a negative height');
              }
            }
            return true;
          }());
          maxHeight = minHeight;
        }
      } else {
        minHeight = height;
        maxHeight = height;
      }
    }

    /// The width needs to be calculated based on the height
    if (node.widthBasedHeight) {
      /// minHeight == maxHeight
      minWidth = minHeight * node.widthHeightRatio!;
      maxWidth = minWidth;
    }

    /// Measure
    if (maxWidth <= 0 || maxHeight <= 0) {
      node.notLaidOut = true;
      if (maxWidth < 0) {
        minWidth = 0;
        maxWidth = 0;
      }
      if (maxHeight < 0) {
        minHeight = 0;
        maxHeight = 0;
      }
      assert(() {
        if (_debugCheckConstraints) {
          if ((!node.isGuideline && !node.isBarrier) &&
              node.visibility != gone) {
            debugPrint(
                'Warning: The child element with id ${node.nodeId} has a negative size, will not be laid out and paint.');
          }
        }
        return true;
      }());
    } else {
      node.notLaidOut = false;
    }

    return BoxConstraints(
      minWidth: minWidth,
      maxWidth: maxWidth,
      minHeight: minHeight,
      maxHeight: maxHeight,
    );
  }

  Offset calculateChildOffset(_ConstrainedNode node) {
    if (node.pinnedInfo != null) {
      PinnedInfo pinnedInfo = node.pinnedInfo!;
      Offset selfOffset = pinnedInfo.selfPos.resolve(node.renderBox!.size);
      Offset targetOffset =
          pinnedInfo.targetPos.resolve(node.pinnedConstraint!.getSize(this));
      double offsetX =
          node.pinnedConstraint!.getX() + targetOffset.dx - selfOffset.dx;
      double offsetY =
          node.pinnedConstraint!.getY() + targetOffset.dy - selfOffset.dy;
      return Offset(offsetX, offsetY);
    }

    EdgeInsets margin = node.margin;
    EdgeInsets goneMargin = node.goneMargin;
    double offsetX = 0;
    double offsetY = 0;
    if (node.isBarrier) {
      BarrierDirection direction = node.direction!;
      List<double> list = [];
      for (final id in node.referencedIds!) {
        if (direction == BarrierDirection.left) {
          list.add(node.parentData._constrainedNodeMap[id]!.getX());
        } else if (direction == BarrierDirection.top) {
          list.add(node.parentData._constrainedNodeMap[id]!.getY());
        } else if (direction == BarrierDirection.right) {
          list.add(node.parentData._constrainedNodeMap[id]!.getRight());
        } else {
          list.add(node.parentData._constrainedNodeMap[id]!.getBottom());
        }
      }
      double min = double.maxFinite;
      double max = double.minPositive;
      for (final element in list) {
        if (element > max) {
          max = element;
        }
        if (element < min) {
          min = element;
        }
      }
      if (direction == BarrierDirection.left) {
        offsetX = min;
        offsetY = 0;
      } else if (direction == BarrierDirection.top) {
        offsetX = 0;
        offsetY = min;
      } else if (direction == BarrierDirection.right) {
        offsetX = max;
        offsetY = 0;
      } else {
        offsetX = 0;
        offsetY = max;
      }
    } else {
      /// Calculate child x offset
      if (node.leftConstraint != null && node.rightConstraint != null) {
        double left;
        if (node.leftAlignType == _AlignType.left) {
          left = node.leftConstraint!.getX();
        } else {
          left = node.leftConstraint!.getRight(this);
        }
        double right;
        if (node.rightAlignType == _AlignType.left) {
          right = node.rightConstraint!.getX();
        } else {
          right = node.rightConstraint!.getRight(this);
        }
        double leftMargin;
        if (node.leftConstraint!.notLaidOut) {
          leftMargin =
              _getLeftInsets(goneMargin, node.percentageMargin, right - left);
        } else {
          leftMargin =
              _getLeftInsets(margin, node.percentageMargin, right - left);
        }
        double rightMargin;
        if (node.rightConstraint!.notLaidOut) {
          rightMargin =
              _getRightInsets(goneMargin, node.percentageMargin, right - left);
        } else {
          rightMargin =
              _getRightInsets(margin, node.percentageMargin, right - left);
        }
        offsetX = left +
            leftMargin +
            (right -
                    rightMargin -
                    left -
                    leftMargin -
                    node.getMeasuredWidth()) *
                node.horizontalBias;
      } else if (node.leftConstraint != null) {
        double left;
        if (node.leftAlignType == _AlignType.left) {
          left = node.leftConstraint!.getX();
        } else {
          left = node.leftConstraint!.getRight(this);
        }
        if (node.leftConstraint!.notLaidOut) {
          left += _getLeftInsets(goneMargin, node.percentageMargin, size.width);
        } else {
          left += _getLeftInsets(margin, node.percentageMargin, size.width);
        }
        offsetX = left;
      } else if (node.rightConstraint != null) {
        double right;
        if (node.rightAlignType == _AlignType.left) {
          right = node.rightConstraint!.getX();
        } else {
          right = node.rightConstraint!.getRight(this);
        }
        if (node.rightConstraint!.notLaidOut) {
          right -=
              _getRightInsets(goneMargin, node.percentageMargin, size.width);
        } else {
          right -= _getRightInsets(margin, node.percentageMargin, size.width);
        }
        offsetX = right - node.getMeasuredWidth();
      } else {
        /// It is not possible to execute this branch
      }

      /// Calculate child y offset
      if (node.topConstraint != null && node.bottomConstraint != null) {
        double top;
        if (node.topAlignType == _AlignType.top) {
          top = node.topConstraint!.getY();
        } else {
          top = node.topConstraint!.getBottom(this);
        }
        double bottom;
        if (node.bottomAlignType == _AlignType.top) {
          bottom = node.bottomConstraint!.getY();
        } else {
          bottom = node.bottomConstraint!.getBottom(this);
        }
        double topMargin;
        if (node.topConstraint!.notLaidOut) {
          topMargin =
              _getTopInsets(goneMargin, node.percentageMargin, bottom - top);
        } else {
          topMargin =
              _getTopInsets(margin, node.percentageMargin, bottom - top);
        }
        double bottomMargin;
        if (node.bottomConstraint!.notLaidOut) {
          bottomMargin =
              _getBottomInsets(goneMargin, node.percentageMargin, bottom - top);
        } else {
          bottomMargin =
              _getBottomInsets(margin, node.percentageMargin, bottom - top);
        }
        offsetY = top +
            topMargin +
            (bottom -
                    bottomMargin -
                    top -
                    topMargin -
                    node.getMeasuredHeight()) *
                node.verticalBias;
      } else if (node.topConstraint != null) {
        double top;
        if (node.topAlignType == _AlignType.top) {
          top = node.topConstraint!.getY();
        } else {
          top = node.topConstraint!.getBottom(this);
        }
        if (node.topConstraint!.notLaidOut) {
          top += _getTopInsets(goneMargin, node.percentageMargin, size.height);
        } else {
          top += _getTopInsets(margin, node.percentageMargin, size.height);
        }
        offsetY = top;
      } else if (node.bottomConstraint != null) {
        double bottom;
        if (node.bottomAlignType == _AlignType.top) {
          bottom = node.bottomConstraint!.getY();
        } else {
          bottom = node.bottomConstraint!.getBottom(this);
        }
        if (node.bottomConstraint!.notLaidOut) {
          bottom -=
              _getBottomInsets(goneMargin, node.percentageMargin, size.height);
        } else {
          bottom -=
              _getBottomInsets(margin, node.percentageMargin, size.height);
        }
        offsetY = bottom - node.getMeasuredHeight();
      } else if (node.baselineConstraint != null) {
        if (node.baselineAlignType == _AlignType.top) {
          offsetY = node.baselineConstraint!.getY() -
              node.getDistanceToBaseline(node.textBaseline, false);
        } else if (node.baselineAlignType == _AlignType.bottom) {
          offsetY = node.baselineConstraint!.getBottom(this) -
              node.getDistanceToBaseline(node.textBaseline, false);
        } else {
          offsetY = node.baselineConstraint!
                  .getDistanceToBaseline(node.textBaseline, true) -
              node.getDistanceToBaseline(node.textBaseline, false);
        }
        if (node.baselineConstraint!.notLaidOut) {
          offsetY +=
              _getTopInsets(goneMargin, node.percentageMargin, size.height);
          offsetY -=
              _getBottomInsets(goneMargin, node.percentageMargin, size.height);
        } else {
          offsetY += _getTopInsets(margin, node.percentageMargin, size.height);
          offsetY -=
              _getBottomInsets(margin, node.percentageMargin, size.height);
        }
      } else {
        /// It is not possible to execute this branch
      }
    }

    return Offset(offsetX, offsetY);
  }

  @override
  bool hitTestChildren(
    BoxHitTestResult result, {
    required Offset position,
  }) {
    if (_needsReorderEventOrder) {
      insertionSort<_ConstrainedNode>(_eventOrderList, (left, right) {
        int result = left.eIndex - right.eIndex;
        if (result == 0) {
          result = left.index - right.index;
        }
        return result;
      });
      _needsReorderEventOrder = false;
    }

    for (final element in _eventOrderList.reversed) {
      if (element.shouldNotPaint()) {
        continue;
      }

      Offset clickShift = Offset.zero;
      if (!element.translateConstraint) {
        clickShift = element.translate;
      }

      /// Expand the click area without changing the actual size
      Offset offsetPos = Offset(position.dx, position.dy);
      EdgeInsets clickPadding = element.clickPadding;
      if (clickPadding != EdgeInsets.zero) {
        double x = element.getX();
        x += clickShift.dx;
        double y = element.getY();
        y += clickShift.dy;
        double clickPaddingLeft = x - clickPadding.left;
        double clickPaddingTop = y - clickPadding.top;
        double clickPaddingRight =
            x + element.getMeasuredWidth() + clickPadding.right;
        double clickPaddingBottom =
            y + element.getMeasuredHeight() + clickPadding.bottom;
        double xClickPercent = (offsetPos.dx - clickPaddingLeft) /
            (clickPaddingRight - clickPaddingLeft);
        double yClickPercent = (offsetPos.dy - clickPaddingTop) /
            (clickPaddingBottom - clickPaddingTop);
        double realClickX = x + xClickPercent * element.getMeasuredWidth();
        double realClickY = y + yClickPercent * element.getMeasuredHeight();
        offsetPos = Offset(realClickX, realClickY);
      }

      bool isHit = result.addWithPaintOffset(
        offset: element.offset + clickShift,
        position: offsetPos,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          return element.renderBox!.hitTest(result, position: transformed);
        },
      );
      if (isHit) {
        return true;
      }
    }

    return false;
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset,
  ) {
    Stopwatch? stopwatch;
    if (_releasePrintLayoutTime && kReleaseMode) {
      stopwatch = Stopwatch()..start();
    }
    assert(() {
      if (_debugPrintLayoutTime) {
        stopwatch = Stopwatch()..start();
      }
      return true;
    }());

    if (_needsReorderPaintingOrder) {
      insertionSort<_ConstrainedNode>(_paintingOrderList, (left, right) {
        int result = left.zIndex - right.zIndex;
        if (result == 0) {
          result = left.index - right.index;
        }
        return result;
      });
      _needsReorderPaintingOrder = false;
    }

    for (final element in _paintingOrderList) {
      if (element.shouldNotPaint()) {
        continue;
      }

      Offset paintShift = Offset.zero;
      if (!element.translateConstraint) {
        paintShift = element.translate;
      }
      context.paintChild(
          element.renderBox!, element.offset + offset + paintShift);

      /// Draw child's click area
      assert(() {
        if (_debugShowClickArea) {
          Paint paint = Paint();
          paint.color = Colors.yellow.withAlpha(192);
          EdgeInsets clickPadding = element.clickPadding;
          Rect rect = Rect.fromLTRB(
              element.getX() - _getLeftInsets(clickPadding),
              element.getY() - _getTopInsets(clickPadding),
              element.getX() +
                  element.getMeasuredWidth() +
                  _getRightInsets(clickPadding),
              element.getY() +
                  element.getMeasuredHeight() +
                  _getBottomInsets(clickPadding));
          rect = rect.shift(offset).shift(paintShift);
          context.canvas.drawRect(rect, paint);
          ui.ParagraphBuilder paragraphBuilder =
              ui.ParagraphBuilder(ui.ParagraphStyle(
            textAlign: TextAlign.center,
            fontSize: 12,
          ));
          paragraphBuilder.addText("CLICK AREA");
          ui.Paragraph paragraph = paragraphBuilder.build();
          paragraph.layout(ui.ParagraphConstraints(
            width: rect.width,
          ));
          context.canvas.drawParagraph(
              paragraph, rect.centerLeft + Offset(0, -paragraph.height / 2));
        }
        return true;
      }());

      /// Draw child's z index
      assert(() {
        if (_debugShowZIndex) {
          ui.ParagraphBuilder paragraphBuilder =
              ui.ParagraphBuilder(ui.ParagraphStyle(
            textAlign: TextAlign.center,
            fontSize: 10,
          ));
          paragraphBuilder.addText("z-index ${element.zIndex}");
          ui.Paragraph paragraph = paragraphBuilder.build();
          paragraph.layout(ui.ParagraphConstraints(
            width: element.getMeasuredWidth(),
          ));
          context.canvas
              .drawParagraph(paragraph, element.offset + offset + paintShift);
        }
        return true;
      }());

      assert(() {
        if (_debugShowChildDepth) {
          ui.ParagraphBuilder paragraphBuilder =
              ui.ParagraphBuilder(ui.ParagraphStyle(
            textAlign: TextAlign.center,
            fontSize: 10,
          ));
          paragraphBuilder.pushStyle(ui.TextStyle(
            color: Colors.black,
          ));
          paragraphBuilder
              .addText("depth ${element.getDepth(null, null, null)}");
          ui.Paragraph paragraph = paragraphBuilder.build();
          paragraph.layout(ui.ParagraphConstraints(
            width: element.getMeasuredWidth(),
          ));
          context.canvas.drawParagraph(
              paragraph,
              element.offset +
                  offset +
                  paintShift +
                  Offset(0, element.getMeasuredHeight() - paragraph.height));
        }
        return true;
      }());
    }

    assert(() {
      if (_debugShowGuideline) {
        for (final element in _paintingOrderList) {
          if (element.isGuideline || element.isBarrier) {
            Paint paint = Paint();
            if (element.isGuideline) {
              paint.color = Colors.green;
            } else {
              paint.color = Colors.purple;
            }
            paint.strokeWidth = 5;
            context.canvas.drawLine(
                element.offset + offset,
                Offset(element.getRight(), element.getBottom()) + offset,
                paint);
          }
        }
      }
      return true;
    }());

    if (stopwatch != null) {
      paintTimeUsage.add(stopwatch!.elapsedMicroseconds);
      if (paintTimeUsage.length > maxTimeUsage) {
        paintTimeUsage.removeFirst();
      }
      _debugShowPerformance(context, offset);
    }
  }

  void _debugShowPerformance(
    PaintingContext context,
    Offset offset,
  ) {
    Paint paint = Paint()..color = Colors.white;
    Iterator<int> constraintCalculateIterator =
        constraintCalculationTimeUsage.iterator;
    double heightOffset = 0;
    while (constraintCalculateIterator.moveNext()) {
      int calculateTime = constraintCalculateIterator.current;
      ui.ParagraphBuilder paragraphBuilder =
          ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: 8,
      ));
      if (calculateTime > 1000) {
        paragraphBuilder.pushStyle(ui.TextStyle(
          color: Colors.red,
          background: paint,
        ));
      } else {
        paragraphBuilder.pushStyle(ui.TextStyle(
          color: Colors.green,
          background: paint,
        ));
      }
      paragraphBuilder.addText("calculate $calculateTime us");
      ui.Paragraph paragraph = paragraphBuilder.build();
      paragraph.layout(const ui.ParagraphConstraints(
        width: 80,
      ));
      context.canvas.drawParagraph(paragraph, Offset(0, heightOffset) + offset);
      heightOffset += 10;
    }

    Iterator<int> layoutIterator = layoutTimeUsage.iterator;
    heightOffset = 0;
    while (layoutIterator.moveNext()) {
      int layoutTime = layoutIterator.current;
      ui.ParagraphBuilder paragraphBuilder =
          ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: 8,
      ));
      if (layoutTime > 5000) {
        paragraphBuilder.pushStyle(ui.TextStyle(
          color: Colors.red,
          background: paint,
        ));
      } else {
        paragraphBuilder.pushStyle(ui.TextStyle(
          color: Colors.green,
          background: paint,
        ));
      }
      paragraphBuilder.addText("layout $layoutTime us");
      ui.Paragraph paragraph = paragraphBuilder.build();
      paragraph.layout(const ui.ParagraphConstraints(
        width: 80,
      ));
      context.canvas
          .drawParagraph(paragraph, Offset(80, heightOffset) + offset);
      heightOffset += 10;
    }

    Iterator<int> paintIterator = paintTimeUsage.iterator;
    heightOffset = 0;
    while (paintIterator.moveNext()) {
      int paintTime = paintIterator.current;
      ui.ParagraphBuilder paragraphBuilder =
          ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: 8,
      ));
      if (paintTime > 5000) {
        paragraphBuilder.pushStyle(ui.TextStyle(
          color: Colors.red,
          background: paint,
        ));
      } else {
        paragraphBuilder.pushStyle(ui.TextStyle(
          color: Colors.green,
          background: paint,
        ));
      }
      paragraphBuilder.addText("paint $paintTime us");
      ui.Paragraph paragraph = paragraphBuilder.build();
      paragraph.layout(const ui.ParagraphConstraints(
        width: 80,
      ));
      context.canvas
          .drawParagraph(paragraph, Offset(160, heightOffset) + offset);
      heightOffset += 10;
    }

    ui.ParagraphBuilder paragraphBuilder =
        ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: 8,
    ));
    paragraphBuilder.pushStyle(ui.TextStyle(
      color: Colors.green,
      background: paint,
    ));
    paragraphBuilder.addText('The bottom one is the latest');
    ui.Paragraph paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(
      width: 240,
    ));
    context.canvas.drawParagraph(paragraph, Offset(0, heightOffset) + offset);
  }
}

class _ConstrainedNode {
  late ConstraintId nodeId;
  RenderBox? renderBox;
  _ConstrainedNode? leftConstraint;
  _ConstrainedNode? topConstraint;
  _ConstrainedNode? rightConstraint;
  _ConstrainedNode? bottomConstraint;
  _ConstrainedNode? baselineConstraint;
  _ConstrainedNode? pinnedConstraint;
  _AlignType? leftAlignType;
  _AlignType? topAlignType;
  _AlignType? rightAlignType;
  _AlignType? bottomAlignType;
  _AlignType? baselineAlignType;
  int depth = -1;
  late bool notLaidOut;
  late _ConstraintBoxData parentData;
  late int index;
  bool widthBasedHeight = false;

  double get width => parentData.width!;

  double get height => parentData.height!;

  int get zIndex => parentData.zIndex ?? index;

  int get eIndex => parentData.eIndex ?? zIndex;

  bool laidOutLater = false;

  Offset get offset {
    if (translateConstraint) {
      return parentData.offset + translate;
    } else {
      return parentData.offset;
    }
  }

  Offset get translate {
    if (!percentageTranslate) {
      return parentData.translate!;
    } else {
      double dx = renderBox!.size.width * parentData.translate!.dx;
      double dy = renderBox!.size.height * parentData.translate!.dy;
      return Offset(dx, dy);
    }
  }

  bool get translateConstraint => parentData.translateConstraint!;

  EdgeInsets get margin => parentData.margin!;

  EdgeInsets get goneMargin => parentData.goneMargin!;

  CLVisibility get visibility => parentData.visibility!;

  double get horizontalBias => parentData.horizontalBias!;

  double get verticalBias => parentData.verticalBias!;

  EdgeInsets get clickPadding => parentData.clickPadding!;

  TextBaseline get textBaseline => parentData.textBaseline!;

  double get widthPercent => parentData.widthPercent!;

  double get heightPercent => parentData.heightPercent!;

  bool get percentageMargin => parentData.percentageMargin!;

  double get minWidth => parentData.minWidth!;

  double get maxWidth => parentData.maxWidth!;

  double get minHeight => parentData.minHeight!;

  double get maxHeight => parentData.maxHeight!;

  PercentageAnchor get widthPercentageAnchor =>
      parentData.widthPercentageAnchor!;

  PercentageAnchor get heightPercentageAnchor =>
      parentData.heightPercentageAnchor!;

  OnLayoutCallback? get callback => parentData.callback;

  List<ConstraintId>? get referencedIds => parentData._referencedIds;

  BarrierDirection? get direction => parentData._direction;

  bool get percentageTranslate => parentData.percentageTranslate!;

  double? get widthHeightRatio => parentData.widthHeightRatio;

  bool? get ratioBaseOnWidth => parentData.ratioBaseOnWidth;

  bool get isGuideline => parentData._isGuideline;

  bool get isBarrier => parentData._isBarrier;

  Size? get helperSize => parentData._helperSize;

  PinnedInfo? get pinnedInfo => parentData.pinnedInfo;

  set helperSize(Size? size) {
    parentData._helperSize = size;
  }

  /// fixed size, matchParent, matchConstraint with two constraints
  bool get widthIsExact =>
      width >= 0 ||
      (width == matchParent) ||
      (width == matchConstraint &&
          widthPercentageAnchor == PercentageAnchor.parent) ||
      (width == matchConstraint &&
          leftConstraint != null &&
          rightConstraint != null);

  /// fixed size, matchParent, matchConstraint with two constraints
  bool get heightIsExact =>
      height >= 0 ||
      (height == matchParent) ||
      (height == matchConstraint &&
          heightPercentageAnchor == PercentageAnchor.parent) ||
      (height == matchConstraint &&
          (topConstraint != null && bottomConstraint != null));

  set offset(Offset value) {
    parentData.offset = value;
  }

  bool isParent() {
    return nodeId == parent;
  }

  bool shouldNotPaint() {
    return visibility == gone || visibility == invisible || notLaidOut;
  }

  double getX() {
    if (isParent()) {
      return 0;
    }
    return offset.dx;
  }

  double getY() {
    if (isParent()) {
      return 0;
    }
    return offset.dy;
  }

  double getRight([RenderBox? parent]) {
    if (isParent()) {
      return parent!.size.width;
    }
    return getX() + getMeasuredWidth();
  }

  double getBottom([RenderBox? parent]) {
    if (isParent()) {
      return parent!.size.height;
    }
    return getY() + getMeasuredHeight();
  }

  Size getSize([RenderBox? parent]) {
    if (isParent()) {
      return parent!.size;
    }
    return renderBox!.size;
  }

  double getMeasuredWidth() {
    if (isGuideline || isBarrier) {
      return helperSize!.width;
    }
    return renderBox!.size.width;
  }

  double getMeasuredHeight() {
    if (isGuideline || isBarrier) {
      return helperSize!.height;
    }
    return renderBox!.size.height;
  }

  double getDistanceToBaseline(TextBaseline textBaseline, bool absolute) {
    if (isParent()) {
      return 0;
    }
    if (isGuideline || isBarrier) {
      return getY();
    }
    double? baseline =
        renderBox!.getDistanceToBaseline(textBaseline, onlyReal: true);
    if (baseline == null) {
      baseline = getY();
    } else {
      if (absolute) {
        baseline += getY();
      }
    }
    return baseline;
  }

  int getDepthFor(_ConstrainedNode constrainedNode, bool? parentSizeConfirmed,
      double? resolvedWidth, double? resolvedHeight) {
    if (parentSizeConfirmed == false) {
      if (constrainedNode.isParent()) {
        /// The width and height can be calculated directly without relying on parent
        if ((width >= 0 ||
                width == wrapContent ||
                (width == matchParent && resolvedWidth != wrapContent)) &&
            (height >= 0 ||
                height == wrapContent ||
                (height == matchParent && resolvedHeight != wrapContent))) {
          return 0;
        }
      }
    }
    return constrainedNode.getDepth(
        parentSizeConfirmed, resolvedWidth, resolvedHeight);
  }

  int getMaxDepth(List<int> depths) {
    int max = -1;
    for (final element in depths) {
      if (element > max) {
        max = element;
      }
    }
    return max;
  }

  int getDepth(bool? parentSizeConfirmed, double? resolvedWidth,
      double? resolvedHeight) {
    if (depth < 0) {
      if (isBarrier) {
        List<int> list = [
          for (final id in referencedIds!)
            parentData._constrainedNodeMap[id]!
                .getDepth(parentSizeConfirmed, resolvedWidth, resolvedHeight)
        ];
        depth = getMaxDepth(list) + 1;
      } else {
        List<int> list = [
          if (leftConstraint != null)
            getDepthFor(leftConstraint!, parentSizeConfirmed, resolvedWidth,
                resolvedHeight),
          if (topConstraint != null)
            getDepthFor(topConstraint!, parentSizeConfirmed, resolvedWidth,
                resolvedHeight),
          if (rightConstraint != null)
            getDepthFor(rightConstraint!, parentSizeConfirmed, resolvedWidth,
                resolvedHeight),
          if (bottomConstraint != null)
            getDepthFor(bottomConstraint!, parentSizeConfirmed, resolvedWidth,
                resolvedHeight),
          if (baselineConstraint != null)
            getDepthFor(baselineConstraint!, parentSizeConfirmed, resolvedWidth,
                resolvedHeight),
          if (pinnedConstraint != null)
            getDepthFor(pinnedConstraint!, parentSizeConfirmed, resolvedWidth,
                resolvedHeight),
        ];
        depth = getMaxDepth(list) + 1;
      }
    }
    return depth;
  }

  /// For debug message print
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (nodeId == parent) {
      map['nodeId'] = 'parent';
    } else {
      map['nodeId'] = nodeId.id;
      if (leftConstraint != null) {
        if (leftAlignType == _AlignType.left) {
          map['leftAlignType'] = 'toLeft';
        } else {
          map['leftAlignType'] = 'toRight';
        }
        if (leftConstraint!.isParent()) {
          map['leftConstraint'] = 'parent';
        } else {
          map['leftConstraint'] = leftConstraint!.toJson();
        }
      }
      if (topConstraint != null) {
        if (topAlignType == _AlignType.top) {
          map['topAlignType'] = 'toTop';
        } else {
          map['topAlignType'] = 'toBottom';
        }
        if (topConstraint!.isParent()) {
          map['topConstraint'] = 'parent';
        } else {
          map['topConstraint'] = topConstraint!.toJson();
        }
      }
      if (rightConstraint != null) {
        if (rightAlignType == _AlignType.left) {
          map['rightAlignType'] = 'toLeft';
        } else {
          map['rightAlignType'] = 'toRight';
        }
        if (rightConstraint!.isParent()) {
          map['rightConstraint'] = 'parent';
        } else {
          map['rightConstraint'] = rightConstraint!.toJson();
        }
      }
      if (bottomConstraint != null) {
        if (bottomAlignType == _AlignType.top) {
          map['bottomAlignType'] = 'toTop';
        } else {
          map['bottomAlignType'] = 'toBottom';
        }
        if (bottomConstraint!.isParent()) {
          map['bottomConstraint'] = 'parent';
        } else {
          map['bottomConstraint'] = bottomConstraint!.toJson();
        }
      }
      if (baselineConstraint != null) {
        if (baselineAlignType == _AlignType.top) {
          map['baselineAlignType'] = 'toTop';
        } else if (baselineAlignType == _AlignType.bottom) {
          map['baselineAlignType'] = 'toBottom';
        } else {
          map['baselineAlignType'] = 'toBaseline';
        }
        if (baselineConstraint!.isParent()) {
          map['baselineConstraint'] = 'parent';
        } else {
          map['baselineConstraint'] = baselineConstraint!.toJson();
        }
      }
      if (pinnedConstraint != null) {
        if (pinnedConstraint!.isParent()) {
          map['pinnedConstraint'] = 'parent';
        } else {
          map['pinnedConstraint'] = pinnedConstraint!.toJson();
        }
      }
    }
    map['depth'] = getDepth(null, null, null);
    return map;
  }
}

class _HelperBox extends RenderBox {
  static void initParentData(_ConstraintBoxData constraintBoxData) {
    constraintBoxData.width = 0;
    constraintBoxData.height = 0;
    constraintBoxData.clickPadding = EdgeInsets.zero;
    constraintBoxData.visibility = invisible;
    constraintBoxData.percentageMargin = false;
    constraintBoxData.margin = EdgeInsets.zero;
    constraintBoxData.goneMargin = EdgeInsets.zero;
    constraintBoxData.left = null;
    constraintBoxData.top = null;
    constraintBoxData.right = null;
    constraintBoxData.bottom = null;
    constraintBoxData.baseline = null;
    constraintBoxData.textBaseline = TextBaseline.alphabetic;
    constraintBoxData.zIndex = null;
    constraintBoxData.translate = Offset.zero;
    constraintBoxData.translateConstraint = false;
    constraintBoxData.widthPercent = 1;
    constraintBoxData.heightPercent = 1;
    constraintBoxData.widthPercentageAnchor = PercentageAnchor.constraint;
    constraintBoxData.heightPercentageAnchor = PercentageAnchor.constraint;
    constraintBoxData.horizontalBias = 0.5;
    constraintBoxData.verticalBias = 0.5;
    constraintBoxData.callback = null;
    constraintBoxData.percentageTranslate = false;
    constraintBoxData.minWidth = 0;
    constraintBoxData.maxWidth = matchParent;
    constraintBoxData.minHeight = 0;
    constraintBoxData.maxHeight = matchParent;
    constraintBoxData.widthHeightRatio = null;
    constraintBoxData.ratioBaseOnWidth = null;
    constraintBoxData.eIndex = null;
    constraintBoxData.pinnedInfo = null;
    constraintBoxData._direction = null;
    constraintBoxData._referencedIds = null;
    constraintBoxData._isGuideline = false;
    constraintBoxData._isBarrier = false;
    constraintBoxData._helperSize = null;
  }

  @protected
  @mustCallSuper
  void updateParentData() {
    _ConstraintBoxData constraintBoxData = parentData as _ConstraintBoxData;
    initParentData(constraintBoxData);
  }
}

class GuidelineDefine extends ConstraintDefine {
  final double? guidelineBegin;
  final double? guidelineEnd;
  final double? guidelinePercent;
  final bool horizontal;

  GuidelineDefine({
    required ConstraintId id,
    this.guidelineBegin,
    this.guidelineEnd,
    this.guidelinePercent,
    this.horizontal = false,
  }) : super(id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is GuidelineDefine &&
          runtimeType == other.runtimeType &&
          guidelineBegin == other.guidelineBegin &&
          guidelineEnd == other.guidelineEnd &&
          guidelinePercent == other.guidelinePercent &&
          horizontal == other.horizontal;

  @override
  int get hashCode =>
      super.hashCode ^
      guidelineBegin.hashCode ^
      guidelineEnd.hashCode ^
      guidelinePercent.hashCode ^
      horizontal.hashCode;
}

class Guideline extends LeafRenderObjectWidget {
  final ConstraintId id;
  final double? guidelineBegin;
  final double? guidelineEnd;
  final double? guidelinePercent;
  final bool horizontal;

  const Guideline({
    Key? key,
    required this.id,
    this.guidelineBegin,
    this.guidelineEnd,
    this.guidelinePercent,
    this.horizontal = false,
  }) : super(key: key);

  bool _checkParam() {
    int guideConstraintCount = (guidelineBegin == null ? 0 : 1) +
        (guidelineEnd == null ? 0 : 1) +
        (guidelinePercent == null ? 0 : 1);
    if (guideConstraintCount == 0) {
      throw ConstraintLayoutException(
          'Must set one of guidelineBegin、guidelineEnd、guidelinePercent.');
    } else if (guideConstraintCount != 1) {
      throw ConstraintLayoutException(
          'Must set only one of guidelineBegin、guidelineEnd、guidelinePercent.');
    }
    if (guidelinePercent != null) {
      _debugEnsurePercent('guidelinePercent', guidelinePercent);
    }
    return true;
  }

  @override
  RenderObject createRenderObject(BuildContext context) {
    assert(_checkParam());
    return _GuidelineRenderBox()
      .._id = id
      .._guidelineBegin = guidelineBegin
      .._guidelineEnd = guidelineEnd
      .._guidelinePercent = guidelinePercent
      .._horizontal = horizontal;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    assert(_checkParam());
    (renderObject as _GuidelineRenderBox)
      ..id = id
      ..guidelineBegin = guidelineBegin
      ..guidelineEnd = guidelineEnd
      ..guidelinePercent = guidelinePercent
      ..horizontal = horizontal;
  }
}

class _GuidelineRenderBox extends _HelperBox {
  late ConstraintId _id;
  late bool _horizontal;
  double? _guidelineBegin;
  double? _guidelineEnd;
  double? _guidelinePercent;

  set id(ConstraintId value) {
    if (_id != value) {
      _id = value;
      updateParentData();
      (this.parent as _ConstraintRenderBox).markNeedsRecalculateConstraints();
      markParentNeedsLayout();
    }
  }

  set guidelineBegin(double? value) {
    if (_guidelineBegin != value) {
      _guidelineBegin = value;
      updateParentData();
      markParentNeedsLayout();
    }
  }

  set guidelineEnd(double? value) {
    if (_guidelineEnd != value) {
      _guidelineEnd = value;
      updateParentData();
      markParentNeedsLayout();
    }
  }

  set guidelinePercent(double? value) {
    if (_guidelinePercent != value) {
      _guidelinePercent = value;
      updateParentData();
      markParentNeedsLayout();
    }
  }

  set horizontal(bool value) {
    if (_horizontal != value) {
      _horizontal = value;
      updateParentData();
      markParentNeedsLayout();
    }
  }

  @override
  void updateParentData() {
    super.updateParentData();
    _ConstraintBoxData constraintBoxData = parentData as _ConstraintBoxData;
    initParentData(
      constraintBoxData,
      id: _id,
      horizontal: _horizontal,
      guidelineBegin: _guidelineBegin,
      guidelineEnd: _guidelineEnd,
      guidelinePercent: _guidelinePercent,
    );
  }

  @override
  void performLayout() {
    if (_horizontal) {
      size = Size(constraints.minWidth, 0);
    } else {
      size = Size(0, constraints.minHeight);
    }
  }

  static void initParentData(
    _ConstraintBoxData constraintBoxData, {
    required ConstraintId id,
    required bool horizontal,
    double? guidelineBegin,
    double? guidelineEnd,
    double? guidelinePercent,
  }) {
    constraintBoxData.id = id;
    constraintBoxData._isGuideline = true;
    if (horizontal) {
      if (guidelineBegin != null) {
        constraintBoxData.left = parent.left;
        constraintBoxData.top = parent.top;
        constraintBoxData.right = parent.right;
        constraintBoxData.width = matchParent;
        constraintBoxData.margin = EdgeInsets.only(top: guidelineBegin);
      } else if (guidelineEnd != null) {
        constraintBoxData.left = parent.left;
        constraintBoxData.right = parent.right;
        constraintBoxData.bottom = parent.bottom;
        constraintBoxData.width = matchParent;
        constraintBoxData.margin = EdgeInsets.only(bottom: guidelineEnd);
      } else {
        constraintBoxData.left = parent.left;
        constraintBoxData.top = parent.top;
        constraintBoxData.right = parent.right;
        constraintBoxData.width = matchParent;
        constraintBoxData.margin = EdgeInsets.only(
          top: guidelinePercent!,
        );
        constraintBoxData.percentageMargin = true;
      }
    } else {
      if (guidelineBegin != null) {
        constraintBoxData.left = parent.left;
        constraintBoxData.top = parent.top;
        constraintBoxData.bottom = parent.bottom;
        constraintBoxData.height = matchParent;
        constraintBoxData.margin = EdgeInsets.only(left: guidelineBegin);
      } else if (guidelineEnd != null) {
        constraintBoxData.top = parent.top;
        constraintBoxData.right = parent.right;
        constraintBoxData.bottom = parent.bottom;
        constraintBoxData.height = matchParent;
        constraintBoxData.margin = EdgeInsets.only(right: guidelineEnd);
      } else {
        constraintBoxData.left = parent.left;
        constraintBoxData.top = parent.top;
        constraintBoxData.bottom = parent.bottom;
        constraintBoxData.height = matchParent;
        constraintBoxData.margin = EdgeInsets.only(
          left: guidelinePercent!,
        );
        constraintBoxData.percentageMargin = true;
      }
    }
  }
}

class BarrierDefine extends ConstraintDefine {
  final BarrierDirection direction;
  final List<ConstraintId> referencedIds;

  BarrierDefine({
    required ConstraintId id,
    required this.direction,
    required this.referencedIds,
  }) : super(id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is BarrierDefine &&
          runtimeType == other.runtimeType &&
          direction == other.direction &&
          referencedIds == other.referencedIds;

  @override
  int get hashCode =>
      super.hashCode ^ direction.hashCode ^ referencedIds.hashCode;
}

class Barrier extends LeafRenderObjectWidget {
  final ConstraintId id;
  final BarrierDirection direction;
  final List<ConstraintId> referencedIds;

  const Barrier({
    Key? key,
    required this.id,
    required this.direction,
    required this.referencedIds,
  }) : super(key: key);

  bool checkParam() {
    if (referencedIds.isEmpty) {
      throw ConstraintLayoutException('referencedIds can not be empty.');
    }
    if (referencedIds.toSet().length != referencedIds.length) {
      throw ConstraintLayoutException('Duplicate id in referencedIds.');
    }
    return true;
  }

  @override
  RenderObject createRenderObject(BuildContext context) {
    assert(checkParam());
    return _BarrierRenderBox()
      .._id = id
      .._direction = direction
      .._referencedIds = referencedIds;
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderObject renderObject) {
    assert(checkParam());
    (renderObject as _BarrierRenderBox)
      ..id = id
      ..direction = direction
      ..referencedIds = referencedIds;
  }
}

class _BarrierRenderBox extends _HelperBox {
  late ConstraintId _id;
  late BarrierDirection _direction;
  late List<ConstraintId> _referencedIds;

  @override
  void updateParentData() {
    super.updateParentData();
    _ConstraintBoxData constraintBoxData = parentData as _ConstraintBoxData;
    initParentData(
      constraintBoxData,
      id: _id,
      direction: _direction,
      referencedIds: _referencedIds,
    );
  }

  set id(ConstraintId value) {
    if (_id != value) {
      _id = value;
      updateParentData();
      (this.parent as _ConstraintRenderBox).markNeedsRecalculateConstraints();
      markParentNeedsLayout();
    }
  }

  set direction(BarrierDirection value) {
    if (_direction != value) {
      _direction = value;
      updateParentData();
      markParentNeedsLayout();
    }
  }

  set referencedIds(List<ConstraintId> value) {
    bool isSameList = true;
    if (_referencedIds.length != value.length) {
      isSameList = false;
    } else {
      for (int i = 0; i < _referencedIds.length; i++) {
        if (_referencedIds[i] != value[i]) {
          isSameList = false;
          break;
        }
      }
    }
    if (!isSameList) {
      _referencedIds = value;
      updateParentData();
      (this.parent as _ConstraintRenderBox).markNeedsRecalculateConstraints();
      markParentNeedsLayout();
    }
  }

  @override
  void performLayout() {
    if (_direction == BarrierDirection.top ||
        _direction == BarrierDirection.bottom) {
      size = Size(constraints.minWidth, 0);
    } else {
      size = Size(0, constraints.minHeight);
    }
  }

  static void initParentData(
    _ConstraintBoxData constraintBoxData, {
    required ConstraintId id,
    required BarrierDirection direction,
    required List<ConstraintId> referencedIds,
  }) {
    constraintBoxData.id = id;
    constraintBoxData._isBarrier = true;
    constraintBoxData._direction = direction;
    constraintBoxData._referencedIds = referencedIds;
    if (direction == BarrierDirection.top ||
        direction == BarrierDirection.bottom) {
      constraintBoxData.top = parent.top;
      constraintBoxData.left = parent.left;
      constraintBoxData.right = parent.right;
    } else {
      constraintBoxData.left = parent.left;
      constraintBoxData.top = parent.top;
      constraintBoxData.bottom = parent.bottom;
    }
  }
}

class ConstraintLayoutException implements Exception {
  final String msg;

  ConstraintLayoutException(this.msg);

  @override
  String toString() {
    return 'ConstraintLayoutException throw: $msg';
  }
}
