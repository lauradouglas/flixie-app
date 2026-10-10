String? showImageUrl(String? path, String size) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  return 'https://image.tmdb.org/t/p/$size$path';
}
