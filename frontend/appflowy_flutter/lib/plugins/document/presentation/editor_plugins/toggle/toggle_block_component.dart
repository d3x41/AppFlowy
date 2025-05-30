import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database/tab_bar/tab_bar_view.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_platform/universal_platform.dart';

class ToggleListBlockKeys {
  const ToggleListBlockKeys._();

  static const String type = 'toggle_list';

  /// The content of a code block.
  ///
  /// The value is a String.
  static const String delta = blockComponentDelta;

  static const String backgroundColor = blockComponentBackgroundColor;

  static const String textDirection = blockComponentTextDirection;

  /// The value is a bool.
  static const String collapsed = 'collapsed';

  /// The value is a int.
  ///
  /// If this value is not null, the block represent a toggle heading.
  static const String level = 'level';
}

Node toggleListBlockNode({
  String? text,
  Delta? delta,
  bool collapsed = false,
  String? textDirection,
  Attributes? attributes,
  Iterable<Node>? children,
}) {
  delta ??= Delta()..insert(text ?? '');
  return Node(
    type: ToggleListBlockKeys.type,
    children: children ?? [],
    attributes: {
      if (textDirection != null)
        ToggleListBlockKeys.textDirection: textDirection,
      ToggleListBlockKeys.collapsed: collapsed,
      ToggleListBlockKeys.delta: delta.toJson(),
      if (attributes != null) ...attributes,
    },
  );
}

Node toggleHeadingNode({
  int level = 1,
  String? text,
  Delta? delta,
  bool collapsed = false,
  String? textDirection,
  Attributes? attributes,
  Iterable<Node>? children,
}) {
  // only support level 1 - 6
  level = level.clamp(1, 6);
  return toggleListBlockNode(
    text: text,
    delta: delta,
    collapsed: collapsed,
    textDirection: textDirection,
    children: children,
    attributes: {
      if (attributes != null) ...attributes,
      ToggleListBlockKeys.level: level,
    },
  );
}

// defining the toggle list block menu item
SelectionMenuItem toggleListBlockItem = SelectionMenuItem.node(
  getName: LocaleKeys.document_plugins_toggleList.tr,
  iconData: Icons.arrow_right,
  keywords: ['collapsed list', 'toggle list', 'list'],
  nodeBuilder: (editorState, _) => toggleListBlockNode(),
  replace: (_, node) => node.delta?.isEmpty ?? false,
);

class ToggleListBlockComponentBuilder extends BlockComponentBuilder {
  ToggleListBlockComponentBuilder({
    super.configuration,
    this.padding = const EdgeInsets.all(0),
    this.textStyleBuilder,
  });

  final EdgeInsets padding;

  /// The text style of the toggle heading block.
  final TextStyle Function(int level)? textStyleBuilder;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return ToggleListBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      padding: padding,
      textStyleBuilder: textStyleBuilder,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(
        blockComponentContext,
        state,
      ),
      actionTrailingBuilder: (context, state) => actionTrailingBuilder(
        blockComponentContext,
        state,
      ),
    );
  }

  @override
  BlockComponentValidate get validate => (node) => node.delta != null;
}

class ToggleListBlockComponentWidget extends BlockComponentStatefulWidget {
  const ToggleListBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.padding = const EdgeInsets.all(0),
    this.textStyleBuilder,
  });

  final EdgeInsets padding;
  final TextStyle Function(int level)? textStyleBuilder;

  @override
  State<ToggleListBlockComponentWidget> createState() =>
      _ToggleListBlockComponentWidgetState();
}

class _ToggleListBlockComponentWidgetState
    extends State<ToggleListBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  // the key used to forward focus to the richtext child
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: ToggleListBlockKeys.type,
  );

  @override
  Node get node => widget.node;

  @override
  EdgeInsets get indentPadding => configuration.indentPadding(
        node,
        calculateTextDirection(
          layoutDirection: Directionality.maybeOf(context),
        ),
      );

  bool get collapsed => node.attributes[ToggleListBlockKeys.collapsed] ?? false;

  int? get level => node.attributes[ToggleListBlockKeys.level] as int?;

  @override
  Widget build(BuildContext context) {
    return collapsed
        ? buildComponent(context)
        : buildComponentWithChildren(context);
  }

  @override
  Widget buildComponentWithChildren(BuildContext context) {
    return Stack(
      children: [
        if (backgroundColor != Colors.transparent)
          Positioned.fill(
            left: cachedLeft,
            top: padding.top,
            child: Container(
              width: UniversalPlatform.isDesktop ? double.infinity : null,
              color: backgroundColor,
            ),
          ),
        Provider(
          create: (context) =>
              DatabasePluginWidgetBuilderSize(horizontalPadding: 0.0),
          child: NestedListWidget(
            indentPadding: indentPadding,
            child: buildComponent(context),
            children: editorState.renderer.buildList(
              context,
              widget.node.children,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = false,
  }) {
    Widget child = _buildToggleBlock();

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [
        BlockSelectionType.block,
      ],
      child: child,
    );

    child = Padding(
      padding: padding,
      child: Container(
        key: blockComponentKey,
        color: withBackgroundColor ||
                (backgroundColor != Colors.transparent && collapsed)
            ? backgroundColor
            : null,
        child: child,
      ),
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }

    return child;
  }

  Widget _buildToggleBlock() {
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );
    final crossAxisAlignment = textDirection == TextDirection.ltr
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end;

    return Container(
      width: double.infinity,
      alignment: alignment,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: textDirection,
            children: [
              _buildExpandIcon(),
              Flexible(
                child: _buildRichText(),
              ),
            ],
          ),
          _buildPlaceholder(),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    // if the toggle block is collapsed or it contains children, don't show the
    // placeholder.
    if (collapsed || node.children.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: UniversalPlatform.isMobile
          ? const EdgeInsets.symmetric(horizontal: 26.0)
          : indentPadding,
      child: FlowyButton(
        text: FlowyText(
          buildPlaceholderText(),
          color: Theme.of(context).hintColor,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 8),
        onTap: onAddContent,
      ),
    );
  }

  Widget _buildRichText() {
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );
    final level = node.attributes[ToggleListBlockKeys.level];
    return AppFlowyRichText(
      key: forwardKey,
      delegate: this,
      node: widget.node,
      editorState: editorState,
      placeholderText: placeholderText,
      lineHeight: 1.5,
      textSpanDecorator: (textSpan) {
        var result = textSpan.updateTextStyle(
          textStyleWithTextSpan(textSpan: textSpan),
        );
        if (level != null) {
          result = result.updateTextStyle(
            widget.textStyleBuilder?.call(level),
          );
        }
        return result;
      },
      placeholderTextSpanDecorator: (textSpan) {
        var result = textSpan.updateTextStyle(
          textStyleWithTextSpan(textSpan: textSpan),
        );
        if (level != null && widget.textStyleBuilder != null) {
          result = result.updateTextStyle(
            widget.textStyleBuilder?.call(level),
          );
        }
        return result.updateTextStyle(
          placeholderTextStyleWithTextSpan(textSpan: textSpan),
        );
      },
      textDirection: textDirection,
      textAlign: alignment?.toTextAlign ?? textAlign,
      cursorColor: editorState.editorStyle.cursorColor,
      selectionColor: editorState.editorStyle.selectionColor,
    );
  }

  Widget _buildExpandIcon() {
    double buttonHeight = UniversalPlatform.isDesktop ? 22.0 : 26.0;
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    if (level != null) {
      // top padding * 2 + button height = height of the heading text
      final textStyle = widget.textStyleBuilder?.call(level ?? 1);
      final fontSize = textStyle?.fontSize;
      final lineHeight = textStyle?.height ?? 1.5;

      if (fontSize != null) {
        buttonHeight = fontSize * lineHeight;
      }
    }

    final turns = switch (textDirection) {
      TextDirection.ltr => collapsed ? 0.0 : 0.25,
      TextDirection.rtl => collapsed ? -0.5 : -0.75,
    };

    return Container(
      constraints: BoxConstraints(
        minWidth: 26,
        minHeight: buttonHeight,
      ),
      alignment: Alignment.center,
      child: FlowyButton(
        margin: const EdgeInsets.all(2.0),
        useIntrinsicWidth: true,
        onTap: onCollapsed,
        text: AnimatedRotation(
          turns: turns,
          duration: const Duration(milliseconds: 200),
          child: const Icon(
            Icons.arrow_right,
            size: 18.0,
          ),
        ),
      ),
    );
  }

  Future<void> onCollapsed() async {
    final transaction = editorState.transaction
      ..updateNode(node, {
        ToggleListBlockKeys.collapsed: !collapsed,
      });
    transaction.afterSelection = editorState.selection;
    await editorState.apply(transaction);
  }

  Future<void> onAddContent() async {
    final transaction = editorState.transaction;
    final path = node.path.child(0);
    transaction.insertNode(
      path,
      paragraphNode(),
    );
    transaction.afterSelection = Selection.collapsed(Position(path: path));
    await editorState.apply(transaction);
  }

  String buildPlaceholderText() {
    if (level != null) {
      return LocaleKeys.document_plugins_emptyToggleHeading.tr(
        args: [level.toString()],
      );
    }
    return LocaleKeys.document_plugins_emptyToggleList.tr();
  }
}
