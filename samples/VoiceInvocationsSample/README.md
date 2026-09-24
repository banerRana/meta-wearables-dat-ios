# Voice Invocations Sample App

A sample iOS application demonstrating integration with Meta Wearables Device Access Toolkit. This app shows how to receive Hey Meta voice invocations from the glasses via `VoiceInvocationsStream`, queue them, present each one to the user for approval, and acknowledge the outcome back to the glasses. The app is registered with the Wearables Developer Center under the name **Echo** so the voice command "Hey Meta, start Echo" routes to it.

## Features

- Connect to Meta AI glasses
- Receive voice invocations from the glasses via `VoiceInvocationsStream`, including invocations that trigger a cold launch
- Queue incoming invocations and present them one at a time
- Approve or reject each invocation and acknowledge the outcome (`sendSuccess` / `sendFailure`) back to the glasses
- Manage device registration and connection states

## Prerequisites

- iOS 17.2+
- Xcode 26.4+
- Swift 6.3+
- Meta Wearables Device Access Toolkit (included as a dependency)
- A Meta AI glasses device for testing
- [Meta AI app](https://apps.apple.com/us/app/meta-ai/id6472740148) installed on the paired iPhone (voice-invocation routing runs through Meta AI)
- App registered in the [Wearables Developer Center](https://wearables.developer.meta.com/) with the **Voice Invocation** permission approved for this bundle identifier. The suggested app name for this sample is **Echo** — you can choose a different name, but review [Known issues](#known-issues) first (e.g. names containing "AI" are not supported)

## Building the app

- Before running on a device, select your Apple development team, use the bundle identifier registered in Wearables Developer Center, and set `META_APP_ID` and `CLIENT_TOKEN`. Voice invocations do not support Developer Mode.

### Using Xcode

1. Clone this repository
2. Open the project in Xcode
3. Select your target device
4. Click the "Build" button or press `Cmd+B` to build the project
5. To run the app, click the "Run" button (▶️) or press `Cmd+R`

## Running the app

1. Install and launch the app once so it can register with the SDK.
2. Press the "Register" button to complete app registration and connect your glasses.
3. On the glasses, say "**Hey Meta, start Echo**" (or "**Hey Meta, launch Echo**").
4. The invocation appears in the app; approve or reject it to acknowledge back to the glasses.

## Known issues

- **Developer Mode is not supported.** Turning on Developer Mode in the Meta AI app breaks voice-invocation routing to third-party apps; keep it off when testing this sample.
- **App names containing "AI" do not route correctly.** Do not use "AI" (or any variant containing it, e.g. "Echo AI") as the WDC-registered app name — the phrase is intercepted by the assistant and never reaches your app.

## Troubleshooting

For issues related to the Meta Wearables Device Access Toolkit, please refer to the [developer documentation](https://wearables.developer.meta.com/docs/develop/) or visit our [discussions forum](https://github.com/facebook/meta-wearables-dat-ios/discussions)

## License

This source code is licensed under the license found in the LICENSE file in the root directory of this source tree.
