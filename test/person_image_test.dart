import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/person.dart';

void main() {
  test('person images parse and build thumbnail and original URLs', () {
    final image = PersonImage.fromJson({
      'personId': 42,
      'aspectRatio': 0.667,
      'imageUrl': '/profile.jpg',
      'imageType': 'profile',
    });

    expect(image.personId, 42);
    expect(image.thumbnailUrl, 'https://image.tmdb.org/t/p/w500/profile.jpg');
    expect(
      image.originalUrl,
      'https://image.tmdb.org/t/p/original/profile.jpg',
    );
  });
}
