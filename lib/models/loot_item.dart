class LootItem {
  final String name;

  const LootItem({required this.name});

  static LootItem findById(String id) {
    if (id.isEmpty) return const LootItem(name: '');
    // Replace underscores with spaces and Title Case each word
    final String name = id
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
    return LootItem(name: name);
  }
}
