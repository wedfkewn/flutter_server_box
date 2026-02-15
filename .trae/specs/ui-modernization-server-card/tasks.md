# Tasks

- [x] Task 1: Data Layer Enhancements
  - [x] Add `arch` (`uname -m`) and `kernel` (`uname -r`) to `StatusCmdType` enum in `lib/data/model/app/scripts/cmd_types.dart`.
  - [x] Update `_getLinuxStatus` in `lib/data/model/server/server_status_update_req.dart` to parse `arch` and `kernel` outputs and store them in `ServerStatus.more`.
  - [x] Verify `BSDStatusCmdType` and `WindowsStatusCmdType` handle or skip these new types appropriately (or implement equivalents).

- [x] Task 2: Create ServerCardModern Widget
  - [x] Create `lib/view/page/server/tab/card_modern.dart`.
  - [x] Implement `ServerCardModern` widget that accepts `ServerState` and `Spi`.
  - [x] Implement Header (Icon, Name, Latency).
  - [x] Implement Info Tags (OS, Arch, Kernel, Uptime).
  - [x] Implement Linear Progress Bars for CPU, Memory, Disk.
  - [x] Implement CPU Model display.
  - [x] Implement Network Stats (Up/Down speed & total).
  - [x] Implement Action Buttons (Reuse `ServerFuncBtns` or create new row).

- [x] Task 3: Integration & Cleanup
  - [x] Modify `lib/view/page/server/tab/tab.dart` to use `ServerCardModern` in `_buildRealServerCard`.
  - [x] Ensure `ServerCardModern` handles different server states (loading, disconnected, etc.) gracefully.
  - [x] Test the new UI with mock data or real server connection.
