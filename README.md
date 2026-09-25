# Hunch

**The Cursor Tab for Mac.**

System-wide autocomplete for macOS, powered exclusively by the Apple
Intelligence model already managed by macOS.

Hunch reads the focused editable field through the Accessibility API, asks
the on-device Foundation Model for a short continuation, and draws ghost text
at the caret. Press Tab to accept one word, Shift-Tab to accept the rest, or
keep typing to dismiss it.

## Privacy

- Inference uses Apple's `FoundationModels` framework and stays on device.
- Hunch does not download, bundle, or manage model weights.
- No account, API key, subscription, telemetry, or text upload is required.
- Secure input, password-like fields, terminals, and password managers are
  excluded from text capture.
- Screen OCR and clipboard context are optional and disabled unless enabled in
  Settings.

Accessibility is a powerful permission. The relevant input path is small and
auditable: `AXText.swift` reads editable text, `KeyTap.swift` handles acceptance,
and `TextInjector.swift` inserts accepted text.

## Requirements

- macOS 26 or newer
- An Apple Intelligence-capable Mac with Apple Intelligence enabled
- Xcode 26 or newer to build from source
- Accessibility permission at runtime

The app checks `SystemLanguageModel.default.availability`. If Apple Intelligence
is disabled, unsupported, or its assets are not ready, Hunch reports that
state and does not fall back to a downloaded model.

## Build

```bash
./Scripts/package_app.sh
open build/Hunch.app
```

The build uses the system `FoundationModels` framework. No Metal toolchain or
third-party model package is needed.

For the normal development loop, `./Scripts/compile_and_run.sh --test` runs the
tests, replaces the bundle, relaunches it, and verifies that it stayed running.

## Release locally

```bash
./Scripts/release.sh --install
```

The release script bumps the patch version, runs the tests, builds and signs the
app on this Mac, creates `build/Hunch.app.zip`, commits and tags the version,
pushes it, and creates the GitHub Release with the ZIP attached. `--install`
copies that exact locally built release into `/Applications`, so downloading it
again is unnecessary. Use `--dry-run` to build without publishing, or
`--version X.Y.Z`, `--minor`, or `--major` to control the version.

## Architecture

```text
focused text field
      ↓ Accessibility
context + caret position
      ↓ FoundationModels
short continuation
      ↓ transparent overlay
ghost text at the caret
      ↓ Tab / Shift-Tab
synthetic text insertion
```

Hunch is a menu-bar app. It can optionally register as a login item and does
not use a LaunchDaemon.

## License

MIT. See `LICENSE`.
