import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/native_dashboard_snapshot.dart';

void main() {
  test('native dashboard snapshot contains presentation data only', () {
    final json = NativeDashboardSnapshot(
      revision: 7,
      servers: const [
        NativeDashboardServerSnapshot(
          id: 'server-1',
          name: 'STD20',
          address: 'root@192.0.2.20:22',
          online: true,
          cpuPercent: 3,
          memoryPercent: 47,
          diskPercent: 41,
        ),
      ],
    ).toJson();

    expect(json, {
      'revision': 7,
      'servers': [
        {
          'id': 'server-1',
          'name': 'STD20',
          'address': 'root@192.0.2.20:22',
          'state': 'online',
          'cpuPercent': 3,
          'memoryPercent': 47,
          'diskPercent': 41,
        },
      ],
    });
  });

  test('native dashboard snapshot encodes revision for ordered delivery', () {
    const snapshot = NativeDashboardSnapshot(revision: 8, servers: []);

    expect(snapshot.encode(), '{"revision":8,"servers":[]}');
  });
}
