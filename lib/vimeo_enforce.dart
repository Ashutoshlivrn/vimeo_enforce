import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// A Vimeo player widget with enforced watch time.
///
/// This widget embeds a Vimeo player and ensures the user watches a specified
/// duration of the video before they can proceed. It provides callbacks for
/// progress updates and completion events.
class VimeoPlayer extends StatefulWidget {
  /// The ID of the Vimeo video.
  final String vimeoId;

  /// The total time in seconds the user has already spent watching the video.
  final double timeSpended;

  /// The required watch time in seconds.
  final double enforceTime;

  /// The type of enforcement.
  /// "0": No enforcement.
  /// "1" or "2": Enforce watching up to `enforceTime`.
  /// The distinction between "1" and "2" was originally for different API calls,
  /// but is now handled by the user of this package via [onUpdateWatchTime].
  final String enforceType;

  /// Callback to update the parent widget with the current progress.
  /// Provides the remaining seconds to watch and a flag indicating if the
  /// enforcement time has been met.
  final void Function(int remainingSeconds, bool canMoveToNextLesson) onProgress;

  /// Callback triggered when the required watch time has been met.
  final VoidCallback onEnforcedTimeMet;

  /// Callback for periodically updating the backend with watch time.
  ///
  /// This is typically called every 5 seconds of new watch time.
  /// The user of this package should implement the API call logic here.
  /// `seconds`: The increment of time watched (usually 5 seconds).
  /// `videoDuration`: The total duration of the video.
  final void Function(int seconds, double? videoDuration) onUpdateWatchTime;


  const VimeoPlayer({
    super.key,
    required this.vimeoId,
    required this.onProgress,
    required this.onEnforcedTimeMet,
    required this.onUpdateWatchTime,
    this.timeSpended = 0.0,
    this.enforceTime = 0.0,
    this.enforceType = "0",
  });

  @override
  State<VimeoPlayer> createState() => _VimeoPlayerState();
}

class _VimeoPlayerState extends State<VimeoPlayer> {
  late InAppWebViewController webViewController;

  double watchedSeconds = 0;
  double? videoDuration;

  double lastAllowedSecond = 0;
  double previousMaxWatched = 0;
  int lastApiCallSecond = -1;
  int furthestApiCallSecond = -1;

  bool canGoNext = false;
  bool askResume = false;
  bool showVideo = false;
  bool isPlaying = false;
  bool countdownFrozen = false;

  bool isRecoveringFromError = false;

  @override
  void initState() {
    super.initState();

    watchedSeconds = widget.timeSpended;
    lastAllowedSecond = watchedSeconds;
    previousMaxWatched = watchedSeconds;
    furthestApiCallSecond = watchedSeconds.floor();

    if (widget.enforceType != "0") {
      if (widget.timeSpended >= widget.enforceTime) {
        canGoNext = true;
        showVideo = true;
        // Directly call onEnforcedTimeMet if already completed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onEnforcedTimeMet();
          widget.onProgress(0, true);
        });
      } else if (widget.timeSpended > 0) {
        askResume = true;
      } else {
        showVideo = true;
      }
    } else {
      showVideo = true;
      canGoNext = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onEnforcedTimeMet();
        widget.onProgress(0, true);
      });
    }
  }

  String buildHtml(double startFrom) {
    // The JavaScript inside the HTML handles seek prevention.
    return '''
  <html>
  <head>
  <meta name="viewport" content="width=device-width, initial-scale=0.6">
  <style>
    body, html { margin: 0; padding: 0; background-color: black; height: 100%; width: 100%; }
    iframe { position: absolute; top: 0; left: 0; height: 100%; width: 100%; }
  </style>
  </head>
  <body>
    <iframe id="player" src="https://player.vimeo.com/video/${widget.vimeoId}#t=${startFrom}s" 
      width="100%" height="100%" frameborder="0" allow="autoplay; fullscreen" allowfullscreen></iframe>
    <script src="https://player.vimeo.com/api/player.js"></script>
    <script>
      const iframe = document.getElementById('player');
      const player = new Vimeo.Player(iframe);

      let lastTime = ${startFrom};
      // Allow seeking beyond the enforce limit if it exists
      const enforceLimit = ${widget.enforceType != "0" ? widget.enforceTime : 'Infinity'};
      let isSeeking = false;

      function enforceSeek(data) {
        const currentTime = data.seconds;
        const duration = data.duration;

        // If enforcement is off, or if we are past the enforcement time, just send updates.
        if (enforceLimit === Infinity || currentTime > enforceLimit) {
          window.flutter_inappwebview.callHandler('timeUpdate', currentTime, duration);
          return;
        }
        
        // Prevent seeking forward beyond the watched time.
        // A small buffer (1.5s) is added to allow for normal playback buffering.
        if (currentTime > lastTime + 1.5) {
          isSeeking = true;
          window.flutter_inappwebview.callHandler('videoEvent', 'seeking');
          player.setCurrentTime(lastTime).then(() => {
            player.play().then(() => {
              isSeeking = false;
              window.flutter_inappwebview.callHandler('videoEvent', 'play');
            });
          }).catch(function(error) {
             isSeeking = false; // reset on error
          });
        } else {
          lastTime = currentTime;
          window.flutter_inappwebview.callHandler('timeUpdate', currentTime, duration);
        }
      }

      player.on('play', () => { if (!isSeeking) window.flutter_inappwebview.callHandler('videoEvent', 'play'); });
      player.on('pause', () => { if (!isSeeking) window.flutter_inappwebview.callHandler('videoEvent', 'pause'); });
      player.on('ended', () => { window.flutter_inappwebview.callHandler('videoEvent', 'finish'); });
      player.on('timeupdate', enforceSeek);
    </script>
  </body>
  </html>
  ''';
  }

  void _handleTimeUpdate(double seconds, double duration) {
    if (!mounted) return;

    videoDuration = duration;
    final currentSecond = seconds;
    
    // This client-side check is a fallback for the JavaScript logic.
    if (widget.enforceType != "0" && currentSecond > lastAllowedSecond + 1.5) {
      webViewController.evaluateJavascript(source: "player.setCurrentTime($lastAllowedSecond);");
      return;
    }
    
    if (currentSecond > previousMaxWatched) {
      previousMaxWatched = currentSecond;
      countdownFrozen = false;
    } else if (currentSecond < previousMaxWatched) {
      countdownFrozen = true;
    }

    if (currentSecond > lastAllowedSecond) {
      lastAllowedSecond = currentSecond;
    }

    watchedSeconds = currentSecond;
    int intSec = watchedSeconds.floor();

    // API calls only when going forward into new territory
    if (isPlaying &&
        widget.enforceType != "0" &&
        intSec % 5 == 0 &&
        intSec != lastApiCallSecond &&
        intSec <= widget.enforceTime + 5 &&
        intSec > furthestApiCallSecond) {
      lastApiCallSecond = intSec;
      furthestApiCallSecond = intSec;
      
      // Use the callback to let the user handle the API call
      widget.onUpdateWatchTime(5, videoDuration);
    }
    
    bool wasCompleted = canGoNext;
    if (widget.enforceType != "0") {
        if (watchedSeconds >= widget.enforceTime) {
            canGoNext = true;
        }
    } else {
        canGoNext = true;
    }

    // If the state changed to completed, call the callback
    if (canGoNext && !wasCompleted) {
      widget.onEnforcedTimeMet();
    }

    setState(() {}); // Update our UI (like remaining seconds)

    // Call progress callback
    widget.onProgress(remainingSeconds, canGoNext);
  }

  int get remainingSeconds {
    if (canGoNext) return 0;
    double base = countdownFrozen ? previousMaxWatched : watchedSeconds;
    double remain = widget.enforceTime - base;
    return remain > 0 ? remain.ceil() : 0;
  }

  void reloadVideo(double fromSecond) async {
    if (mounted) {
      await webViewController.loadData(data: buildHtml(fromSecond));
      isRecoveringFromError = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (askResume && !showVideo)
          AlertDialog(
            title: const Text("Resume Video"),
            content: Text("You previously watched till ${widget.timeSpended.toInt()}s. Resume or start over?"),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    watchedSeconds = 0;
                    lastAllowedSecond = 0;
                    previousMaxWatched = 0;
                    furthestApiCallSecond = 0;
                    countdownFrozen = false;
                    askResume = false;
                    showVideo = true;
                    canGoNext = false;
                  });

                  widget.onProgress(widget.enforceTime.toInt(), false);
                  reloadVideo(0);
                },
                child: const Text("Start Over"),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    watchedSeconds = widget.timeSpended;
                    lastAllowedSecond = widget.timeSpended;
                    previousMaxWatched = widget.timeSpended;
                    furthestApiCallSecond = widget.timeSpended.floor();
                    countdownFrozen = false;
                    askResume = false;
                    showVideo = true;
                  });
                  reloadVideo(watchedSeconds);
                },
                child: const Text("Resume"),
              ),
            ],
          ),

        if (showVideo)
          Expanded(
            child: InAppWebView(
              initialData: InAppWebViewInitialData(data: buildHtml(watchedSeconds)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
              ),
              onWebViewCreated: (controller) {
                webViewController = controller;

                controller.addJavaScriptHandler(
                  handlerName: "videoEvent",
                  callback: (args) {
                    final event = args[0];
                    if (event == "play") {
                      isPlaying = true;
                    }
                    if (event == "pause" || event == "finish" || event == "seeking") {
                      isPlaying = false;
                    }
                  },
                );

                controller.addJavaScriptHandler(
                  handlerName: "timeUpdate",
                  callback: (args) {
                    final seconds = args[0] as double;
                    final duration = args[1] as double;
                    _handleTimeUpdate(seconds, duration);
                  },
                );
              },
              onReceivedError: (controller, request, error) {
                if (!isRecoveringFromError && mounted) {
                  isRecoveringFromError = true;
                  reloadVideo(lastAllowedSecond);
                }
              },
            ),
          ),
        
        // The user of the package can use the onProgress callback to display this
        // information in their own UI.
        // if (widget.enforceType != "0" && !canGoNext)
        //   Padding(
        //     padding: const EdgeInsets.all(8.0),
        //     child: Text(
        //       "Remaining: ${remainingSeconds}s",
        //       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        //     ),
        //   ),
      ],
    );
  }
}
