// lib/models/portfolio.dart

class PortfolioItem {
  final int id;
  final String image;
  final String? description;
  final DateTime? createdAt;  // ✅ ADD THIS

  PortfolioItem({
    required this.id,
    required this.image,
    this.description,
    this.createdAt,
  });

  factory PortfolioItem.fromJson(Map<String, dynamic> json) => PortfolioItem(
    id: json['id'] ?? 0,
    image: json['image'] ?? '',
    description: json['description'],
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'image': image,
    'description': description,
    'created_at': createdAt?.toIso8601String(),
  };
}