class Task {
  String id;
  String title;
  String description;
  DateTime date;
  bool completed;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.completed = false,
  });

  Map<String, dynamic> toMap(String userId) => {
    'userId': userId,
    'title': title,
    'description': description,
    'date': date.toIso8601String(),
    'completed': completed,
    'createdAt': DateTime.now().toIso8601String(),
  };

  factory Task.fromMap(String id, Map<String, dynamic> map) => Task(
    id: id,
    title: map['title'],
    description: map['description'],
    date: DateTime.parse(map['date']),
    completed: map['completed'],
  );
}
