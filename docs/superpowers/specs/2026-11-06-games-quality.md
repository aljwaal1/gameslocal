# GamesLocal quality specification — user requirements

Repository aljwaal1/gameslocal, ONLY feature/world-class-ui-v2. Never edit main or merge PR66 until user tests APK and explicitly approves merge. Initial source b3bb7ab493078922f09c5a56bf0d41ab8adce8fb; adopt latest remote head, preserving existing changes. Previous unpushed edits were lost: trust source, not assumed old work.

## Execution and invariants
Tests first for every significant fix: author behavioral/unit/widget/integration tests, observe RED for expected missing behavior, implement, observe GREEN. No source-text-only tests where actual behavior can be exercised. Focused tests before full Flutter tests and analysis after each package. Independent specification/code-quality review after each subsystem and final integration review. Preserve ALL game rules, scores, networking authority, Random call order, payload key names, and existing features. No approval pauses between packages; complete through verified release APK. Incremental target-branch pushes/Actions required; fix failures to green. Never claim success without actual logs; never claim APK exists without real file/artifact. Final report per game, tests/analyze, Actions URL, DIRECT APK URL (not ZIP alone), honest remaining limitations.

Final commands: flutter pub get; dart format lib test; dart format --output=none --set-exit-if-changed lib test; flutter analyze --no-fatal-infos --no-fatal-warnings; flutter test; flutter build apk --release. Validate 320x640, long phone, landscape and text scale1.3. Do not leave known defects and call package complete.

## Cards (implemented in90185583, verified by CI628)
Hand51CardLayout independent geometry shared by rendering and touch.20cards at320px and textscale1.3 need>=24px exposed header, true horizontal scroll. Selection first/middle/end after scroll, small crowded fan angle. Larger clear high-contrast corner rank+suit and opposite inverted corner. A,10,J,Q,K,joker and red/black legible. Preserve melds/opening/points/rules.
PlayingCardView large central rank>=24compact/30full, suit>=24compact/32full plus corners, textscale1/1.3. Four full72px cards+spacing312px cannot fit300px available at320screen: scroll horizontal or responsive without shrinking readability. Real four-card hand tests: one row, no overflow, every card tappable. Preserve PlayingCardModel, values, capture/basra/results/network. Independent review additionally required reverse paint-order rect hit for raised selection, useful full-height compact table viewport, longmeld horizontal containment.

## Hockey
Create lib/games/air_hockey/hockey_bot_controller.dart with HockeyBotProfile.forDifficulty(BotDifficulty), HockeyBotState, HockeyBotController.step. Pixel/second speed and pixel/second² acceleration, NOT screen-normalized limits. Response intervals easy.24s,normal.16s,hard.09s. Hold target between reaction decisions; gradual accel/decel; defensive return when puck distant; difficulty-dependent trajectory prediction; attack only reachable puck with suitable speed. Hard improves capability while obeying limits. Guard invalid/large dt against teleportation. Reset after goal,match reset,mode change.
Independent paddle contact function hockey_physics.dart: restitution~.90, paddle normal speed transfer~.65,separation1px, GLOBAL puck speed900px/s. Remove old1.42 transfer, normalized2.65cap, difficulty minimum bot shot injection. Apply900 cap before position integration, after paddle,post and wall paths. Separating contact adds no energy, zero distance finite, persistent contact does not issue repeated strike every frame. Preserve goal aperture/posts/field bounds,five-goal win,friend/LAN/score and all messages.
Tests: difficulty ordering/response intervals, accel/speed limits, defense, conditional attacks, equal pixel behavior across dimensions, stationary/moving paddle, repeated/separating/zero contacts, posts/walls/all900 caps,friend and LAN same scoring.

## Football shared timeline
Create lib/games/football/penalty_motion_timeline.dart returning frame phase,approach,plant,contact,followThrough,ballFlight,keeperPush,keeperReach,keeperLanding. Normalized boundaries:
- plantStart.22,approachEnd.28
- keeperPushStart.26
- contactStart.34,contactEnd/ballLaunch.38
- keeperPushEnd/reachStart.48
- followThroughEnd.58
- keeperReachEnd.84
- ballArrival.86
- keeperLanding.86..1.0
Ball fixed before contact, flight only after contact END. Kick sound+haptic ONCE at contact. Nonlinear approach slows before kick, body/foot follow-through continues after launch. Keeper preparation,push,extension,reach,landing. Goal/save/post/miss feedback and visible score/message at arrival, not animation start. Outcome may be internally resolved at shot start for synchronization but must not be displayed/count visually early. Use existing image assets with Canvas/Flame transforms/shadows. Full actor bodies visible long/wide screens. Do not change outcome probabilities or random call order.

### Local
Apply to world_class_penalty_game_v2.dart. Preserve outcome probabilities, exact Random ordering, score/points/roles,earlyfinish,suddendeath,existing network delegation. Shared timeline drives player/keeper/ball, not disconnected tests. Test actual integration/contact/arrival order.

### Feedback cancellation
GameFeedbackCancellation lifetime for EACH local shot. Starting new shot,stopping/pausing game,scene removal/restart cancels previous lifetime. Check canceled after EVERY await in audio preparation (stop,setVolume,setSourceBytes,resume). Haptic is event-timed and MUST NOT wait audio preparation. Cancel requests stop for already-started player only if still owned by SAME lifetime; stale cancellation must never stop newer audio sharing player. Backward compatibility for all existing calls without cancellation. Tests controlled await stop,setVolume,setSourceBytes,resume cancellations,ownership reuse, pause/resume,remove,newshot. Preserve general feedback layer and per-game themes.

### Network
Apply SAME timeline to elite_penalty_game_v2.dart. Resolve outcome locally at shot START; send shot to peer BEFORE animation ends. Preserve EXACT payload keys action,turn,tx,ty,kx,ky,power,curve,outcome. Preserve host authority,turn IDs,score rules. Local/remote use same sequence: no ball flight before contact; score/message/feedback at arrival. Canceled animation/removedscreen must produce no late score/sound. Test local/LAN/internet visual event ordering. Route through shared GameFeedback, no direct arbitrary haptic/system sounds.

## Road
Inspect aljwaal1/carsgame reference engine/config/models/speeds/weather/stages/car models. Never copy old retro_road_painter.dart,RetroPixels,CRT.
Create independent RoadSceneGeometry with depthScale(y),project(x,y),roadHalfWidth(y). Professional2.5D road with clear perspective; smooth lightly textured asphalt; shoulders/edges/animated lane markings. Smooth vector cars: curved body,roof,windows,lights,wheels,groundshadow,gloss; depth-sized. Subtle suspension when lane changes,speed feel without annoying shake. Day,sunset,night,fog,snow,rain: keep cars/road visible. Modern light HUD does not obscure play. Preserve collision,lanes,score,days,control,network,payload,ArcadeTiming semantics.
Tests: monotonic depth,symmetriclanes,bounded safe offscreen geometry,collision center stable acrossdimensions,320x640/landscape,allweather, noRetroPixels/CRT,unchanged timing/collision/network. Prefer actual geometry/widget/painter behavior; sourcecontracts alone insufficient.

## Plane
Inspect carsgame Fuel Plane engine/config/models. Never old fuel_plane_painter.dart,RetroPixels,CRT or space-looking background.
Independent PlaneSceneGeometry project(x,y),depthScale(y),bankForDelta(delta): bounded/safe projection,monotonicdepth,bounded symmetric banking,stable play center acrossaspect. Smooth top-down vector plane body,wings,tail,cockpit,engines,shadow,glow,exhaust; visual banking on horizontal movement. Layered aerial water,land,islands,clouds,fog,parallax. Distinct fuel/rocks/enemyplane. Bullets,muzzleflash,briefexplosion. Local/remote planes visibly distinct. Clear fuel HUD withlowfuel state. Preserve fuel/shooting/collision/score/levels/co-op/versus/network,payload,ArcadeTiming.
Tests safegeometry/depth/bank/center/aspect,lowfuelclarity,local-vsremote identity,noRetroPixels/CRT,and gameplay/network invariants.

## Reference audio
Before importing any WAV examine silence,clipping,noise,duration. Candidates car_crash.wav,car_pass.wav,stage_clear.wav,weather_change.wav,fuel_pickup.wav,plane_shoot.wav,plane_explosion.wav. Do not import if existing audio better. One cue per event; no duplicate crash/explosion via layered feedback. Monitor APK size. All through current shared audio layer. Existing metric audit docs/verification/audio-audit.md; no importedWAV currently.
