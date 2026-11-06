# Game quality progress — 2026-11-06

## Binding constraints
Work only on feature/world-class-ui-v2. Never modify main or merge PR66. Preserve rules, score, ArcadeTiming, Random call order and all network payload keys. User authorizes continuous implementation, review, incremental pushes and verified release APK. No approval pauses required.

## Completed
1. Cards: commit90185583a53a0392f00135afab7dd5dafcc7eb62. Hand51 shared geometry/reverse paint-order hits,20cards readable and horizontally scrollable; large identities/corners/joker. Cards full72x112/compact64x100 scalable, four-card scroll row, concise retained status, bounded table/longmelds/landscape. Independent review found raised selected-card dead strip + croppedtable; both fixed with behavioral RED/GREEN tests. Final19 focused/96full tests pass; analysis0/noerrors,189nonfatal diagnostics; format clean. Real-font320/long/landscape captures reviewed.
2. Build infrastructure: target branch push CI, format/test/analyze gate, exact-SHA guarded publication to apk/world-class-ui-v2/gameslocal-release.apk. GitHub Actions628 succeeded: https://github.com/aljwaal1/gameslocal/actions/runs/42158425733 . Source90185583; artifact commit0c092a2085ed3110b4d76ea235ad2b9216d4342b. Actual56MB APK exists, intermediate cards-only build.
3. Audio reference audit saved audio-audit.md. carsgame fedb200b784fb8ec37fcf778cafccb32fa1be6bd; no clipped samples. Retain existing synthesized feedback unless perceptual/gameplay benefit shown; no WAV import so far.

## Current
Hockey implementer /root/hockey owns lib/games/air_hockey and new tests. TDD, independent review required before next subsystem. Report /tmp/hockey-report.md. No worker commits/pushes; root publishes through GitHub connector (CLI git push lacks auth).

## Pending ordered work
- Hockey controller/physics -> focused/full/analyze -> independent review -> branch push.
- Football shared timeline/local feedback cancellation -> review.
- Network football integration/event order -> review.
- Smooth2.5D road geometry/vector cars/weather/HUD, existing mechanics retained -> review.
- Smooth aerial plane geometry/vector art/background/fuel/HUD, mechanics retained -> review.
- Final integration320x640/long/landscape/textscale1.3; focused tests; pubget/format/check/analyze/fulltests/releasebuild; CI green; actual final APK direct URL. No merge.

## Runtime recovery
The session environment was cleaned during user inactivity after cards push; all completed source recovered from GitHub at0c092a2. Runtime being reinstalled at/tmp/flutter, AndroidSDK at/workspace/android-sdk. ALWAYS prefix Flutter with CI=true FLUTTER_SUPPRESS_ANALYTICS=true: Flutter BotDetector otherwise probes Azure metadata; automatic review rejected that default invocation previously. CI=true short-circuits metadata code; safe invocation verified in prior stage. Dart3.13.7/Flutter3.47.9 stable. All local reports/screenshots can be regenerated from committed behavioral tests. GitHub source/build logs are durable authority.

Hockey review round1: focused28/full122 passed, analyze0/noerrors186nonfatal. Independentreview requests actual landscapegeometry fix:640x320/1.3 field too wide forheight, width-scaled paddle protrudes. Implementer adding widgetRED thencompactlandscapeHUD/aspectboundedfield; no rule changes. Controller/physics/network otherwise approved. Actualbotmotion72000steps passed; wrongpredictionwall and terminalgoalbroadcast fixed after RED. Flutter+AndroidSDK restored; root offlinepubget restored completeYAMLlock without changing tested84-package resolution.

Task2 hockey complete: independent re-review PASS/PASS, landscapefinding addressed. Focused31/full125 passed; analyzeexit0/noerrors185nonfatal; formatclean. Source preserves five-goal rules,payloads,authority; fixes finalgoal broadcast. Added fullYAMLpubspec.lock consistent with tested84-package resolution; CI now preserves lock around Flutter Android scaffolding. Next:footballtimeline/localcancellation/network.

Hockey sourcebf935247f1debc794e6a75b3288ac8273b21d2e4 pushed; Actions https://github.com/aljwaal1/gameslocal/actions/runs/42192577895 succeeded. Football implementer active: shared timeline+localcancellation+networkcore behavioraltests green, actorlayout/captures/fullreview pending. Root restored final fullpub lock and protected CI from scaffolding overwrites.

Football review round1: /tmp/football-review.md (initial full166/167 green, timing/audio/RNGapproved) requires five fixes before acceptance: preserve activeGameWidget on live rotation; enforce remote-turn parity/admissiblependingturn; terminaldisconnect cannotresume; discardpauseddrags/rejectpausedgameentry; malformedpayload/range validation and defensiveactorbounds. Worker /root/football implementing behavioral RED/GREEN for all; reviewer /root/football_review will scopedre-review. RootAndroidprecache completed, Gradle9.3.1+SDK36/NDK28 installed; finalbuildruntime ready. No source/payload/rule changes by root during workerfix.

Football complete and independently approved: focused90/full207/network45 passed; analyzeexit0/noerrors185existingdiagnostics; format111files0changes. All5findingsclosed; sourceRandom/probabilityblocks unchanged, exact9outgoingkeys unchanged. Durableevidence football-report.md and football-rereview-round2.md. Next road thenplane thenfinalAPK. Runtime now persistent ../runtime/flutter, PUB_CACHE ../runtime/pub-cache, SDK ../runtime/android-sdk, Gradlecache ../runtime/gradle-cache; logs ../verification.

Road complete/reviewPASS: focused15/full222/no skips; analyze0errors0warnings163legacyinfos; format7files0changes. 18screensweather/aspect/scale1.3 reviewed; all10criticalengine/control/wirebodyhashes unchanged. Independentnonblockingobservation retained: readable silhouetteshavegenerouslegacycontactmargins; centersanchored.82 andrulesunchanged. Next Plane thenfinalintegration/build.
