# GamesLocal Internet Relay

خادم WebSocket صغير لا ينفذ قوانين الألعاب؛ يخصص رمز غرفة وينقل رسائل
`NetworkMessage` بين الأجهزة فقط. تبقى صحة الحركة والدور والنتيجة داخل تطبيق
GamesLocal.

## التشغيل

```bash
PORT=8080 dart run server.dart
```

نقطة WebSocket هي `/ws` وفحص الصحة هو `/health`. بعد نشر الخادم خلف HTTPS،
ابنِ التطبيق بعنوان `wss`:

```bash
flutter build apk --release \
  --dart-define=INTERNET_RELAY_URL=wss://games.example.com/ws
```

الخادم يحد الغرفة إلى 12 جهازًا، الرسالة إلى 64KB، ومعدل العميل إلى 60 رسالة
في الثانية. الغرف غير النشطة تنتهي خلال ست ساعات وتغلق عند خروج الداعي.
