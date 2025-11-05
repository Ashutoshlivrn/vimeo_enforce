import 'package:flutter/material.dart';
import 'package:vimeo_enforce/vimeo_enforce.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vimeo Enforce Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: VideoScreen(),
    );
  }
}

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
      appBar: AppBar(title: Text("Vimeo Player Example")),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: VimeoPlayer(
              // IMPORTANT: Replace this with your actual Vimeo Video ID
              vimeoId: "824804225", 
              enforceTime: 60.0,             // Require 60 seconds of watch time
              timeSpended: 15.0,             // User has already watched 15s
              enforceType: "1",              // Enforce the watch time

              onProgress: (remaining, canGo) {
                // Use this callback to update your UI
                setState(() {
                  _remainingSeconds = remaining;
                  _canGoNext = canGo;
                });
                print("Remaining: $remaining, Can go: $canGo");
              },
              onEnforcedTimeMet: () {
                // Called once when the user meets the required watch time
                print("Enforced time has been met!");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Video complete! You can now proceed.")),
                );
              },
              onUpdateWatchTime: (seconds, videoDuration) {
                // This is your hook to save progress to your backend
                print("User watched another $seconds seconds. Total duration: $videoDuration");
                // In a real app, you would make an API call here:
                // your_api.updateWatchTime(seconds);
              },
            ),
          ),
          const SizedBox(height: 20),
          // Your custom UI that reacts to the player's state
          if (!_canGoNext)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Time remaining: $_remainingSeconds seconds",
                 style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ElevatedButton(
            onPressed: _canGoNext ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Moving to next lesson!")),
                );
            } : null,
            child: Text("Next Lesson"),
          ),
        ],
      ),
    );
  }
}
