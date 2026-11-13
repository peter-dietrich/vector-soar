# Vector Soar

An original, Joust-inspired aerial combat arcade game for macOS and the Fun City launcher, built with SwiftUI and SpriteKit. Procedural geometric flightcraft, no borrowed graphics, trademarks, music, or arcade ROMs.

## First playable prototype

- Tap **Space** to flap; use **Left / Right** or **A / D** to steer.
- Hold **Shift** for a gravity-assisted dive.
- Hit enemy craft from above to defeat them and raise combo multipliers.
- Collect dropped energy cores for bonus points.
- Survive enemy waves; three lives; escalating enemy speed and elite flyers.
- **Return** starts/restarts, **P** pauses.
- Right-side flight telemetry, faint environmental parallax, responsive particle explosions and persistent local high score.

## Build and play

Open `VectorSoar.xcodeproj` in Xcode 16+ and select **VectorSoar → My Mac → Run**.

```sh
xcodebuild -project VectorSoar.xcodeproj -scheme VectorSoar -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

For Fun City local development, select the built `VectorSoar.app` using **LOCATE GAME**, if automatic app discovery is unavailable. Bundle ID: `io.vectorsoar.game`.

**Status:** Unverified first playable prototype; still requires a successful macOS build and hands-on gameplay testing. A signed/notarized GitHub Release is not yet available; Fun City download action requires one.
