# Vonage Video Bridge for Flutter

This plugin wraps the official native Vonage/OpenTok Video SDKs instead of relying on an untrusted Flutter package.

## What This Gives You

- Android native SDK: `com.opentok.android:opentok-android-sdk:2.32.1`
- iOS native SDK: `OpenTok`, `2.32.1`
- Flutter API for connect, publish, mute audio/video, switch camera, disconnect
- Native platform view that renders remote video full size and local preview in the top-right corner

## Add The Plugin To Your Flutter App

Put this folder beside your Flutter app, then add it to your app `pubspec.yaml`:

```yaml
dependencies:
  vonage_video_bridge:
    path: ../vonage_video_bridge
```

Then run:

```sh
flutter pub get
```

## Android Setup

In your app `android/app/src/main/AndroidManifest.xml`, add:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

Make sure your app uses AndroidX and has `minSdkVersion 23` or higher.

For production, request camera and microphone permissions from Flutter before calling `connect`. The plugin also asks natively, but your app should own the permission UX.

## iOS Setup

In your app `ios/Runner/Info.plist`, add:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is required for video calls.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone is required for video calls.</string>
```

Then run:

```sh
cd ios
pod install
```

## Backend Requirement

Do not generate Vonage tokens in Flutter. Your backend should create:

- `applicationId`
- `sessionId`
- `token`

The Flutter app receives those values from your backend and passes them to the plugin.

## Flutter Usage

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vonage_video_bridge/vonage_video_bridge.dart';

class CallPage extends StatefulWidget {
  const CallPage({
    super.key,
    required this.applicationId,
    required this.sessionId,
    required this.token,
  });

  final String applicationId;
  final String sessionId;
  final String token;

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  StreamSubscription<VonageVideoEvent>? _events;
  bool _audioEnabled = true;
  bool _videoEnabled = true;

  @override
  void initState() {
    super.initState();

    _events = VonageVideoBridge.events.listen((event) {
      debugPrint('Vonage event: ${event.type} ${event.message ?? ''}');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await VonageVideoBridge.connect(
        applicationId: widget.applicationId,
        sessionId: widget.sessionId,
        token: widget.token,
        publisherName: 'User',
      );
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    VonageVideoBridge.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(child: VonageVideoView()),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: () async {
                    setState(() => _audioEnabled = !_audioEnabled);
                    await VonageVideoBridge.setAudioEnabled(_audioEnabled);
                  },
                  icon: Icon(_audioEnabled ? Icons.mic : Icons.mic_off),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: () async {
                    setState(() => _videoEnabled = !_videoEnabled);
                    await VonageVideoBridge.setVideoEnabled(_videoEnabled);
                  },
                  icon: Icon(_videoEnabled ? Icons.videocam : Icons.videocam_off),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: VonageVideoBridge.switchCamera,
                  icon: const Icon(Icons.cameraswitch),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    await VonageVideoBridge.disconnect();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.call_end),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## Notes Before Production

- This bridge subscribes to the first remote stream. If your app supports group calls, extend the native controller to manage a list of subscribers.
- Add stronger permission handling in Flutter with a package such as `permission_handler`.
- Keep token creation on your backend.
- Pin SDK versions first, then upgrade deliberately after testing calls on real iOS and Android devices.
- Run on real devices. Simulators/emulators are not reliable for camera/audio validation.
