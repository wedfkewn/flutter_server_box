# Server Card UI Modernization Spec

## Why
The user wants to modernize the server card UI on the home page to match a specific design that provides more detailed information (OS, Arch, Kernel, Uptime) and a cleaner visual style with linear progress bars and tags.

## What Changes
- **Data Layer**:
  - Add `arch` (Architecture) and `kernel` (Kernel Version) commands to `StatusCmdType` for Linux.
  - Update `ServerStatus` parsing logic to collect and store these new data points.
- **UI Layer**:
  - Create a new `ServerCardModern` widget to replace the existing card content.
  - Implement a layout with:
    - Header: Icon, Name, Latency Tag.
    - Info Tags: OS Name, Arch, Kernel.
    - Uptime Tag.
    - Resource Stats: CPU, Memory, Disk (Linear Progress Bars).
    - Hardware Info: CPU Model.
    - Network: Upload/Download speeds and totals.
    - Footer: Action buttons (Terminal, SFTP, Edit, etc. - adapting existing actions).

## Impact
- **Affected Specs**: Server monitoring and display.
- **Affected Code**:
  - `lib/data/model/app/scripts/cmd_types.dart`: Add new commands.
  - `lib/data/model/server/server_status_update_req.dart`: Update parsing.
  - `lib/view/page/server/tab/tab.dart`: Use new card widget.
  - New file: `lib/view/page/server/tab/card_modern.dart`.

## ADDED Requirements
### Requirement: Extended System Info
The system SHALL collect and display:
- Kernel Version (e.g., `5.15.0`)
- System Architecture (e.g., `x86_64`)

### Requirement: Modern Card UI
The system SHALL display server status in a card with:
- **Tags Row**: OS, Arch, Kernel.
- **Uptime**: displayed as a distinct tag/section.
- **Linear Stats**: CPU, RAM, Disk usage as linear progress indicators with detailed text (Used %, Used/Total).
- **Network**: distinct Up/Down sections with speed and total transferred.

## MODIFIED Requirements
### Requirement: Server Card Display
**Modified**: The home page server list will use the new `ServerCardModern` instead of the old circular percent indicators.
