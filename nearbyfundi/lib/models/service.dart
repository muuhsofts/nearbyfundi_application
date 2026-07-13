class Service {
  final int id;
  final String name;
  Service({required this.id, required this.name});
  factory Service.fromJson(Map<String, dynamic> json) => Service(
    id: json['id'],
    name: json['name'],
  );
}