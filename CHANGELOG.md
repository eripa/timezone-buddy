# Changelog

All notable changes to Timezone Buddy are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- The Settings window no longer draws an empty material strip below the pane
  tabs.

## [1.5.0] - 2026-10-26

### Added

- Keyboard-accessible move up/down controls for zone ordering.
- UI smoke test that opens the menu bar panel and Settings window.
- String Catalog (`Localizable.xcstrings`) for the app's user-facing strings.
- Privacy manifest declaring the UserDefaults required-reason API.
- Contributor guide, code of conduct, security policy, issue and pull request
  templates, and Dependabot configuration.
- CI workflow for build, test, and strict formatting checks.
- Changelog.

### Changed

- Settings now uses an AppKit window controller rather than SwiftUI's private
  `showSettingsWindow:` selector.
- Project-level deployment target aligned with the app target at macOS 27.
- Sources formatted with `swift-format` and checked in CI.

### Fixed

- Time-travel entries beyond the 48-hour slider maximum are rejected instead of
  leaving the slider outside its range.
- Persisted settings no longer reset silently: decode and encode failures are
  logged, invalid and duplicate zones are dropped on load, and unresolved
  identifiers fall back to GMT rather than the local zone.
- Menu bar VoiceOver labels now include inline clock values.

## [1.4.0] - 2026-10-26

### Added

- About pane in Settings with app icon, version, build, and copyright.
- README with feature documentation and screenshots.
- Tag-triggered release workflow for ad-hoc signed GitHub releases.

### Changed

- Version 1.4 and build 6.

## [1.3.0] - 2026-10-26

### Added

- Ranked search by city, time zone name, abbreviation, and curated alias.
- Custom display names for zones.
- UTC support and neutral abbreviations such as ET, CT, MT, and PT.
- Drag reordering with `reorderContainer`.
- Search, custom-name, persistence, and zone-ranking tests.

### Changed

- Version 1.3 and build 5.

## [1.2.0] - 2026-10-26

### Added

- Liquid Glass-era styling, including semantic chrome and a neutral time-travel
  slider with hour ticks.
- Reopening the last-used Settings pane.
- Minute-boundary clock updates.

### Changed

- Minimum macOS version raised to 27.
- Version 1.2 and build 4.

## [1.1.0] - 2026-10-24

### Added

- Editable 24-hour clocks synchronized across zones and the time-travel slider.
- DST-aware time parsing and slider-window expansion.

### Fixed

- Reject entered times that require more than the 48-hour slider maximum.

### Changed

- Version 1.1 and build 3.

## [1.0.0] - 2026-10-24

### Added

- Initial menu bar app with configurable zones, time travel, Settings, app icon,
  and launch-at-login support.
