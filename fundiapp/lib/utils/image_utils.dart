// lib/utils/image_utils.dart

import '../config/app_config.dart';

class ImageUtils {
  static String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    final base = AppConfig.baseUrl.replaceFirst('/api', '');
    if (path.startsWith('/')) path = path.substring(1);

    // All storage paths are under /storage/ (thanks to the symlink)
    return '$base/storage/$path';
  }
}