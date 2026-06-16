import 'package:workmanager/workmanager.dart';

import '../../domain/life/life.dart';
import '../local_store.dart';
import '../notifications/notification_service.dart';

const String kLifeCheckTask = 'ocl-life-check';

/// WorkManager entry point — runs in a separate isolate (no UI, no Firebase).
/// Once a day it re-evaluates the spirit's life from the locally-persisted
/// snapshot and fires a notification if it newly died / entered danger /
/// passed into the coffin — even when the app is closed.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      await NotificationService.init();
      final snap = await LocalStore.loadLifeSnapshot();
      if (snap == null) return true;

      final before = snap.life;
      final now = DateTime.now();

      // already dead → only the golden-time → coffin transition matters
      if (before.state == LifeState.dead) {
        final after = LifeEngine.evaluate(before, snap.dailyMinutes, now);
        if (after.state == LifeState.coffin) {
          await NotificationService.cancelGoldenCountdown();
          await LocalStore.saveLifeSnapshot(life: after, dailyMinutes: snap.dailyMinutes, name: snap.name);
        }
        return true;
      }
      if (!before.contractActive) return true;

      final after = LifeEngine.evaluate(before, snap.dailyMinutes, now);
      if (after.state == LifeState.dead && after.diedAt != null) {
        await NotificationService.notifyDeath(
          spiritName: snap.name,
          deadline: after.diedAt!.add(const Duration(days: Life.goldenDays)),
        );
        await LocalStore.saveLifeSnapshot(life: after, dailyMinutes: snap.dailyMinutes, name: snap.name);
      } else if (after.state == LifeState.danger && before.state != LifeState.danger) {
        await NotificationService.notifyDanger(spiritName: snap.name, health: after.health);
        await LocalStore.saveLifeSnapshot(life: after, dailyMinutes: snap.dailyMinutes, name: snap.name);
      } else if (after.lastEvalDate != before.lastEvalDate) {
        await LocalStore.saveLifeSnapshot(life: after, dailyMinutes: snap.dailyMinutes, name: snap.name);
      }
      return true;
    } catch (_) {
      return true; // never crash the background runner
    }
  });
}
