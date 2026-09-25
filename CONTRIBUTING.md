# Contributing

Hunch is a SwiftPM macOS menu-bar app targeting macOS 26 or newer. It uses
Apple's system `FoundationModels` framework exclusively; there are no external
model packages, weights, or Metal build steps.

## Development

```bash
swift build
swift test
./Scripts/compile_and_run.sh
```

Pass `--test` to the last command to run the test suite before packaging and
launching. The script stops only the instance launched from this checkout,
rebuilds `build/Hunch.app`, launches it, and verifies that it stays alive.

To package without launching:

```bash
./Scripts/package_app.sh
```

The packaging script creates the Info.plist, copies the icon and executable,
adds the microphone entitlement used by optional dictation, signs the bundle,
and verifies its signature.

## Runtime permissions

The built app needs Accessibility permission. Optional screen context needs
Screen Recording, and optional dictation needs Microphone access. A raw SwiftPM
executable is useful for tests but should not be used for permission testing.

## Pull requests

- Keep secure-input and password-field checks fail-closed.
- Never add network inference or model downloads.
- Add focused tests for behavior changes.
- Run `swift test` and `./Scripts/package_app.sh` before submitting.
