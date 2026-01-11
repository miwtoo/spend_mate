import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spend_mate/config/ai_provider.dart';
import 'package:spend_mate/config/ai_provider_config.dart';
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads defaults when nothing is stored', () async {
    final repo = await AiProviderConfigRepository.create();
    final config = await repo.load();

    expect(config.provider, AiProvider.openAiCompatible);
    expect(config.baseUrl, 'https://api.openai.com');
    expect(config.apiKey, '');
    expect(config.model, 'gpt-4o-mini');
    expect(config.visionModel, 'gpt-4o-mini');
  });

  test('saves and reloads config', () async {
    final repo = await AiProviderConfigRepository.create();

    const config = AiProviderConfig(
      provider: AiProvider.gemini,
      baseUrl: 'https://generativelanguage.googleapis.com',
      apiKey: 'abc123',
      model: 'gemini-1.5-flash',
      visionModel: 'gemini-1.5-flash',
    );

    await repo.save(config);
    final loaded = await repo.load();

    expect(loaded.provider, AiProvider.gemini);
    expect(loaded.baseUrl, config.baseUrl);
    expect(loaded.apiKey, config.apiKey);
    expect(loaded.model, config.model);
    expect(loaded.visionModel, config.visionModel);
  });
}
