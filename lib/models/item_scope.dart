enum ItemScopeType { personal, group }

class ItemScope {
  const ItemScope._({
    required this.type,
    required this.id,
    required this.label,
  });

  const ItemScope.personal()
    : this._(type: ItemScopeType.personal, id: null, label: '내 물품');

  const ItemScope.group({required String id, required String label})
    : this._(type: ItemScopeType.group, id: id, label: label);

  final ItemScopeType type;
  final String? id;
  final String label;

  bool get isPersonal => type == ItemScopeType.personal;
  bool get isGroup => type == ItemScopeType.group;

  String get storageKey {
    return switch (type) {
      ItemScopeType.personal => 'personal',
      ItemScopeType.group => 'group:$id',
    };
  }

  @override
  bool operator ==(Object other) {
    return other is ItemScope &&
        other.type == type &&
        other.id == id &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(type, id, label);
}
