class RemarkModel {
  const RemarkModel({
    required this.id,
    required this.leadId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String leadId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;

  RemarkModel copyWith({
    String? id,
    String? leadId,
    String? authorId,
    String? authorName,
    String? text,
    DateTime? createdAt,
  }) {
    return RemarkModel(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
