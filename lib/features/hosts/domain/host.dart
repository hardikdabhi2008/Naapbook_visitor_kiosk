class Host {
  const Host({
    required this.id,
    required this.name,
    required this.designation,
    required this.department,
    required this.floor,
    required this.email,
    required this.available,
  });

  final String id;
  final String name;
  final String designation;
  final String department;
  final String floor;
  final String email;
  final bool available;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join().toUpperCase();
  }
}

abstract interface class HostRepository {
  Future<List<Host>> fetchHosts();
}
