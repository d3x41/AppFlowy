import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database/application/field/field_controller.dart';
import 'package:appflowy/plugins/database/domain/field_service.dart';
import 'package:appflowy/plugins/database/grid/application/grid_bloc.dart';
import 'package:appflowy/plugins/database/grid/application/grid_header_bloc.dart';
import 'package:appflowy/plugins/database/tab_bar/tab_bar_view.dart';
import 'package:appflowy_backend/log.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reorderables/reorderables.dart';
import 'package:universal_platform/universal_platform.dart';

import '../../layout/sizes.dart';
import 'desktop_field_cell.dart';

class GridHeaderSliverAdaptor extends StatefulWidget {
  const GridHeaderSliverAdaptor({
    super.key,
    required this.viewId,
    required this.shrinkWrap,
    required this.anchorScrollController,
  });

  final String viewId;
  final ScrollController anchorScrollController;
  final bool shrinkWrap;

  @override
  State<GridHeaderSliverAdaptor> createState() =>
      _GridHeaderSliverAdaptorState();
}

class _GridHeaderSliverAdaptorState extends State<GridHeaderSliverAdaptor> {
  @override
  Widget build(BuildContext context) {
    final fieldController =
        context.read<GridBloc>().databaseController.fieldController;
    final databaseSize = context.read<DatabasePluginWidgetBuilderSize?>();
    final horizontalPadding = databaseSize?.horizontalPadding ?? 0.0;
    final paddingLeft = databaseSize?.paddingLeftWithMaxDocumentWidth ?? 0.0;
    return BlocProvider(
      create: (context) {
        return GridHeaderBloc(
          viewId: widget.viewId,
          fieldController: fieldController,
        )..add(const GridHeaderEvent.initial());
      },
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: widget.anchorScrollController,
        child: Padding(
          padding: widget.shrinkWrap
              ? EdgeInsets.fromLTRB(
                  horizontalPadding + paddingLeft,
                  0,
                  horizontalPadding,
                  0,
                )
              : EdgeInsets.zero,
          child: _GridHeader(
            viewId: widget.viewId,
            fieldController: fieldController,
          ),
        ),
      ),
    );
  }
}

class _GridHeader extends StatefulWidget {
  const _GridHeader({required this.viewId, required this.fieldController});

  final String viewId;
  final FieldController fieldController;

  @override
  State<_GridHeader> createState() => _GridHeaderState();
}

class _GridHeaderState extends State<_GridHeader> {
  final Map<String, ValueKey<String>> _gridMap = {};
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GridHeaderBloc, GridHeaderState>(
      builder: (context, state) {
        final cells = state.fields
            .map(
              (fieldInfo) => GridFieldCell(
                key: _getKeyById(fieldInfo.id),
                viewId: widget.viewId,
                fieldInfo: fieldInfo,
                fieldController: widget.fieldController,
                onTap: () => context
                    .read<GridHeaderBloc>()
                    .add(GridHeaderEvent.startEditingField(fieldInfo.id)),
                onFieldInsertedOnEitherSide: (fieldId) => context
                    .read<GridHeaderBloc>()
                    .add(GridHeaderEvent.startEditingNewField(fieldId)),
                onEditorOpened: () => context
                    .read<GridHeaderBloc>()
                    .add(const GridHeaderEvent.endEditingField()),
                isEditing: state.editingFieldId == fieldInfo.id,
                isNew: state.newFieldId == fieldInfo.id,
              ),
            )
            .toList();

        return RepaintBoundary(
          child: ReorderableRow(
            scrollController: _scrollController,
            buildDraggableFeedback: (context, constraints, child) => Material(
              color: Colors.transparent,
              child: child,
            ),
            draggingWidgetOpacity: 0,
            header: _cellLeading(),
            needsLongPressDraggable: UniversalPlatform.isMobile,
            footer: _CellTrailing(viewId: widget.viewId),
            onReorder: (int oldIndex, int newIndex) {
              context
                  .read<GridHeaderBloc>()
                  .add(GridHeaderEvent.moveField(oldIndex, newIndex));
            },
            children: cells,
          ),
        );
      },
    );
  }

  /// This is a workaround for [ReorderableRow].
  /// [ReorderableRow] warps the child's key with a [GlobalKey].
  /// It will trigger the child's widget's to recreate.
  /// The state will lose.
  ValueKey<String>? _getKeyById(String id) {
    if (_gridMap.containsKey(id)) {
      return _gridMap[id];
    }
    final newKey = ValueKey(id);
    _gridMap[id] = newKey;
    return newKey;
  }

  Widget _cellLeading() {
    return SizedBox(
      width: context.read<DatabasePluginWidgetBuilderSize>().horizontalPadding,
    );
  }
}

class _CellTrailing extends StatelessWidget {
  const _CellTrailing({required this.viewId});

  final String viewId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: GridSize.newPropertyButtonWidth,
      height: GridSize.headerHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AFThemeExtension.of(context).borderColor),
        ),
      ),
      child: CreateFieldButton(
        viewId: viewId,
        onFieldCreated: (fieldId) => context
            .read<GridHeaderBloc>()
            .add(GridHeaderEvent.startEditingNewField(fieldId)),
      ),
    );
  }
}

class CreateFieldButton extends StatelessWidget {
  const CreateFieldButton({
    super.key,
    required this.viewId,
    required this.onFieldCreated,
  });

  final String viewId;
  final void Function(String fieldId) onFieldCreated;

  @override
  Widget build(BuildContext context) {
    return FlowyButton(
      margin: GridSize.cellContentInsets,
      radius: BorderRadius.zero,
      text: FlowyText(
        lineHeight: 1.0,
        LocaleKeys.grid_field_newProperty.tr(),
        overflow: TextOverflow.ellipsis,
      ),
      hoverColor: AFThemeExtension.of(context).greyHover,
      onTap: () async {
        final result = await FieldBackendService.createField(
          viewId: viewId,
        );
        result.fold(
          (field) => onFieldCreated(field.id),
          (err) => Log.error("Failed to create field type option: $err"),
        );
      },
      leftIcon: const FlowySvg(
        FlowySvgs.add_less_padding_s,
        size: Size.square(16),
      ),
    );
  }
}
