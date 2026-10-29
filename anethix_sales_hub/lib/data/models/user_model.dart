import '../../shared/models/enums.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.joinDate,
    required this.createdAt,
    required this.updatedAt,
    this.managerId,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? managerId;
  final bool isActive;
  final DateTime joinDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? avatarUrl;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    Object? managerId = _sentinel,
    bool? isActive,
    DateTime? joinDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? avatarUrl = _sentinel,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      managerId:
          managerId == _sentinel ? this.managerId : managerId as String?,
      isActive: isActive ?? this.isActive,
      joinDate: joinDate ?? this.joinDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      avatarUrl: avatarUrl == _sentinel ? this.avatarUrl : avatarUrl as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UserModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

const Object _sentinel = Object();
