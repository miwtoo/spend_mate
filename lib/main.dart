import 'package:flutter/material.dart';
import 'package:spend_mate/data/repositories/ai_provider_config_repository.dart';
import 'package:spend_mate/data/repositories/firefly_config_repository.dart';
import 'package:spend_mate/ui/home/home_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spend Mate',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AppBootstrap(),
    );
  }
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        AiProviderConfigRepository.create(),
        FireflyConfigRepository.create(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Text('Failed to start app: ${snapshot.error}'),
            ),
          );
        }

        final configRepo = snapshot.data![0] as AiProviderConfigRepository;
        final fireflyConfigRepo = snapshot.data![1] as FireflyConfigRepository;

        return HomeScreen(
          configRepository: configRepo,
          fireflyConfigRepository: fireflyConfigRepo,
        );
      },
    );
  }
}
