import 'dart:async';
import 'dart:typed_data';

/// A gameplay event lifetime, shared by all of its feedback cues.
class GameFeedbackCancellation {
  bool _cancelled = false;
  final Set<void Function()> _listeners = {};
  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listeners = List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  void Function() onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
    return () => _listeners.remove(listener);
  }
}

/// Serializes a reusable player's asynchronous commands. Ownership changes at
/// enqueue time so an old cancellation cannot stop the next owner's sound.
class GameFeedbackAudioChannel {
  GameFeedbackAudioChannel({
    required this.stop,
    required this.setVolume,
    required this.setSourceBytes,
    required this.resume,
  });

  final Future<void> Function() stop;
  final Future<void> Function(double) setVolume;
  final Future<void> Function(Uint8List) setSourceBytes;
  final Future<void> Function() resume;
  Future<void> _tail = Future<void>.value();
  Object? _owner;
  void Function()? _detach;

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    // A rejected device command must not poison subsequent cues on this player.
    _tail = result.catchError((Object _) {});
    return result;
  }

  Future<void> play({
    required Uint8List bytes,
    required double volume,
    GameFeedbackCancellation? cancellation,
  }) {
    if (cancellation?.isCancelled ?? false) return Future<void>.value();
    final owner = Object();
    _detach?.call();
    _owner = owner;
    bool active() =>
        identical(_owner, owner) && !(cancellation?.isCancelled ?? false);
    _detach = cancellation?.onCancel(() {
      unawaited(_enqueue(() async {
        if (!identical(_owner, owner)) return;
        await stop();
        if (identical(_owner, owner)) _owner = null;
      }).catchError((Object _) {}));
    });
    return _enqueue(() async {
      if (!active()) return;
      await stop();
      if (!active()) return;
      await setVolume(volume);
      if (!active()) return;
      await setSourceBytes(bytes);
      if (!active()) return;
      await resume();
      if (!active()) return;
    });
  }
}
