# Vimeo Enforce Player

A Flutter widget that provides a Vimeo video player with enforced watch time. 

This package allows you to ensure that users watch a certain duration of a Vimeo video before they can proceed in your application.

## Features

*   **Enforced Watch Time**: Block users from seeking forward past the time they have already watched.
*   **Progress Callbacks**: Get real-time updates on watch progress, remaining time, and completion status.
*   **Resume Playback**: Asks users if they want to resume from where they left off or start over.
*   **Backend Integration**: Provides hooks to periodically save user's watch progress to your backend.
*   **Customizable**: Works with any state management solution and allows you to control the UI.

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  vimeo_enforce: ^1.0.0 # Replace with the actual version
```

Then, run `flutter pub get`.

## Usage

Here is a basic example of how to use the `VimeoPlayer` widget.

```dart
import 'package:flutter/material.dart';
import 'package:vimeo_enforce/vimeo_enforce.dart';

class VideoScreen extends StatefulWidget {
  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  int _remainingSeconds = 0;
  bool _canGoNext = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Vimeo Player")),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: VimeoPlayer(
              vimeoId: "your_vimeo_video_id", // <-- Your Vimeo Video ID
              enforceTime: 60.0,             // <-- Require 60 seconds of watch time
              timeSpended: 15.0,             // <-- User has already watched 15s
              onProgress: (remaining, canGo) {
                // Use this callback to update your UI
                setState(() {
                  _remainingSeconds = remaining;
                  _canGoNext = canGo;
                });
              },
              onEnforcedTimeMet: () {
                // Called once when the user meets the required watch time
                print("Enforced time has been met!");
                // You could permanently unlock the next button here
              },
              onUpdateWatchTime: (seconds, videoDuration) {
                // This is your hook to save progress to your backend
                print("User watched another $seconds seconds. Total duration: $videoDuration");
                // your_api.updateWatchTime(seconds);
              },
            ),
          ),
          // Your custom UI that reacts to the player's state
          if (!_canGoNext)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("Time remaining: $_remainingSeconds seconds"),
            ),
          ElevatedButton(
            onPressed: _canGoNext ? () => print("Moving to next lesson!") : null,
            child: Text("Next Lesson"),
          ),
        ],
      ),
    );
  }
}
```

### A Note on the Reference API Implementation

This package includes a file named `vimeo_enforce_with_personal_api_call.dart`. This file is **not part of the reusable package** but is provided as a reference.

It contains the original, more complex implementation that was tied to a specific state management solution (Controller) and included direct API calls. You can look at this file to see a complete, working example of how you might:

1.  Create a controller or state management class for your screen.
2.  Implement the `onUpdateWatchTime` callback to make a network request to your server.
3.  Manage the UI state based on the player's progress.

**Do not import this file directly.** Instead, use it as a guide to build your own logic in the `onUpdateWatchTime` and `onProgress` callbacks of the main `VimeoPlayer` widget.
