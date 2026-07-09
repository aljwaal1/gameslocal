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
    network/
      local_network_core.dart
      local_wifi_transport.dart
      network_message.dart
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

## ما تم إنجازه في التحديث الحالي

- إضافة طبقة Network Core داخل `lib/core/network`.
- تعريف رسائل JSON موحدة بين الألعاب.
- تعريف وضع اللاعب Host / Client.
- تجهيز حالة الغرفة واللاعبين والجاهزية.
- إضافة طبقة Wi-Fi Transport أولية عبر TCP Socket.
- تشغيل Host من غرفة اللعبة وعرض IP و Port.
- السماح للاعب الثاني بإدخال IP اللاعب الأول والاتصال عبر نفس Wi-Fi / Hotspot.
- استقبال رسالة انضمام اللاعب الثاني وتحديث قائمة اللاعبين في الغرفة.

## الخطة القادمة

1. اختبار الاتصال الفعلي عبر Wi-Fi / Hotspot على جهازين.
2. نقل حركة الضامة بين جهازين.
3. تعميم طبقة الاتصال على الدومينو.
4. إضافة الشدة / السراقة.
5. إضافة اللعب عبر الإنترنت لاحقًا بعد استقرار Wi-Fi المحلي.
