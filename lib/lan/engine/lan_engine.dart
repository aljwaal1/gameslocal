import '../models/lan_message.dart';
import '../models/lan_room.dart';
import 'client_service.dart';
import 'discovery_service.dart';
import 'host_service.dart';

class LanEngine {
  LanEngine._();

  static final LanEngine instance = LanEngine._();

  final LanHostService host = LanHostService();
  final LanClientService client = LanClientService();
  final LanDiscoveryService discovery = LanDiscoveryService();

  Stream<LanMessage> get hostMessages => host.messages;
  Stream<LanMessage> get clientMessages => client.messages;
  Stream<LanRoom> get discoveredRooms => discovery.rooms;

  Future<LanRoom> createRoom({required String gameId, required String hostName}) async {
    final room = await host.startHost(gameId: gameId, hostName: hostName);
    await discovery.startAdvertising(room);
    return room;
  }

  Future<void> searchRooms() => discovery.startListening();

  Future<void> joinRoom({required String hostAddress, required int port}) {
    return client.connect(host: hostAddress, port: port);
  }

  void sendFromClient(LanMessage message) => client.send(message);

  void sendFromHost(LanMessage message) => host.broadcast(message);

  Future<void> stopAll() async {
    discovery.stop();
    client.disconnect();
    await host.stop();
  }
}
