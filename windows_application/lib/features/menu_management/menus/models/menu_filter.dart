class MenuFilter {
  const MenuFilter({
    this.search = '',
    this.status = 'all',
    this.sort = 'priority',
    this.direction = 'asc',
  });
  final String search, status, sort, direction;
  bool get hasActiveFilters =>
      search.isNotEmpty ||
      status != 'all' ||
      sort != 'priority' ||
      direction != 'asc';
  MenuFilter copyWith({
    String? search,
    String? status,
    String? sort,
    String? direction,
  }) => MenuFilter(
    search: search ?? this.search,
    status: status ?? this.status,
    sort: sort ?? this.sort,
    direction: direction ?? this.direction,
  );
}
