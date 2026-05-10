class TripModel {
  final int id;
  final String title;
  final String? description;
  final String startDate;
  final String endDate;
  final bool isPublic;
  final double? totalBudget;
  final int stopCount;

  TripModel({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    this.isPublic = false,
    this.totalBudget,
    this.stopCount = 0,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) => TripModel(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        startDate: json['start_date'],
        endDate: json['end_date'],
        isPublic: json['is_public'] ?? false,
        totalBudget: (json['total_budget'] as num?)?.toDouble(),
        stopCount: json['stop_count'] ?? 0,
      );
}