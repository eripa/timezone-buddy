# Contributing to Timezone Buddy

Thanks for taking the time to contribute. This is a small menu bar app, so a
focused change with a test is much more useful than a large refactor.

## Before you start

- macOS 27 or later and Xcode 27 or later are required by the current project.
- The app is Apple silicon only (`ARCHS = arm64`).
- By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Build, test, and lint

From the repository root:

```sh
# Build the app
xcodebuild build -project timezone-buddy.xcodeproj -scheme timezone-buddy \
  -destination 'platform=macOS'

# Run the Swift Testing and UI test suites (hosted by the app)
xcodebuild test -project timezone-buddy.xcodeproj -scheme timezone-buddy \
  -destination 'platform=macOS'

# Check formatting
xcrun swift-format lint --strict --configuration .swift-format \
  --recursive timezone-buddy timezone-buddyTests timezone-buddyUITests
```

To fix formatting, run the formatter instead of editing whitespace by hand:

```sh
xcrun swift-format format --in-place --configuration .swift-format \
  --recursive timezone-buddy timezone-buddyTests timezone-buddyUITests
```

Or open `timezone-buddy.xcodeproj` in Xcode and press Run.

## Tests

- Use [Swift Testing](https://developer.apple.com/documentation/testing/) for
  unit tests. The test target is `timezone-buddyTests`.
- Put a test for new behavior in the same pull request as the behavior.
- Date and time logic is the most bug-prone part of the app. Cover DST gaps,
  half-hour offsets, date-line changes, and time-travel bounds when relevant.
- UI tests live in `timezone-buddyUITests` and use XCUIAutomation. Keep the
  smoke test focused on the menu bar panel and Settings window.
- User-facing strings live in `timezone-buddy/Localizable.xcstrings`; add
  translations through the String Catalog in Xcode rather than hard-coding
  localized copies in views.
- UI tests are optional for small changes but should be updated when a change
  alters the menu bar panel or Settings window.

## Code style

- Four-space indentation, one type per file where practical.
- PascalCase for types and camelCase for properties and methods.
- Use `@State private var` for SwiftUI state and `let` for constants.
- Prefer Swift concurrency (`async`/`await`, `Task`) over Combine.
- Avoid force unwraps and force `try`; use `guard`, `if let`, or `#require` in
  tests.
- Add comments for non-obvious behavior, especially time-zone edge cases.
- Keep UI strings user-facing and concise.

The `.swift-format` configuration is the source of truth. CI rejects formatting
that does not pass `swift-format lint --strict`.

## Pull requests

Please keep pull requests small and explain the problem being solved.

- Link an issue when one exists.
- Include tests for behavior changes.
- Include before/after screenshots or a short recording for UI changes.
- Update `README.md` if user-facing behavior or setup changes.
- Make sure the build, tests, and formatter check pass locally.
- Do not commit `build/`, `DerivedData/`, `dist/`, archives, or Xcode
  `xcuserdata`.
- Do not include credentials, tokens, provisioning profiles, or personal data.

Opening a pull request means you agree to license your contribution under the
project's license, GPL-3.0-or-later. There is no CLA.

## Reporting bugs

Use the bug report issue template and include:

- macOS version
- Timezone Buddy version and build number (Settings → About)
- Steps to reproduce
- Expected and actual behavior
- Screenshots or logs if useful

Please do not report security vulnerabilities in a public issue. See
[SECURITY.md](SECURITY.md).
