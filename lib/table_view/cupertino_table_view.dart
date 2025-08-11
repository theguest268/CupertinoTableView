import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../delegate/cupertino_table_view_delegate.dart';
import '../index_path/index_path.dart';
import '../refresh/refresh_config.dart';
import '../refresh/refresh_controller.dart';
import '../refresh/refresh_indicator.dart';
import 'cupertino_table_view_cell.dart';

class _TableViewConstants {
  static const double defaultBorderWidth = 1.0;
  static const Color defaultDividerColor = Color(0x00f7f7f7);
  static const double defaultDividerIndent = 15.0;
  static const double defaultDividerHeight = 1.0;

  // Special row indices for headers and footers
  static const int headerRowIndex = -1;
  static const int footerRowIndex = -2;
}

enum CellType {
  only,
  first,
  middle,
  last,
}

class CupertinoTableView extends StatefulWidget {
  const CupertinoTableView({
    super.key,
    required this.delegate,
    this.padding,
    this.margin,
    this.physics = const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
    this.refreshConfig,
    this.scrollController,
    this.primaryScrollController,
    this.onScroll,
    this.roundCornerBorderRadius,
    this.hasDefaultBorder,
    this.backgroundColor,
    this.pressedColor,
  });

  final CupertinoTableViewDelegate delegate;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final ScrollPhysics? physics;
  final RefreshConfig? refreshConfig;
  final ScrollController? scrollController;
  final bool? primaryScrollController;
  final ValueChanged<ScrollController>? onScroll;
  final double? roundCornerBorderRadius;
  final bool? hasDefaultBorder;
  final Color? backgroundColor;
  final Color? pressedColor;

  @override
  State<CupertinoTableView> createState() => _CupertinoTableViewState();
}

class _CupertinoTableViewState extends State<CupertinoTableView> {
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _footerKey = GlobalKey();

  double _headerHeight = 0.0;
  double _footerHeight = 0.0;

  /// 如果外部没有传scrollController，那么会使用_fallbackScrollController
  ScrollController? _fallbackScrollController;

  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _fallbackScrollController ?? PrimaryScrollController.maybeOf(context)!;

  @override
  void initState() {
    super.initState();
    _initScrollController();
    _addListener();
    _calculateHeight();
  }

  @override
  void dispose() {
    _removeListener();
    _disposeScrollController();

    widget.refreshConfig?.dispose();
    super.dispose();
  }

  /// 是否设置了需要refresh功能
  bool get enableRefresh {
    final refreshConfig = widget.refreshConfig;
    if (refreshConfig == null) {
      return false;
    }
    return refreshConfig.enablePullUp || refreshConfig.enablePullDown;
  }

  bool get enableDivider {
    return widget.delegate.dividerInTableView?.call(context) != null;
  }

  @override
  Widget build(BuildContext context) {
    if (!enableRefresh && widget.onScroll == null && widget.scrollController == null) {
      return _buildSimpleContainer();
    }

    return _buildScrollableContainer();
  }

  /// Builds a simple container with ListView when refresh is not needed
  Widget _buildSimpleContainer() {
    return Container(
      color: widget.backgroundColor,
      margin: widget.margin,
      child: _buildSimpleList(),
    );
  }

  /// Builds a scrollable container with refresh functionality
  Widget _buildScrollableContainer() {
    final refreshConfig = widget.refreshConfig;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: <Widget>[
            Positioned(
              top: (refreshConfig?.enablePullDown == true) ? -_headerHeight : 0,
              bottom: (refreshConfig?.enablePullUp == true) ? -_footerHeight : 0,
              left: 0,
              right: 0,
              child: NotificationListener<ScrollNotification>(
                onNotification: _dispatchScrollEvent,
                child: Container(
                  margin: widget.margin,
                  color: widget.backgroundColor,
                  child: _buildCustomScrollView(refreshConfig),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds the CustomScrollView with slivers
  Widget _buildCustomScrollView(RefreshConfig? refreshConfig) {
    return CustomScrollView(
      primary: widget.primaryScrollController,
      physics: widget.physics,
      controller: (widget.primaryScrollController == true) ? null : _effectiveScrollController,
      slivers: [
        if (refreshConfig?.enablePullDown == true) SliverToBoxAdapter(child: _buildRefreshHeader(refreshConfig!)),
        _buildSliverList(),
        if (refreshConfig?.enablePullUp == true) SliverToBoxAdapter(child: _buildRefreshFooter(refreshConfig!)),
      ],
    );
  }

  /// Builds a simple ListView for basic use cases
  Widget _buildSimpleList() {
    final indexPaths = _generateIndexPaths();

    return ListView.builder(
      padding: widget.padding,
      physics: widget.physics,
      itemCount: indexPaths.length,
      itemBuilder: (context, index) {
        return _buildListItem(indexPaths[index]);
      },
    );
  }

  /// Builds a SliverList for use in CustomScrollView
  Widget _buildSliverList() {
    final indexPaths = _generateIndexPaths();

    return SliverPadding(
      padding: widget.padding ?? EdgeInsets.zero,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _buildListItem(indexPaths[index]);
          },
          childCount: indexPaths.length,
        ),
      ),
    );
  }

  /// Generates all index paths for the table view
  List<IndexPath> _generateIndexPaths() {
    final result = <IndexPath>[];
    final sectionCount = _getSectionCount();

    for (int section = 0; section < sectionCount; section++) {
      // Add section header
      result.add(IndexPath(section: section, row: _TableViewConstants.headerRowIndex));

      // Add cells and dividers
      final rowCount = _getRowCount(section);
      if (enableDivider && rowCount > 0) {
        // Add cells with dividers between them
        for (int row = 0; row < rowCount; row++) {
          result.add(IndexPath(section: section, row: row));
          if (row < rowCount - 1) {
            // Add divider (using negative row index to distinguish)
            result.add(IndexPath(section: section, row: -(row + 10))); // Unique negative index for dividers
          }
        }
      } else {
        // Add cells without dividers
        for (int row = 0; row < rowCount; row++) {
          result.add(IndexPath(section: section, row: row));
        }
      }

      // Add section footer
      result.add(IndexPath(section: section, row: _TableViewConstants.footerRowIndex));
    }

    return result;
  }

  /// Builds an individual list item based on the index path
  Widget _buildListItem(IndexPath indexPath) {
    final row = indexPath.row;

    // Handle special row types
    if (row == _TableViewConstants.headerRowIndex) {
      return _buildSectionHeader(indexPath.section);
    } else if (row == _TableViewConstants.footerRowIndex) {
      return _buildSectionFooter(indexPath.section);
    } else if (row < 0) {
      // Divider row (negative index)
      return _buildDivider(indexPath.section);
    } else {
      // Regular cell
      return _buildCell(indexPath);
    }
  }

  int _getSectionCount() {
    return widget.delegate.numberOfSectionsInTableView();
  }

  int _getRowCount(int section) {
    return widget.delegate.numberOfRowsInSection?.call(section) ?? 0;
  }

  /// 构建单个cell
  Widget _buildCell(IndexPath indexPath) {
    final section = indexPath.section;
    final rowCount = _getRowCount(section);

    if (rowCount <= 0) {
      return const SizedBox.shrink();
    }

    final decoration = _getCellDecoration(section);
    final cellType = _determineCellType(indexPath.row, rowCount);

    return Container(
      clipBehavior: Clip.hardEdge,
      margin: _calculateCellMargin(cellType, section),
      decoration: decoration.copyWith(
        color: widget.backgroundColor ?? Colors.transparent,
        border: _getBorder(),
        borderRadius: _calculateBorderRadius(cellType),
      ),
      child: _buildCellContent(indexPath),
    );
  }

  Widget _buildCellContent(IndexPath indexPath) {
    return CupertinoTableViewCell(
      pressedOpacity: widget.delegate.pressedOpacity,
      onTap: _createTapHandler(indexPath),
      pressedColor: widget.pressedColor ?? Colors.transparent,
      builder: (context) => widget.delegate.cellForRowAtIndexPath(context, indexPath),
    );
  }

  /// Creates a tap handler for a cell
  VoidCallback? _createTapHandler(IndexPath indexPath) {
    final canSelect = widget.delegate.canSelectRowAtIndexPath?.call(indexPath) ?? false;
    if (!canSelect || widget.delegate.didSelectRowAtIndexPath == null) {
      return null;
    }
    return () => widget.delegate.didSelectRowAtIndexPath?.call(indexPath);
  }

  /// Gets the decoration for a section
  BoxDecoration _getCellDecoration(int section) {
    return widget.delegate.decorationForSection?.call(context, section) ?? const BoxDecoration();
  }

  /// Determines the type of cell based on its position
  CellType _determineCellType(int rowIndex, int totalRows) {
    if (totalRows == 1) return CellType.only;
    if (rowIndex == 0) return CellType.first;
    if (rowIndex == totalRows - 1) return CellType.last;
    return CellType.middle;
  }

  /// Calculates margin for a cell based on its type
  EdgeInsets? _calculateCellMargin(CellType cellType, int section) {
    final baseMargin = widget.delegate.marginForSection?.call(section) ?? EdgeInsets.zero;

    switch (cellType) {
      case CellType.only:
        return baseMargin;
      case CellType.first:
        return baseMargin.copyWith(bottom: 0);
      case CellType.last:
        return baseMargin.copyWith(top: 0);
      case CellType.middle:
        return baseMargin.copyWith(top: 0, bottom: 0);
    }
  }

  /// Calculates border radius for a cell based on its type
  BorderRadiusGeometry? _calculateBorderRadius(CellType cellType) {
    final radius = widget.roundCornerBorderRadius;
    if (radius == null) return BorderRadius.zero;

    switch (cellType) {
      case CellType.only:
        return BorderRadius.circular(radius);
      case CellType.first:
        return BorderRadius.vertical(top: Radius.circular(radius));
      case CellType.last:
        return BorderRadius.vertical(bottom: Radius.circular(radius));
      case CellType.middle:
        return BorderRadius.zero;
    }
  }

  /// Gets the default border for cells
  BoxBorder? _getBorder() {
    if (!(widget.hasDefaultBorder ?? false)) return null;

    final color = widget.backgroundColor ?? Colors.transparent;
    return Border.all(
      color: color,
      width: _TableViewConstants.defaultBorderWidth,
      strokeAlign: BorderSide.strokeAlignOutside,
    );
  }

  /// 构建section header
  Widget _buildSectionHeader(int section) {
    return widget.delegate.headerInSection?.call(context, section) ?? const SizedBox.shrink();
  }

  /// 构建section footer
  Widget _buildSectionFooter(int section) {
    return widget.delegate.footerInSection?.call(context, section) ?? const SizedBox.shrink();
  }

  Widget _buildDivider(section) {
    final sectionMargin = widget.delegate.marginForSection?.call(section) ?? EdgeInsets.zero;

    return Container(
      margin: EdgeInsets.only(left: sectionMargin.left, right: sectionMargin.right),
      child: widget.delegate.dividerInTableView?.call(context) ??
          const Divider(
            height: _TableViewConstants.defaultDividerHeight,
            thickness: _TableViewConstants.defaultDividerHeight,
            indent: _TableViewConstants.defaultDividerIndent,
            endIndent: _TableViewConstants.defaultDividerIndent,
            color: _TableViewConstants.defaultDividerColor,
          ),
    );
  }

  /// 构建refresh header
  /// 如果config中的header builder为空，那么没有效果
  Widget _buildRefreshHeader(RefreshConfig config) {
    if (config.refreshHeaderBuilder == null) {
      return const SizedBox.shrink();
    }
    return RefreshHeader(
      key: _headerKey,
      refreshController: config.controller,
      indicatorBuilder: config.refreshHeaderBuilder!,
      config: config.headerConfig,
    );
  }

  /// 构建refresh footer
  /// 如果config中的footer builder为空，那么没有效果
  Widget _buildRefreshFooter(RefreshConfig config) {
    if (config.refreshFooterBuilder == null) {
      return const SizedBox.shrink();
    }
    return RefreshFooter(
      key: _footerKey,
      refreshController: config.controller,
      indicatorBuilder: config.refreshFooterBuilder!,
      config: config.footerConfig,
    );
  }

  /// 初始化ScrollController
  void _initScrollController() {
    if (widget.scrollController == null) {
      if ((widget.primaryScrollController ?? false)) {
        if (PrimaryScrollController.maybeOf(context) == null) {
          _fallbackScrollController = ScrollController();
        }
      } else {
        _fallbackScrollController = ScrollController();
      }
    }
  }

  /// 销毁ScrollController，在state dispose中调用
  void _disposeScrollController() {
    if (widget.scrollController != null) {
      widget.scrollController!.dispose();
    } else {
      _fallbackScrollController?.dispose();
      _fallbackScrollController = null;
    }
  }

  /// 增加listener
  void _addListener() {
    if (widget.refreshConfig == null) {
      return;
    }
    RefreshController controller = widget.refreshConfig!.controller;
    controller.addHeaderListener(_headerStatusDidChange);
    controller.addFooterListener(_footerStatusDidChange);
  }

  /// 移除listener，在state dispose中调用
  void _removeListener() {
    if (widget.refreshConfig == null) {
      return;
    }
    RefreshController controller = widget.refreshConfig!.controller;
    controller.removeHeaderListener(_headerStatusDidChange);
    controller.removeFooterListener(_footerStatusDidChange);
  }

  /// 处理refresh header状态变化
  void _headerStatusDidChange() {
    if (widget.refreshConfig == null) {
      return;
    }
    RefreshController controller = widget.refreshConfig!.controller;
    _refreshHeaderStatusDidChange(controller, controller.refreshHeaderStatus);
  }

  /// 处理refresh footer状态变化
  void _footerStatusDidChange() {
    if (widget.refreshConfig == null) {
      return;
    }
    RefreshController controller = widget.refreshConfig!.controller;
    _refreshFooterStatusDidChange(controller, controller.refreshFooterStatus);
  }

  /// 处理refresh header状态变化
  void _refreshHeaderStatusDidChange(
    RefreshController controller,
    RefreshStatus status,
  ) {
    widget.refreshConfig!.onRefreshHeaderStatusChange?.call(controller, status);
    switch (status) {
      case RefreshStatus.refreshing:
        if (Platform.isIOS) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.vibrate();
        }

        RefreshIndicatorConfig config = widget.refreshConfig!.headerConfig;
        jumpTo(currentOffset + config.visibleRange);
        break;
      case RefreshStatus.idle:
        break;
      case RefreshStatus.prepared:
        break;
      case RefreshStatus.completed:
        break;
    }
  }

  /// 处理refresh footer状态变化
  void _refreshFooterStatusDidChange(
    RefreshController controller,
    RefreshStatus status,
  ) {
    widget.refreshConfig!.onRefreshFooterStatusChange?.call(controller, status);
    switch (status) {
      case RefreshStatus.refreshing:
        if (Platform.isIOS) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.vibrate();
        }
        break;
      default:
        break;
    }
  }

  /// 计算refresh header和refresh footer的高度
  void _calculateHeight() {
    final refreshConfig = widget.refreshConfig;
    if (refreshConfig == null) {
      return;
    }

    _headerHeight = widget.refreshConfig?.headerConfig.indicatorHeight ?? 0;
    _footerHeight = widget.refreshConfig?.footerConfig.indicatorHeight ?? 0;

    bool needCalculateHeight = false;
    if (refreshConfig.enablePullDown && _headerHeight == 0) {
      needCalculateHeight = true;
    }
    if (refreshConfig.enablePullUp && _footerHeight == 0) {
      needCalculateHeight = true;
    }
    if (!needCalculateHeight) {
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (refreshConfig.enablePullDown) {
          _headerHeight = _headerKey.currentContext?.size?.height ?? 0;
        }
        if (refreshConfig.enablePullUp) {
          _footerHeight = _footerKey.currentContext?.size?.height ?? 0;
        }
      });
    });
  }

  /// 开始滚动的处理
  bool _handleScrollStart(ScrollStartNotification notification) {
    if (widget.refreshConfig == null) {
      return false;
    }

    if (notification.metrics.outOfRange) {
      return false;
    }

    if (widget.refreshConfig!.enablePullDown) {
      dynamic state = _headerKey.currentState;
      if (_headerKey.currentState == null) {
        return false;
      }
      DragProcessor header = state as DragProcessor;
      header.onDragStart(notification);
    }

    if (widget.refreshConfig!.enablePullUp) {
      dynamic state = _footerKey.currentState;
      if (state == null) {
        return false;
      }
      DragProcessor footer = state as DragProcessor;
      footer.onDragStart(notification);
    }

    return false;
  }

  /// 滚动中的处理
  bool _handleScrollMoving(ScrollUpdateNotification notification) {
    if (widget.refreshConfig == null) {
      return false;
    }

    if (widget.refreshConfig!.enablePullDown) {
      dynamic state = _headerKey.currentState;
      if (_headerKey.currentState == null) {
        return false;
      }
      DragProcessor header = state as DragProcessor;
      header.onDragMove(notification);
    }

    if (widget.refreshConfig!.enablePullUp) {
      dynamic state = _footerKey.currentState;
      if (state == null) {
        return false;
      }
      DragProcessor footer = state as DragProcessor;
      footer.onDragMove(notification);
    }

    return false;
  }

  /// 停止滚动的处理
  bool _handleScrollEnd(ScrollNotification notification) {
    if (widget.refreshConfig == null) {
      return false;
    }

    if (widget.refreshConfig!.enablePullDown) {
      dynamic state = _headerKey.currentState;
      if (_headerKey.currentState == null) {
        return false;
      }
      DragProcessor header = state as DragProcessor;
      header.onDragEnd(notification);
    }

    if (widget.refreshConfig!.enablePullUp) {
      dynamic state = _footerKey.currentState;
      if (state == null) {
        return false;
      }
      DragProcessor footer = state as DragProcessor;
      footer.onDragEnd(notification);
    }

    return false;
  }

  /// 分发滚动事件
  bool _dispatchScrollEvent(ScrollNotification notification) {
    widget.onScroll?.call(_effectiveScrollController);

    if (notification.metrics.axis == Axis.horizontal) {
      return false;
    }

    bool pullUp = notification.metrics.pixels < 0;
    bool pullDown = notification.metrics.pixels > 0;
    if (!pullUp && !pullDown) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      return _handleScrollStart(notification);
    }

    if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails == null) {
        // dragDetails为空表示手指离开了滑动区域
        return _handleScrollEnd(notification);
      } else {
        return _handleScrollMoving(notification);
      }
    }

    if (notification is ScrollEndNotification) {
      return _handleScrollEnd(notification);
    }

    return false;
  }

  /// 当前列表的offset
  double get currentOffset => _effectiveScrollController.offset;

  /// 跳转到某个offset
  void jumpTo(double offset) {
    _effectiveScrollController.jumpTo(offset);
  }

  /// 滚动到某个offset
  Future<void> animateTo(double offset, {required Duration duration, required Curve curve}) {
    return _effectiveScrollController.animateTo(offset, duration: duration, curve: curve);
  }
}
