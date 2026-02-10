class LootItem {
  final String name;

  const LootItem({
    required this.name,
  });

  static LootItem findById(String id) {
    if (id.isEmpty) return const LootItem(name: '');
    // Title Case: Capital first, lowercase rest
    final String name = id[0].toUpperCase() + id.substring(1).toLowerCase();
    return LootItem(name: name);
  }
}

