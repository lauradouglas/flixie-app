class WatchProvider {
  final String logoPath;
  final int providerId;
  final String providerName;
  final int displayPriority;

  const WatchProvider({
    required this.logoPath,
    required this.providerId,
    required this.providerName,
    required this.displayPriority,
  });

  factory WatchProvider.fromJson(Map<String, dynamic> json) {
    return WatchProvider(
      logoPath: json['logoPath'] as String,
      providerId: json['providerId'] is int
          ? json['providerId']
          : int.parse(json['providerId'].toString()),
      providerName: json['providerName'] as String,
      displayPriority: json['displayPriority'] is int
          ? json['displayPriority']
          : int.parse(json['displayPriority'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'logoPath': logoPath,
      'providerId': providerId,
      'providerName': providerName,
      'displayPriority': displayPriority,
    };
  }
}
