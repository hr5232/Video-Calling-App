import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

// Fill in the App ID obtained from the Agora Console
const appId = "f960e725feac454f8cba4633f5347af8"; // Replace with your Agora App ID

// Application class
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

// Home page for creating/joining a channel
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _channelController = TextEditingController();
  bool _validateError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart health'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Channel name input
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: TextField(
                controller: _channelController,
                decoration: InputDecoration(
                  errorText: _validateError ? 'Channel name is mandatory' : null,
                  border: const OutlineInputBorder(),
                  hintText: 'Enter Channel Name',
                ),
              ),
            ),
            // Join button
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _channelController.text.isEmpty
                      ? _validateError = true
                      : _validateError = false;
                });
                if (!_validateError) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoCallPage(
                        channelName: _channelController.text,
                      ),
                    ),
                  );
                }
              },
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}

// Video call page
class VideoCallPage extends StatefulWidget {
  final String channelName;

  const VideoCallPage({Key? key, required this.channelName}) : super(key: key);

  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  int? _remoteUid; // The UID of the remote user
  bool _localUserJoined = false; // Indicates whether the local user has joined the channel
  late RtcEngine _engine; // The RtcEngine instance
  bool _muted = false; // Indicates whether the microphone is muted

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    // Request permissions for microphone and camera
    await [Permission.microphone, Permission.camera].request();

    // Create the RtcEngine instance
    _engine = await createAgoraRtcEngine();

    // Initialize the RtcEngine
    await _engine.initialize(const RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // Register event handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('local user joined: ${connection.localUid}');
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('remote user joined: $remoteUid');
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint('remote user left: $remoteUid');
          setState(() {
            _remoteUid = null;
          });
        },
      ),
    );

    // Enable video
    await _engine.enableVideo();

    // Join the channel
    await _engine.joinChannel(
      token: "", // No token required
      channelId: widget.channelName,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
      uid: 0, // Generate a random UID
    );
  }

  @override
  void dispose() {
    super.dispose();
    _dispose();
  }

  Future<void> _dispose() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
    });
    _engine.muteLocalAudioStream(_muted);
  }

  void _switchCamera() {
    _engine.switchCamera();
  }

  void _endCall() {
    _dispose();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call'),
        actions: [
          // End Call Button
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.red),
            onPressed: _endCall,
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(child: _remoteVideo()),
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              height: 150,
              child: Center(
                child: _localUserJoined
                    ? AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _engine,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute Button
                  FloatingActionButton(
                    onPressed: _toggleMute,
                    backgroundColor: _muted ? Colors.red : Colors.white,
                    child: Icon(
                      _muted ? Icons.mic_off : Icons.mic,
                    ),
                  ),
                  // Switch Camera Button
                  FloatingActionButton(
                    onPressed: _switchCamera,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.cameraswitch),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Remote video widget
  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    } else {
      return const Text(
        'Please wait for remote user to join',
        textAlign: TextAlign.center,
      );
    }
  }
}
