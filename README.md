# F1Dash

A native macOS app for real-time Formula 1 timing and telemetry, built with SwiftUI.

> **Work in progress** — actively under development. Features may be incomplete or change without notice.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Live timing dashboard** — leaderboard, sector times, gaps, tire strategy, DRS status
- **Track map** — real-time driver positions with smooth interpolated movement
- **Race replay** — load and replay historical sessions from OpenF1
- **Car telemetry** — speed, throttle, brake, gear, RPM per driver
- **Race control** — flags, track limits, safety car notifications
- **Team radio** — live team radio captures
- **Weather** — track and air temperature, wind, rainfall
- **Schedule** — upcoming race weekends with countdown
- **Standings** — WDC and WCC with live updates

## Screenshots

*Coming soon*

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+

## Building

```bash
xcodebuild build -scheme F1Dash -destination 'platform=macOS'
```

Run in demo mode with simulated race data:
```bash
open path/to/F1Dash.app --args --demo
```

## Data Sources

- [OpenF1 API](https://openf1.org) — live and historical timing data
- [Jolpica F1 API](https://github.com/jolpica/jolpica-f1) — schedule and standings

## License

MIT
