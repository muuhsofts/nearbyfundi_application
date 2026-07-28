class PortfolioItem {
  final int id;
  final String image;
  final String? description;
  final DateTime? createdAt;
  final String? instagram;
  final String? facebook;
  final String? tiktok;
  final String? twitter;
  final String? telegram;

  PortfolioItem({
    required this.id,
    required this.image,
    this.description,
    this.createdAt,
    this.instagram,
    this.facebook,
    this.tiktok,
    this.twitter,
    this.telegram,
  });

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return PortfolioItem(
      id: data['id'] ?? 0,
      image: data['image'] ?? '',
      description: data['description'],
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : null,
      instagram: data['instagram'] ?? data['social_links']?['instagram'],
      facebook: data['facebook'] ?? data['social_links']?['facebook'],
      tiktok: data['tiktok'] ?? data['social_links']?['tiktok'],
      twitter: data['twitter'] ?? data['social_links']?['twitter'],
      telegram: data['telegram'] ?? data['social_links']?['telegram'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'image': image,
    'description': description,
    'created_at': createdAt?.toIso8601String(),
    'instagram': instagram,
    'facebook': facebook,
    'tiktok': tiktok,
    'twitter': twitter,
    'telegram': telegram,
  };
}