// import 'dart:async';
// import 'dart:convert';
// import 'package:acadle/utils/strings/api_end_points.dart';
//
// import 'package:flutter/material.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:http/http.dart' as http;
// import '../../../../../utils/api_helper/api_helper.dart';
// import '../../../cont/video/video_lesson_controller.dart';
//
//
// class Vimeo1 extends ConsumerStatefulWidget {
//   final String vimeoId;
//   final int lessonId;
//   final String videoId;
//   final double enforceTime;
//   final double timeSpended;
//   final String enforceType;
//
//   const Vimeo1({
//     super.key,
//     required this.vimeoId,
//     required this.lessonId,
//     required this.videoId,
//     required this.enforceTime,
//     required this.timeSpended,
//     required this.enforceType,
//   });
//
//   @override
//   ConsumerState<Vimeo1> createState() => _Vimeo1State();
// }
//
// class _Vimeo1State extends ConsumerState<Vimeo1> {
//   late InAppWebViewController webViewController;
//
//   double watchedSeconds = 0;
//   double? videoDuration;
//
//   double lastAllowedSecond = 0;
//   double previousMaxWatched = 0;
//   int lastApiCallSecond = -1;
//   int furthestApiCallSecond = -1;
//
//   bool canGoNext = false;
//   bool askResume = false;
//   bool showVideo = false;
//   bool isPlaying = false;
//   bool countdownFrozen = false;
//
//   bool isRecoveringFromError = false;
//
//   @override
//   void initState() {
//     super.initState();
//
//     watchedSeconds = widget.timeSpended;
//     lastAllowedSecond = watchedSeconds;
//     previousMaxWatched = watchedSeconds;
//     furthestApiCallSecond = watchedSeconds.floor();
//
//     if (widget.enforceType != "0") {
//       if (widget.timeSpended >= widget.enforceTime) {
//         canGoNext = true;
//         showVideo = true;
//       } else if (widget.timeSpended > 0) {
//         askResume = true;
//       } else {
//         showVideo = true;
//       }
//     } else {
//       showVideo = true;
//     }
//   }
//
//   String buildHtml(double startFrom) {
//     return '''
//   <html>
//   <head>
//   <meta name="viewport" content="width=device-width, initial-scale=0.6">
//   <style>
//     body, html { margin: 0; padding: 0; background-color: black; height: 100%; width: 100%; }
//     iframe { position: absolute; top: 0; left: 0; height: 100%; width: 100%; }
//   </style>
//   </head>
//   <body>
//     <iframe id="player" src="https://player.vimeo.com/video/${widget.vimeoId}#t=${startFrom}s"
//       width="100%" height="100%" frameborder="0" allow="autoplay; fullscreen" allowfullscreen></iframe>
//     <script src="https://player.vimeo.com/api/player.js"></script>
//     <script>
//       const iframe = document.getElementById('player');
//       const player = new Vimeo.Player(iframe);
//
//       let lastTime = ${startFrom};
//       let enforceLimit = ${widget.enforceTime};
//       let isSeeking = false;
//
//       function enforceSeek(data) {
//         const currentTime = data.seconds;
//         const duration = data.duration;
//
//         if (currentTime > enforceLimit) {
//           window.flutter_inappwebview.callHandler('timeUpdate', currentTime, duration);
//           return;
//         }
//
//         if (currentTime > lastTime + 1.5) {
//           isSeeking = true;
//           window.flutter_inappwebview.callHandler('videoEvent', 'seeking');
//           player.setCurrentTime(lastTime).then(() => {
//             player.play().then(() => {
//               isSeeking = false;
//               window.flutter_inappwebview.callHandler('videoEvent', 'play');
//             });
//           });
//         } else {
//           lastTime = currentTime;
//           window.flutter_inappwebview.callHandler('timeUpdate', currentTime, duration);
//         }
//       }
//
//       player.on('play', () => { if (!isSeeking) window.flutter_inappwebview.callHandler('videoEvent', 'play'); });
//       player.on('pause', () => { if (!isSeeking) window.flutter_inappwebview.callHandler('videoEvent', 'pause'); });
//       player.on('ended', () => { window.flutter_inappwebview.callHandler('videoEvent', 'finish'); });
//       player.on('timeupdate', enforceSeek);
//     </script>
//   </body>
//   </html>
//   ''';
//   }
//
//   void _handleTimeUpdate(double seconds, double duration) {
//     videoDuration = duration;
//     final currentSecond = seconds;
//
//     // Restrict skipping forward
//     if (widget.enforceType != "0" && currentSecond > lastAllowedSecond + 1) {
//       webViewController.evaluateJavascript(source: "player.setCurrentTime($lastAllowedSecond);");
//       return;
//     }
//
//     // Update max watched & freeze countdown when going back
//     if (currentSecond > previousMaxWatched) {
//       previousMaxWatched = currentSecond;
//       countdownFrozen = false;
//     } else if (currentSecond < previousMaxWatched) {
//       countdownFrozen = true;
//     }
//
//     if (currentSecond > lastAllowedSecond) {
//       lastAllowedSecond = currentSecond;
//     }
//
//     watchedSeconds = currentSecond;
//     int intSec = watchedSeconds.floor();
//
//     // API calls only when going forward into new territory
//     if (isPlaying &&
//         widget.enforceType != "0" && intSec % 5 == 0 &&
//         intSec != lastApiCallSecond &&
//         intSec <= widget.enforceTime + 5 &&
//         intSec > furthestApiCallSecond) {
//       lastApiCallSecond = intSec;
//       furthestApiCallSecond = intSec;
//
//       if (widget.enforceType == "1") {
//         _updateTimeSpend();
//       } else if (widget.enforceType == "2") {
//         _updateTimeWatched();
//       }
//     }
//
//     if (widget.enforceType != "0" && watchedSeconds >= widget.enforceTime) {
//       canGoNext = true;
//     }
//
//     setState(() {});
//
//     ref.read(videoLessonControllerProvider.notifier).onVideoProgress(
//       remainingTime: remainingSeconds,
//       canMoveToNextLesson: canGoNext,
//     );
//   }
//
//   int get remainingSeconds {
//     if (canGoNext) return 0;
//     double base = countdownFrozen ? previousMaxWatched : watchedSeconds;
//     double remain = widget.enforceTime - base;
//     return remain > 0 ? remain.ceil() : 0;
//   }
//
//
//   Future<void> _updateTimeSpend() async {
//     try {
//       await ref.read(apiHelperProvider).postRequest(
//         ApiEndPoints.updateTimeSpend,
//         {"lesson_id": widget.lessonId, "seconds": 5},
//       );
//     } catch (_) {}
//   }
//
//   Future<void> _updateTimeWatched() async {
//     try {
//       await http.post(
//         Uri.parse(ApiEndPoints.updateTimeWatched),
//         body: jsonEncode({
//           "lesson_id": widget.lessonId,
//           "video_id": widget.videoId,
//           "duration": videoDuration,
//           "seconds": 5,
//         }),
//         headers: {'Content-Type': 'application/json'},
//       );
//     } catch (_) {}
//   }
//
//   void reloadVideo(double fromSecond) async {
//     await webViewController.loadData(data: buildHtml(fromSecond));
//     isRecoveringFromError = false;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         if (askResume && !showVideo)
//           AlertDialog(
//             title: Text("Resume Video"),
//             content: Text("You previously watched till ${widget.timeSpended.toInt()}s. Resume or start over?"),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   setState(() {
//                     watchedSeconds = 0;
//                     lastAllowedSecond = 0;
//                     previousMaxWatched = 0;
//                     furthestApiCallSecond = 0;
//                     countdownFrozen = false;
//                     askResume = false;
//                     showVideo = true;
//                     canGoNext = false;
//                   });
//                   // 🔥 Reset controller state too
//                   ref.read(videoLessonControllerProvider.notifier).onVideoProgress(
//                     remainingTime: widget.enforceTime.toInt(),
//                     canMoveToNextLesson: false,
//                   );
//
//                   reloadVideo(0);
//                 },
//                 child: Text("Start Over"),
//               ),
//               TextButton(
//                 onPressed: () {
//                   setState(() {
//                     watchedSeconds = widget.timeSpended;
//                     lastAllowedSecond = widget.timeSpended;
//                     previousMaxWatched = widget.timeSpended;
//                     furthestApiCallSecond = widget.timeSpended.floor();
//                     countdownFrozen = false;
//                     askResume = false;
//                     showVideo = true;
//                   });
//                   reloadVideo(watchedSeconds);
//                 },
//                 child: Text("Resume"),
//               ),
//             ],
//           ),
//
//         if (showVideo)
//           Expanded(
//             child: InAppWebView(
//               initialData: InAppWebViewInitialData(data: buildHtml(watchedSeconds)),
//               initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
//               onWebViewCreated: (controller) {
//                 webViewController = controller;
//
//                 controller.addJavaScriptHandler(
//                   handlerName: "videoEvent",
//                   callback: (args) {
//                     final event = args[0];
//                     if (event == "play") {
//                       isPlaying = true;
//                     }
//                     if (event == "pause" || event == "finish" || event == "seeking") {
//                       isPlaying = false;
//                     }
//                   },
//                 );
//
//                 controller.addJavaScriptHandler(
//                   handlerName: "timeUpdate",
//                   callback: (args) {
//                     final seconds = args[0] as double;
//                     final duration = args[1] as double;
//                     _handleTimeUpdate(seconds, duration);
//                   },
//                 );
//               },
//               onReceivedError: (controller, request, error) {
//                 if (!isRecoveringFromError) {
//                   isRecoveringFromError = true;
//                   reloadVideo(lastAllowedSecond);
//                 }
//               },
//             ),
//           ),
//
//         if (widget.enforceType != "0" && !canGoNext)
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Text(
//               "Remaining: ${remainingSeconds}s",
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
//             ),
//           ),
//
//         if (canGoNext)
//           ElevatedButton(
//             onPressed: () {
//               // Handle next lesson logic
//             },
//             child: Text("Next Lesson"),
//           ),
//       ],
//     );
//   }
// }