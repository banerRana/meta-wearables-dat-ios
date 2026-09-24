# Sensors Sample App

A sample iOS application demonstrating the sensor capabilities of the Meta Wearables Device Access Toolkit. "Sensors Playground" is a single screen that visualizes three live sensor streams from Meta AI glasses at once:

- **Motion** — a wireframe pair of glasses that rotates in real time, driven by the device IMU orientation (`Motion` / `MotionSample.orientation`).
- **Inputs** — an on-screen grid of controls that flash and log as you tap, press, and swipe the glasses (`Inputs` / `InputEvent`).
- **Speech** — a live transcription caption of what the glasses microphone hears (`Speech` / `TranscriptionResult`), shown after you grant microphone access.

The whole app runs against the real DAT SDK. A real device is the default; a `#if DEBUG` MockDeviceKit affordance lets you drive every stream with no glasses.

## Features

- Connect to Meta AI glasses and observe registration/session state
- Rotate a wireframe glasses model from the live IMU orientation quaternion
- Light up on-screen input controls from cap-touch, action button, capture button, and Neural Band events
- Request microphone permission, then show a live speech-transcription caption
- Debug-only MockDeviceKit sheet to pair a simulated device, power it on, and inject inputs while host motion and host speech recognition drive the live sensors

## Prerequisites

- iOS 17.2+
- Xcode 26.4+
- Swift 6.3+
- Meta Wearables Device Access Toolkit (included as a dependency)
- A Meta AI glasses device for testing (or use the MockDeviceKit debug affordance)
- [Meta AI app](https://apps.apple.com/us/app/meta-ai/id6472740148) installed on the paired iPhone (registration and permission flows route through Meta AI)
- App registered in the [Wearables Developer Center](https://wearables.developer.meta.com/) with the **Motion**, **Inputs**, and **Speech** capabilities approved for this bundle identifier

## Building the app

- Before running on a device, select your Apple development team, use the bundle identifier registered in Wearables Developer Center, and set `META_APP_ID` and `CLIENT_TOKEN`.

### Using Xcode

1. Clone this repository
2. Open `SensorsSample.xcodeproj` in Xcode
3. Select your target device
4. Build and run (`Cmd+R`)

## Running the app

1. Install and launch the app once so it can register with the SDK.
2. Tap "Connect my glasses" to complete app registration and connect your glasses.
3. Put on your glasses. The wireframe follows your head movement, and input events light up the on-screen controls.
4. Tap "Enable microphone" to grant microphone access and start the live transcription caption.

### Testing without glasses (DEBUG builds)

1. Tap the debug button to open the MockDeviceKit sheet.
2. Enable MockDeviceKit, then tap "Power on & wear" to pair and activate a Ray-Ban Meta device in one step.
3. Once the mock glasses are powered on and worn, motion follows the host device automatically, speech uses the host microphone, and inputs can be injected from the sheet.
4. Tap "Power off" to exit mock mode and return the app to real-glasses pairing.

## Troubleshooting

For issues related to the Meta Wearables Device Access Toolkit, please refer to the [developer documentation](https://wearables.developer.meta.com/docs/develop/) or visit our [discussions forum](https://github.com/facebook/meta-wearables-dat-ios/discussions)

## License

This source code is licensed under the license found in the LICENSE file in the root directory of this source tree.
