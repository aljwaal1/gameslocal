# خريطة الفروع وطلبات السحب

جرد بتاريخ 2026-11-13: **73 فرعًا** و**5 طلبات سحب مفتوحة**.
مرجع المقارنة: `896759a18ad94be67bd1cb0e83099e1dd6aa4d29` على فرع التطوير الحالي.

- فرع عمل حالي واحد: `feature/world-class-ui-v2`.
- فرع أساسي واحد: `main`.
- 23 فرعًا تاريخها محتوى بالكامل في فرع التطوير (GitHub compare: behind، ahead_by=0).
- 48 فرعًا متباعدًا لها التزامات غير محتواة فيه. هذا لا يثبت اختلاف السلوك؛ قد تتكرر تعديلات بصيغة squash أو cherry-pick.
- لم يُحذف أي فرع في هذه الجولة. الفروع المحتواة مرشحة لتنظيف لاحق بعد التحقق من تبعياتها وبقاء رؤوسها محفوظة؛ الفروع المتباعدة تحتاج مراجعة فروق قبل أي حذف.

## طلبات السحب المفتوحة

| الطلب | الفرع | وضعه في الخطة |
| --- | --- | --- |
| [#67](https://github.com/aljwaal1/gameslocal/pull/67) | `feature/world-class-ui-system` | عمل سابق مستقل؛ لا يُدمج تلقائيًا مع التحديث الحالي |
| [#66](https://github.com/aljwaal1/gameslocal/pull/66) | `feature/world-class-ui-v2` | طلب التطوير الحالي؛ ينتظر تجربة APK |
| [#49](https://github.com/aljwaal1/gameslocal/pull/49) | `hotfix/procedural-professional-penalty` | عمل سابق مستقل؛ لا يُدمج تلقائيًا مع التحديث الحالي |
| [#36](https://github.com/aljwaal1/gameslocal/pull/36) | `fix/chicken-empty-round-accuracy` | عمل سابق مستقل؛ لا يُدمج تلقائيًا مع التحديث الحالي |
| [#29](https://github.com/aljwaal1/gameslocal/pull/29) | `agent/battle-validate-current-comparison-20260711` | عمل سابق مستقل؛ لا يُدمج تلقائيًا مع التحديث الحالي |

## سجل الفروع

كل SHA رابط دائم لتسهيل الرجوع إلى اللقطة المفحوصة. «التزامات إضافية» محسوبة مقابل مرجع المقارنة أعلاه.

| الفرع | التصنيف | التزامات إضافية | الرأس وقت الجرد |
| --- | --- | ---: | --- |
| `agent/add-name-animal-object-game` | محتوى بالكامل؛ تاريخي | 0 | [e4f43123](https://github.com/aljwaal1/gameslocal/commit/e4f43123065a6542fa404af4403978c3fcbac873) |
| `agent/battle-boundary-decisions-20260711` | متباعد؛ يحتاج مراجعة | 2 | [42d8fb35](https://github.com/aljwaal1/gameslocal/commit/42d8fb35cc970cd104fdd3d88565dc3e00a8dbf3) |
| `agent/battle-critical-pickup-priority` | متباعد؛ يحتاج مراجعة | 2 | [1c0bfa65](https://github.com/aljwaal1/gameslocal/commit/1c0bfa65760b0772235ef6831af644a1282356f9) |
| `agent/battle-finite-pickup-distance-20260712` | متباعد؛ يحتاج مراجعة | 2 | [18405bfa](https://github.com/aljwaal1/gameslocal/commit/18405bfaf9ab5bbfe37138b2aa2cd0fa80b9a307) |
| `agent/battle-ignore-hidden-pickup-distance` | متباعد؛ يحتاج مراجعة | 2 | [899f4c01](https://github.com/aljwaal1/gameslocal/commit/899f4c013209ff19f13e6252a11f28ed20364bad) |
| `agent/battle-quick-match-roll-validation-20260711` | متباعد؛ يحتاج مراجعة | 2 | [21ba4dfb](https://github.com/aljwaal1/gameslocal/commit/21ba4dfbc38bcf7454bfccb8562ab9e192d3842c) |
| `agent/battle-quick-match-variety-20260711` | متباعد؛ يحتاج مراجعة | 3 | [3b49e101](https://github.com/aljwaal1/gameslocal/commit/3b49e101d41486ca6e4c240a4e69f2dfc9a50636) |
| `agent/battle-validate-current-comparison-20260711` | متباعد؛ يحتاج مراجعة | 2 | [bbab46b0](https://github.com/aljwaal1/gameslocal/commit/bbab46b0cdc39e7088dd1030fab45c24636c748d) |
| `agent/battle-validate-strategy-inputs-20260711` | متباعد؛ يحتاج مراجعة | 2 | [31e99065](https://github.com/aljwaal1/gameslocal/commit/31e99065d17ab0c009fa85eb6554ce4f571e4ddf) |
| `agent/checkers-arabic-piece-counts-20260711` | متباعد؛ يحتاج مراجعة | 2 | [1d333152](https://github.com/aljwaal1/gameslocal/commit/1d3331528b271effd42878fd5eef18895c5ca1b7) |
| `agent/checkers-capture-count-wording-20260711` | متباعد؛ يحتاج مراجعة | 1 | [5b7ad58e](https://github.com/aljwaal1/gameslocal/commit/5b7ad58e3d1fc56ea15c4c3475e535bc30b0be55) |
| `agent/chicken-achievement-validation-20260711` | متباعد؛ يحتاج مراجعة | 2 | [e2b1b48e](https://github.com/aljwaal1/gameslocal/commit/e2b1b48ee89eeed375e3b4d67256cab054049bb7) |
| `agent/chicken-master-score-achievement` | متباعد؛ يحتاج مراجعة | 2 | [cdbfe2f1](https://github.com/aljwaal1/gameslocal/commit/cdbfe2f1ddb4f1ec97246277267a2a473260a17d) |
| `agent/chicken-perfect-round-20260711` | متباعد؛ يحتاج مراجعة | 2 | [c0e97cc7](https://github.com/aljwaal1/gameslocal/commit/c0e97cc70b57d10d789662332e9dd2b2b8767109) |
| `agent/domino-reject-duplicate-tiles` | متباعد؛ يحتاج مراجعة | 2 | [e0703ee1](https://github.com/aljwaal1/gameslocal/commit/e0703ee150bd16cc9bdaf202b6f81a2f3ad7505f) |
| `agent/domino-standard-pip-validation` | متباعد؛ يحتاج مراجعة | 2 | [9c9cdd4c](https://github.com/aljwaal1/gameslocal/commit/9c9cdd4c3b006419b4cf7d551bcd7700e2527822) |
| `agent/domino-starting-player-20260711` | متباعد؛ يحتاج مراجعة | 3 | [9fd95d54](https://github.com/aljwaal1/gameslocal/commit/9fd95d54f65cc8684986c18429456ee6d8ed0079) |
| `agent/host-is-player-min-two` | متباعد؛ يحتاج مراجعة | 1 | [a99fcf38](https://github.com/aljwaal1/gameslocal/commit/a99fcf38f2e9382100d55eea5c804786f3b19ca8) |
| `automation/accurate-battle-home-card` | محتوى بالكامل؛ تاريخي | 0 | [34c0c96d](https://github.com/aljwaal1/gameslocal/commit/34c0c96d8f8e70addd0063ccb391dea34ca6eac9) |
| `automation/battle-choice-validation-20260711` | متباعد؛ يحتاج مراجعة | 2 | [ac2c539f](https://github.com/aljwaal1/gameslocal/commit/ac2c539ff1350e117eb6a7b12cdacbb48a533c37) |
| `automation/battle-quick-match-always-new-character-20260711` | متباعد؛ يحتاج مراجعة | 8 | [82e69ba9](https://github.com/aljwaal1/gameslocal/commit/82e69ba92107384a0d16da688186746131397026) |
| `automation/battle-quick-match-balanced-alternatives-20260711` | متباعد؛ يحتاج مراجعة | 2 | [eae6727d](https://github.com/aljwaal1/gameslocal/commit/eae6727da9f51e3a171a1ecab5056c3e57ddf414) |
| `automation/battle-quick-match-current-selection-validation-20260711` | محتوى بالكامل؛ تاريخي | 0 | [1503a617](https://github.com/aljwaal1/gameslocal/commit/1503a617a410837c700317a76c829652d598c2bd) |
| `automation/battle-quick-match-invariant-20260711` | متباعد؛ يحتاج مراجعة | 1 | [2ea26d79](https://github.com/aljwaal1/gameslocal/commit/2ea26d794ea315dd5f73ac021dc085f887bccfc0) |
| `automation/battle-quick-match-roll-validation-20260711` | متباعد؛ يحتاج مراجعة | 2 | [b1ba11a3](https://github.com/aljwaal1/gameslocal/commit/b1ba11a3ed69fc3ac346db7867e01b93531ef151) |
| `automation/battle-quick-match-single-character-variety-20260711` | متباعد؛ يحتاج مراجعة | 2 | [cd17006b](https://github.com/aljwaal1/gameslocal/commit/cd17006b522621e19ff29557d4d1c783c07bba3d) |
| `automation/battle-quick-match-uniform-random-20260711` | متباعد؛ يحتاج مراجعة | 1 | [abca98e4](https://github.com/aljwaal1/gameslocal/commit/abca98e48ee9262e20edebbe6b830cbb7f8715d3) |
| `automation/battle-quick-match-validation-20260711` | محتوى بالكامل؛ تاريخي | 0 | [2a7b3c57](https://github.com/aljwaal1/gameslocal/commit/2a7b3c577d2893c90a198d593b748a7272db978b) |
| `automation/battle-safe-random-bounds-20260711` | متباعد؛ يحتاج مراجعة | 2 | [b388220d](https://github.com/aljwaal1/gameslocal/commit/b388220d6629a396066e551ada44367425eff374) |
| `automation/battle-single-character-roll-bound-20260711` | متباعد؛ يحتاج مراجعة | 2 | [67a82d70](https://github.com/aljwaal1/gameslocal/commit/67a82d70e5ba4bd65e1ad92582d67d918d0b4798) |
| `automation/checkers-capture-advantage-summary-20260711` | متباعد؛ يحتاج مراجعة | 3 | [eeeae5c2](https://github.com/aljwaal1/gameslocal/commit/eeeae5c2b0ffe7c333e2c9b1e17275aa9f9d975e) |
| `automation/checkers-concise-result-20260711` | متباعد؛ يحتاج مراجعة | 2 | [078874f9](https://github.com/aljwaal1/gameslocal/commit/078874f9b7c1c93ed2054ccccf7adebe17442384) |
| `automation/checkers-mandatory-capture-highlight-20260711` | متباعد؛ يحتاج مراجعة | 2 | [d0a3a673](https://github.com/aljwaal1/gameslocal/commit/d0a3a673f1436e10811d621b2635ffb990d23eec) |
| `automation/checkers-no-move-piece-tiebreak-20260711` | متباعد؛ يحتاج مراجعة | 2 | [6b846c7e](https://github.com/aljwaal1/gameslocal/commit/6b846c7e9c660aef2daf8399040a3bedb14abbec) |
| `automation/checkers-normalize-piece-counts-20260711` | متباعد؛ يحتاج مراجعة | 2 | [d78c1b1c](https://github.com/aljwaal1/gameslocal/commit/d78c1b1cbc374af646a8323b57ab54b4a308b05b) |
| `automation/checkers-readable-result-20260711` | متباعد؛ يحتاج مراجعة | 4 | [a1f419ba](https://github.com/aljwaal1/gameslocal/commit/a1f419ba0daa4bc9f8f31c4d0888269816a61be7) |
| `automation/checkers-readable-result-lines-20260711` | متباعد؛ يحتاج مراجعة | 2 | [b8d937f9](https://github.com/aljwaal1/gameslocal/commit/b8d937f966fb8baf9eeba44be81223001a36eba7) |
| `automation/checkers-trim-result-reason-20260711` | محتوى بالكامل؛ تاريخي | 0 | [2f19e1ab](https://github.com/aljwaal1/gameslocal/commit/2f19e1abb96172d5649956dc31571daa64a225b3) |
| `automation/clamp-checkers-captured-count` | متباعد؛ يحتاج مراجعة | 1 | [502a3c82](https://github.com/aljwaal1/gameslocal/commit/502a3c82963f135f3d7a9ffcd2958a577564bca0) |
| `automation/fix-battle-home-card` | متباعد؛ يحتاج مراجعة | 1 | [c466b09f](https://github.com/aljwaal1/gameslocal/commit/c466b09f5b095cea37c878e59c37aa26468cefb5) |
| `automation/fix-checkers-captured-count` | متباعد؛ يحتاج مراجعة | 2 | [af62c42d](https://github.com/aljwaal1/gameslocal/commit/af62c42de1c6f7cd5f3f00ae15d83b807220ad5f) |
| `automation/normalize-checkers-result-counts` | متباعد؛ يحتاج مراجعة | 2 | [7fa6893f](https://github.com/aljwaal1/gameslocal/commit/7fa6893f462ed19468608349be578957d07e033e) |
| `battle-character-stats` | متباعد؛ يحتاج مراجعة | 1 | [1489b0fc](https://github.com/aljwaal1/gameslocal/commit/1489b0fc86b846b40bf5a2940a78be5b63e673cf) |
| `ci/force-apk-build` | متباعد؛ يحتاج مراجعة | 1 | [c6c64efd](https://github.com/aljwaal1/gameslocal/commit/c6c64efdee3674244e758d47987851af133c70ef) |
| `feature/football-motion-overhaul` | محتوى بالكامل؛ تاريخي | 0 | [a5d972ae](https://github.com/aljwaal1/gameslocal/commit/a5d972ae78018115f7b5bbda423baf1667592b17) |
| `feature/football-photo-v3` | محتوى بالكامل؛ تاريخي | 0 | [67a08c1c](https://github.com/aljwaal1/gameslocal/commit/67a08c1ce156556a0418d656343da965ce97de39) |
| `feature/football-visual-overhaul-v2` | محتوى بالكامل؛ تاريخي | 0 | [7140954f](https://github.com/aljwaal1/gameslocal/commit/7140954f62e693af9a133fab5aaa5a26c99c0c44) |
| `feature/fullscreen-polish` | محتوى بالكامل؛ تاريخي | 0 | [85b9ad9b](https://github.com/aljwaal1/gameslocal/commit/85b9ad9ba7573452fa30110c221e5204396d759e) |
| `feature/global-game-audio` | محتوى بالكامل؛ تاريخي | 0 | [f13b5fbe](https://github.com/aljwaal1/gameslocal/commit/f13b5fbef2f634e546a2c59b6057d70d1d277238) |
| `feature/iphone-web-player` | متباعد؛ يحتاج مراجعة | 4 | [6a9e854c](https://github.com/aljwaal1/gameslocal/commit/6a9e854ca401728185e0a3499cae6f1e6174a3f0) |
| `feature/penalty-shootout` | متباعد؛ يحتاج مراجعة | 8 | [44053f37](https://github.com/aljwaal1/gameslocal/commit/44053f37cf13d3f41bcd20646452427d8385daea) |
| `feature/pro-football-redesign` | محتوى بالكامل؛ تاريخي | 0 | [c46f2bf0](https://github.com/aljwaal1/gameslocal/commit/c46f2bf0588dc2f5b73ed6781539a75efaedac2d) |
| `feature/pro-penalty-arena-v2` | محتوى بالكامل؛ تاريخي | 0 | [fc2b63b3](https://github.com/aljwaal1/gameslocal/commit/fc2b63b3df0e9f0e9ab42dfea8b2bac335c69566) |
| `feature/pro-penalty-v2` | محتوى بالكامل؛ تاريخي | 0 | [78d1e3d6](https://github.com/aljwaal1/gameslocal/commit/78d1e3d67fc597b9392d672d8c1561032c112041) |
| `feature/realistic-penalty-gameplay-v3` | متباعد؛ يحتاج مراجعة | 1 | [216bcb99](https://github.com/aljwaal1/gameslocal/commit/216bcb991e3a2c5fbc7da41df517dafafafa206b) |
| `feature/universal-qr-games` | محتوى بالكامل؛ تاريخي | 0 | [49ee33f1](https://github.com/aljwaal1/gameslocal/commit/49ee33f107df7d4d1c66030339a87b3b64e6e7c3) |
| `feature/world-class-football` | محتوى بالكامل؛ تاريخي | 0 | [37b034b5](https://github.com/aljwaal1/gameslocal/commit/37b034b50b898346b30b5c9b849556c1c04c6a10) |
| `feature/world-class-ui-system` | متباعد؛ يحتاج مراجعة | 6 | [f904ab5b](https://github.com/aljwaal1/gameslocal/commit/f904ab5b8561e996d4b7b4f4e6f9f7ae69679fb3) |
| `feature/world-class-ui-v2` | التطوير الحالي | — | [896759a1](https://github.com/aljwaal1/gameslocal/commit/896759a18ad94be67bd1cb0e83099e1dd6aa4d29) |
| `fix/bot-gameplay-audit` | محتوى بالكامل؛ تاريخي | 0 | [31936f12](https://github.com/aljwaal1/gameslocal/commit/31936f126c469d9be9abae19394f7fc765da8f36) |
| `fix/chicken-empty-round-accuracy` | متباعد؛ يحتاج مراجعة | 2 | [f9132c63](https://github.com/aljwaal1/gameslocal/commit/f9132c63dbddb5f971d03f35d8fdda26b0dea0cc) |
| `fix/requested-gameplay-notes` | محتوى بالكامل؛ تاريخي | 0 | [7a7101c4](https://github.com/aljwaal1/gameslocal/commit/7a7101c4952c4e62014d3d8f41be775cec33df52) |
| `fix/robot-qr-football-ui` | محتوى بالكامل؛ تاريخي | 0 | [116f7328](https://github.com/aljwaal1/gameslocal/commit/116f7328b29b56cb1b19f576afd772bd97cbed0c) |
| `fix/sheikh-beard-scoring-and-turn-ui` | محتوى بالكامل؛ تاريخي | 0 | [7e109a82](https://github.com/aljwaal1/gameslocal/commit/7e109a82e0bef60c82b33cb21a2adbd883ae2bdf) |
| `fix/xo-pregame-qr-lobby` | محتوى بالكامل؛ تاريخي | 0 | [7de21be6](https://github.com/aljwaal1/gameslocal/commit/7de21be6fd0c0bd41a1581f66e221f96174c4777) |
| `hotfix/android-baseline-football-art` | متباعد؛ يحتاج مراجعة | 2 | [1a0cf11a](https://github.com/aljwaal1/gameslocal/commit/1a0cf11a441c2acd7bd58bb91daefd4ef664e3ea) |
| `hotfix/football-realistic-assets` | محتوى بالكامل؛ تاريخي | 0 | [4cc5f820](https://github.com/aljwaal1/gameslocal/commit/4cc5f8202f629ee018647f538b4d7f5715a1a763) |
| `hotfix/football-visible-player-keeper` | محتوى بالكامل؛ تاريخي | 0 | [5f33d0f4](https://github.com/aljwaal1/gameslocal/commit/5f33d0f4f2990d8307f148b2fd659ed3c9a198a5) |
| `hotfix/procedural-professional-penalty` | متباعد؛ يحتاج مراجعة | 4 | [81e4550c](https://github.com/aljwaal1/gameslocal/commit/81e4550c4e36669eaafae3e216584ab880a1663e) |
| `hotfix/procedural-professional-penalty-v2` | متباعد؛ يحتاج مراجعة | 1 | [32fe77fb](https://github.com/aljwaal1/gameslocal/commit/32fe77fbfd376d5580ad81ef1c24cab5511bb093) |
| `legacy-android-4.4` | متباعد؛ يحتاج مراجعة | 6 | [840e1fb3](https://github.com/aljwaal1/gameslocal/commit/840e1fb3cf24d3e7c83241d1ffbf25a712948ebb) |
| `main` | الأساسي | — | [35a5f7c2](https://github.com/aljwaal1/gameslocal/commit/35a5f7c213c89b45a45fe3a41e4eff9db5a25903) |
| `remove-battle-mode` | محتوى بالكامل؛ تاريخي | 0 | [e8366536](https://github.com/aljwaal1/gameslocal/commit/e8366536f45e5ea91510c0b6c7666f668bfcba97) |

[العودة لحالة المشروع](../PROJECT_STATUS.md)
