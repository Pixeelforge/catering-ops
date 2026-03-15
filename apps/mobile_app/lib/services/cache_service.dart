import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static const String _boxName = 'app_cache';
  static late Box _box;
  static bool _isInitialized = false;

  /// Initialize Hive and open the cache box
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);
      _isInitialized = true;
      debugPrint('📦 CacheService: Initialized successfully');
    } catch (e) {
      debugPrint('📦 CacheService Error: Failed to initialize Hive: $e');
    }
  }

  /// Save data to cache (automatically serializes to JSON)
  static Future<void> save(String key, dynamic data) async {
    if (!_isInitialized) {
      debugPrint('📦 CacheService Warning: save() called before init()');
      return;
    }
    try {
      await _box.put(key, data);
      debugPrint('📦 CacheService: Saved data for key: $key');
    } catch (e) {
      debugPrint('📦 CacheService Error: Failed to save data: $e');
    }
  }

  /// Retrieve data from cache
  static dynamic get(String key) {
    if (!_isInitialized) {
      debugPrint('📦 CacheService Warning: get() called before init()');
      return null;
    }
    try {
      final data = _box.get(key);
      if (data != null) {
        debugPrint('📦 CacheService: Retrieved data for key: $key');
      }
      return data;
    } catch (e) {
      debugPrint('📦 CacheService Error: Failed to retrieve data: $e');
      return null;
    }
  }

  /// Check if data exists for a key
  static bool has(String key) {
    if (!_isInitialized) return false;
    return _box.containsKey(key);
  }

  /// Clear specific cache key or entire box
  static Future<void> clear({String? key}) async {
    if (!_isInitialized) return;
    try {
      if (key != null) {
        await _box.delete(key);
      } else {
        await _box.clear();
      }
      debugPrint('📦 CacheService: Cleared cache ${key ?? "completely"}');
    } catch (e) {
      debugPrint('📦 CacheService Error: Failed to clear cache: $e');
    }
  }
}
