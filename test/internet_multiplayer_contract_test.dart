import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Internet multiplayer reuses the existing game message contract', () {
    final core =
        File('lib/core/network/local_network_core.dart').readAsStringSync();
    final transport = File(
      'lib/core/network/internet_relay_transport.dart',
    ).readAsStringSync();

    expect(core, contains('createInternetRoom'));
    expect(core, contains('joinInternetRoom'));
    expect(core, contains('NetworkConnectionKind.internet'));
    expect(transport, contains("'INTERNET_RELAY_URL'"));
    expect(transport, contains("'kind': 'game'"));
    expect(transport, contains('NetworkMessage.fromJson'));
  });

  test('relay validates rooms and has abuse and lifetime limits', () {
    final relay =
        File('server/internet_relay/server.dart').readAsStringSync();

    expect(relay, contains('_maxPlayersPerRoom = 12'));
    expect(relay, contains('_maxFrameBytes = 65536'));
    expect(relay, contains('windowFrames > 60'));
    expect(relay, contains("found.gameId != gameId"));
    expect(relay, contains('_roomLifetime = Duration(hours: 6)'));
  });

  test('Internet option is exposed without replacing LAN discovery', () {
    final room = File('lib/core/game_room.dart').readAsStringSync();

    expect(room, contains('نفس الشبكة'));
    expect(room, contains('عبر الإنترنت'));
    expect(room, contains('_findRooms'));
    expect(room, contains('_internetJoinPanel'));
    expect(room, contains('LocalRoomDiscovery'));
  });
}
