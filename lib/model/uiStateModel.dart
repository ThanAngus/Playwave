import '../utils/constants/enumConstants.dart';

class UIState {
  final ViewType viewType;
  final SortBy sortBy;
  final OrderBy orderBy;
  final LayoutType layoutType;

  const UIState({
    this.viewType = ViewType.listView,
    this.sortBy = SortBy.name,
    this.orderBy = OrderBy.ascending,
    this.layoutType = LayoutType.folderView,
  });
}