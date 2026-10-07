/// Роль пользователя с уровнем доступа.
/// Уровень (level) позволяет сравнивать «не ниже чем».
enum Role {
  client(1, 'Покупатель'),
  manager(2, 'Менеджер'),
  admin(3, 'Администратор');

  final int level;
  final String label;
  const Role(this.level, this.label);

  /// Роль не ниже указанной.
  bool allows(Role min) => level >= min.level;

  /// Разбор роли из строки, пришедшей с сервера.
  static Role parse(String? raw) => switch (raw) {
    'admin' => Role.admin,
    'manager' => Role.manager,
    _ => Role.client,
  };

  String get wire => name; // 'client' / 'manager' / 'admin'
}