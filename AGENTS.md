## Development Workflow

### Cross-platform consistency

VektorTV includes native iOS/iPadOS and tvOS apps **and a Tauri 2 desktop app for Windows 11 and macOS**. Treat all of them as maintained product surfaces.

- For every change to shared UI, visual design, navigation, features, playback behavior, configuration or the Rust core, assess its impact on both the native Apple apps and the Tauri 2 builds.
- When a change can affect the desktop experience, implement the corresponding updates in the Tauri React interface and/or Rust platform code in the same work. A native Apple UI redesign is incomplete until the applicable design changes reach Windows and macOS as well.
- Preserve appropriate platform-specific input, windowing, playback and credential-storage behavior. Record intentional platform differences in the documentation instead of silently leaving a platform behind.
- For affected Tauri changes, run frontend checks, build the affected Windows and macOS targets, and verify native playback/integration where the platform is available. Include desktop packaging and CI changes when needed. Report any unavailable platform or blocked verification explicitly; do not claim runtime verification from compilation alone.
- Keep desktop versions, README, changelog and verification/release documentation current alongside the Apple release workflow below.

### Required release workflow

**IMPORTANT**: After any code change, bug fix, or feature addition/removal, you MUST complete all of these steps:

1. **Update README.md** if the change affects:
   - Usage examples or commands
   - Installation instructions
   - Configuration options
   - Available features

2. **Update CHANGELOG.md**:
   - Add new version number following semantic versioning (MAJOR.MINOR.PATCH)
   - Add entry under appropriate category (Added, Changed, Fixed, Removed)
   - Include date in format YYYY-MM-DD

3. **Commit and push changes**:
   - Use `git add` to stage all modified files (README.md, CHANGELOG.md, and code files)
   - Create descriptive commit message following existing style
   - Push to remote repository with `git push`

4. **Build and upload to TestFlight after every version bump**:
   - Update the native Apple marketing version and increment the build number in `apps/apple/scripts/generate-project.py`, then regenerate the checked-in Xcode project.
   - Complete relevant verification, then build Release archives for **both VektorTV-iOS and VektorTV-tvOS** with a released Xcode.
   - Export and upload both archives to App Store Connect using the existing signing account and `apps/apple/Resources/ExportOptions.plist`. Follow `docs/apple-release.md` for commands.
   - Verify that Apple accepts and processes both uploads and that the builds are available to the existing **VektorTV Internal** TestFlight group.
   - Update release/verification documentation with the actual version, build number and distribution status, then commit and push those updates.
   - Do not leave a version bump at simulator-only verification or defer its TestFlight upload. If signing, authentication or Apple processing blocks distribution, report the exact blocker and completed steps without claiming the builds are available.
