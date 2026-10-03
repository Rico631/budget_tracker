import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

/// Подменяет каталог временных файлов `path_provider`.
///
/// Приложение открывает базу через `drift_flutter`, который берет каталог
/// временных файлов из `path_provider`. В тестовом окружении плагины не
/// зарегистрированы, поэтому тесты, открывающие базу по явному пути, подменяют
/// ответ платформы. Перед подменой нужно инициализировать привязку Flutter:
/// `TestWidgetsFlutterBinding.ensureInitialized()`.
void mockTemporaryDirectoryPath(String path) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        _pathProviderChannel,
        (call) async => call.method == 'getTemporaryDirectory' ? path : null,
      );
}
