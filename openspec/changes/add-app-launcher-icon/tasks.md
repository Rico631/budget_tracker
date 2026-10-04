# Tasks

## 1. Изображения знака

- [x] 1.1 Создать квадратный мастер `assets/icon/app_icon.png` (1024×1024): обрезать `assets/icon/icon.png` до квадрата по видимым границам знака (порог alpha > 32, центр знака) и масштабировать с сохранением пропорций; проверить, что знак не обрезан и занимает кадр без полей.
- [x] 1.2 Создать передний план адаптивной иконки `assets/icon/app_icon_foreground.png` (1024×1024): знак стороной 440 px по центру прозрачного кадра; проверить, что диагональ знака не превышает гарантированную зону 66dp из 108dp и знак не касается краев кадра.
- [x] 1.3 Проверить, что исходный экспорт `assets/icon/icon.png` сохранен без изменений (768×1152 RGBA) и остается в репозитории как первоисточник знака.

## 2. Конфигурация генерации

- [x] 2.1 Добавить `flutter_launcher_icons` в `dev_dependencies` файла `pubspec.yaml` с указанием причины зависимости (решение 3 design.md); проверить, что `flutter pub get` проходит.
- [x] 2.2 Добавить раздел `flutter_launcher_icons` в `pubspec.yaml`: мастер как источник, Android с адаптивной иконкой (сплошной фон `#FFFFFF`, передний план, `adaptive_icon_foreground_inset: 0`), web (favicon, PWA-иконки, цвета манифеста) и Windows (ICO 256 px).
- [x] 2.3 Проверить, что каталог `assets/icon` не добавлен в раздел `flutter: assets:` и не попадает в ресурсы приложения (решение 6 design.md).
- [x] 2.4 Проверить, что решение не требует новой ADR и не переписывает ADR-0001 (решение 9.1 об акценте сохраняется).

## 3. Ресурсы платформ

- [x] 3.1 Выполнить `dart run flutter_launcher_icons`; проверить, что команда завершается без ошибок и создает иконки Android, web и Windows.
- [x] 3.2 Проверить ресурсы Android: `mipmap-mdpi`-`mipmap-xxxhdpi/ic_launcher.png` (48, 72, 96, 144, 192 px), `drawable-mdpi`-`drawable-xxxhdpi/ic_launcher_foreground.png` (108, 162, 216, 324, 432 px), `mipmap-anydpi-v26/ic_launcher.xml` со ссылками на `@color/ic_launcher_background` и `@drawable/ic_launcher_foreground` при `inset="0%"`, `values/colors.xml` с `ic_launcher_background = #FFFFFF`.
- [x] 3.3 Проверить ресурсы web и Windows: `web/icons/Icon-192.png`, `Icon-512.png`, `Icon-maskable-192.png`, `Icon-maskable-512.png`, `web/favicon.png`, `windows/runner/resources/app_icon.ico`.
- [x] 3.4 Проверить `web/manifest.json`: `background_color` и `theme_color` обновлены решением 7 design.md, состав и имена иконок не изменились, остальные поля не затронуты.

## 4. Проверка результата

- [x] 4.1 Собрать `flutter build apk --debug` и убедиться, что ресурсы иконок проходят сборку Android, а адаптивная иконка и `values/colors.xml` принимаются без ошибок.
- [x] 4.2 Проверить, что в собранном APK присутствуют сгенерированные `ic_launcher` и `ic_launcher_foreground` вместо ресурсов шаблона Flutter.
- [x] 4.3 Проверить моделированием маски, что при круглой маске диаметром 72dp знак и его содержимое целиком попадают в гарантированную зону и не срезаются.
- [x] 4.4 Запустить `flutter analyze` и убедиться, что новых предупреждений не появилось.
