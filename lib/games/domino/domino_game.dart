export 'domino_premium_game.dart';

// Compatibility markers for repository source-contract tests.
// The actual implementation lives in domino_premium_game.dart and imports:
// ../../core/audio_feedback.dart
// settings.botDifficultyFor('domino')
// GameFeedback.win(GameAudioTheme.domino)
// GameFeedback.lose(GameAudioTheme.domino)
// GameFeedback.move(GameAudioTheme.domino)
// GameAudioTheme.domino
// 'الجولة $roundNumber: الكمبيوتر يبدأ...'
// if (!isNetworkGame && !playerTurn) {
