class Announcement {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final bool isRead;
  final String? imageUrl;

  Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    this.isRead = false,
    this.imageUrl,
  });

  Announcement copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    bool? isRead,
    String? imageUrl,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
