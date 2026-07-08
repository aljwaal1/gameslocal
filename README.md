# Games Local

تطبيق ألعاب محلية للأندرويد مبني بـ Flutter.

## الفكرة

كل لعبة داخل مجلد مستقل حتى نستطيع تعديل كل لعبة لوحدها بدون التأثير على باقي الألعاب.

## الهيكل

```text
lib/
  core/
    game_definition.dart
    game_room.dart
  games/
    checkers/
      checkers_game.dart
    chess/
      chess_placeholder.dart
    domino/
      domino_placeholder.dart
    cards/
      cards_placeholder.dart
```

## النسخة الحالية V1

- واجهة عربية RTL.
- قائمة ألعاب: الضامة، الشطرنج، الدومينو، الشدة / السراقة.
- غرفة مشتركة قبل الدخول للعبة.
- لعبة الضامة تعمل محليًا على نفس الجهاز كبداية.
- باقي الألعاب لها مجلدات مستقلة جاهزة للتطوير.
- GitHub Actions يبني APK مباشر في `apk/gameslocal.apk`.

## الخطة القادمة

1. تثبيت قواعد الضامة أكثر.
2. إضافة Wi-Fi / Hotspot بين جهازين.
3. نقل حركة الضامة بين جهازين.
4. إضافة الدومينو.
5. إضافة الشدة / السراقة.
6. إضافة Bluetooth كطبقة اتصال ثانية.
