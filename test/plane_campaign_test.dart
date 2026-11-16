import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/fuel_plane/plane_campaign.dart';

void main() {
  test('the stage stays locked until every required hit lands', () {
    final campaign = PlaneCampaign();
    campaign.advance(359);
    expect(campaign.gateReady, isFalse);
    campaign.advance(1);
    expect(campaign.gateReady, isTrue);
    campaign.openGate();
    for (var i = 0; i < 7; i++) {
      expect(campaign.hitGate(), isFalse);
    }
    expect(campaign.stage, 1);
    expect(campaign.hitGate(), isTrue);
    expect(campaign.stage, 2);
    expect(campaign.gateReady, isFalse);
    expect(campaign.gateHealth, 0);
  });

  test('a lost life resets the current checkpoint and the last ends play', () {
    final campaign = PlaneCampaign()
      ..advance(360)
      ..openGate();
    for (var i = 0; i < 8; i++) {
      campaign.hitGate();
    }
    campaign.advance(500);
    campaign.openGate();
    expect(campaign.loseLife(), isTrue);
    expect(campaign.stage, 2);
    expect(campaign.gateHealth, 0);
    expect(campaign.gateReady, isFalse);
    expect(campaign.loseLife(), isTrue);
    expect(campaign.loseLife(), isFalse);
    expect(campaign.lives, 0);
  });

  test('forward flight covers more ground and consumes more fuel', () {
    final cruise = PlaneCampaign()..advance(50);
    final boost = PlaneCampaign()..advance(50, boosting: true);
    expect(boost.travel, greaterThan(cruise.travel));
    expect(
      PlaneCampaign.fuelDrain(boosting: true),
      greaterThan(PlaneCampaign.fuelDrain()),
    );
  });
}
