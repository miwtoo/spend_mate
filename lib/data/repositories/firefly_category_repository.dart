import 'package:spend_mate/config/firefly_config.dart';
import 'package:spend_mate/data/repositories/firefly_config_repository.dart';
import 'package:spend_mate/data/services/firefly/firefly_api_service.dart';
import 'package:spend_mate/domain/models/firefly_category.dart';

class FireflyCategoryRepository {
  FireflyCategoryRepository({
    required FireflyConfigRepository configRepository,
    required FireflyApiService apiService,
  })  : _configRepository = configRepository,
        _apiService = apiService;

  final FireflyConfigRepository _configRepository;
  final FireflyApiService _apiService;

  Future<List<FireflyCategory>> listCategories() async {
    final config = await _configRepository.load();
    _validateConfig(config);
    return _apiService.listCategories(config: config);
  }

  Future<FireflyCategory> createCategory(String name) async {
    final config = await _configRepository.load();
    _validateConfig(config);
    return _apiService.createCategory(config: config, name: name);
  }

  void _validateConfig(FireflyConfig config) {
    if (!config.hasCredentials) {
      throw Exception('Firefly connection is not configured.');
    }
  }
}
