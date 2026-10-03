import 'package:budget_tracker/core/di/app_lifecycle_providers.dart';
import 'package:budget_tracker/domain/repositories/database_registry.dart';
import 'package:budget_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Корень приложения: открывает активную базу из реестра и владеет контейнером
/// провайдеров.
///
/// По команде мягкого перезапуска контейнер освобождается (существующий
/// `ref.onDispose(database.close)` закрывает соединение с прежней базой) и
/// создается заново с базой по новому активному пути. Пересоздание контейнера, а
/// не инвалидация провайдеров, гарантирует, что закэшированное состояние прежней
/// базы не переживет переключение (ADR-0006, решение 6.6).
class AppRoot extends StatefulWidget {
  const AppRoot({
    super.key,
    required this.registry,
    this.locale,
    this.overrides = const [],
  });

  /// Реестр баз: подменяется в тестах, чтобы не обращаться к платформе.
  final DatabaseRegistry registry;

  /// Явная локаль приложения: используется тестами.
  final Locale? locale;

  /// Дополнительные переопределения провайдеров для тестов.
  ///
  /// Тесты подменяют соединение с базой: приложение открывает базу через
  /// `drift_flutter` в фоновом изоляте, который не работает в тестовом
  /// окружении. Разрешение пути активной базы и пересоздание контейнера при
  /// этом проверяются как в приложении.
  final List<Override> overrides;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late Future<String?> _activePath;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _activePath = _resolveActiveDatabasePath();
  }

  /// Читает путь активной базы до создания контейнера.
  ///
  /// Недоступный реестр не мешает запуску: приложение открывает базу по
  /// дефолтному пути, а о неудачной инициализации сообщает экран начальной
  /// загрузки.
  Future<String?> _resolveActiveDatabasePath() async {
    final registry = widget.registry;
    try {
      final state = await registry.load();
      return await registry.pathOf(state.activeEntry.fileName);
    } on Exception {
      return null;
    }
  }

  void _restart() {
    setState(() {
      _generation++;
      _activePath = _resolveActiveDatabasePath();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _activePath,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupView();
        }

        return ProviderScope(
          key: ValueKey(_generation),
          overrides: [
            ...widget.overrides,
            activeDatabasePathProvider.overrideWithValue(snapshot.data),
            appRestartProvider.overrideWithValue(_restart),
          ],
          child: BudgetTrackerApp(locale: widget.locale),
        );
      },
    );
  }
}

/// Экран начальной загрузки: показывается, пока читается активная база.
class _StartupView extends StatelessWidget {
  const _StartupView();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
