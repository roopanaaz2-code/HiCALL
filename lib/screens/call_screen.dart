import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/call_service.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/slide_action.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.credentials,
    required this.remoteName,
    this.remoteAvatarPath,
  });

  final CallCredentials credentials;
  final String remoteName;
  final String? remoteAvatarPath;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final Room room;
  late CallCredentials _credentials;
  EventsListener<RoomEvent>? _roomListener;
  RealtimeChannel? _callStateChannel;
  Timer? _callTimer;
  DateTime? _connectedAt;
  VideoTrack? _remoteVideoTrack;

  bool connecting = true;
  bool connected = false;
  bool reconnecting = false;
  bool muted = false;
  bool cameraOn = false;
  bool ending = false;
  String? error;
  Duration elapsed = Duration.zero;

  bool get _isVideoCall => widget.credentials.callType == 'video';

  @override
  void initState() {
    super.initState();
    room = Room();
    _credentials = widget.credentials;
    unawaited(WakelockPlus.enable());
    _listenToRoom();
    _callStateChannel = CallService.instance.watchCallStatus(
      widget.credentials.callId,
      _onCallStatus,
    );
    unawaited(connect());
  }

  void _listenToRoom() {
    _roomListener = room.createListener()
      ..on<ParticipantConnectedEvent>((_) => _refreshRemoteVideo())
      ..on<ParticipantDisconnectedEvent>((_) => _refreshRemoteVideo())
      ..on<TrackPublishedEvent>((_) => _refreshRemoteVideo())
      ..on<TrackUnpublishedEvent>((_) => _refreshRemoteVideo())
      ..on<TrackSubscribedEvent>((_) => _refreshRemoteVideo())
      ..on<TrackUnsubscribedEvent>((_) => _refreshRemoteVideo())
      ..on<TrackMutedEvent>((_) => _refreshRemoteVideo())
      ..on<TrackUnmutedEvent>((_) => _refreshRemoteVideo())
      ..on<RoomReconnectingEvent>((_) {
        if (!mounted || ending) return;
        setState(() => reconnecting = true);
      })
      ..on<RoomReconnectedEvent>((_) {
        if (!mounted || ending) return;
        setState(() {
          reconnecting = false;
          connected = true;
          connecting = false;
          error = null;
        });
        _refreshRemoteVideo();
      })
      ..on<RoomDisconnectedEvent>((_) {
        if (!mounted || ending) return;
        setState(() {
          connected = false;
          reconnecting = false;
          connecting = false;
          error = 'The call was disconnected.';
          _remoteVideoTrack = null;
        });
      });
  }

  void _onCallStatus(String status) {
    if (!mounted || ending) return;
    if (status == 'ended' ||
        status == 'declined' ||
        status == 'missed' ||
        status == 'cancelled') {
      unawaited(_finishRemoteCall());
    }
  }

  Future<void> _finishRemoteCall() async {
    if (!mounted || ending) return;
    setState(() => ending = true);
    _callTimer?.cancel();
    try {
      await room.disconnect();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> connect() async {
    try {
      if (_credentials.token.isEmpty) {
        if (mounted) setState(() { connecting = true; connected = false; });
        await CallService.instance.waitForAcceptance(_credentials.callId);
        if (!mounted || ending) return;
        _credentials = await CallService.instance.joinCall(_credentials.callId);
      }
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        throw _PermissionFailure(
          micPermission.isPermanentlyDenied
              ? 'Microphone access is blocked. Enable it in Settings to place calls.'
              : 'Microphone permission is required to place a call.',
        );
      }

      if (_isVideoCall) {
        final cameraPermission = await Permission.camera.request();
        if (!cameraPermission.isGranted) {
          throw _PermissionFailure(
            cameraPermission.isPermanentlyDenied
                ? 'Camera access is blocked. Enable it in Settings to place video calls.'
                : 'Camera permission is required for video calls.',
          );
        }
      }
      if (!mounted || ending) return;

      await room.connect(_credentials.serverUrl, _credentials.token);
      if (!mounted || ending) {
        try {
          await room.disconnect();
        } catch (_) {}
        return;
      }

      await room.localParticipant?.setMicrophoneEnabled(true);
      if (!mounted || ending) {
        try {
          await room.disconnect();
        } catch (_) {}
        return;
      }
      if (_isVideoCall) {
        await room.localParticipant?.setCameraEnabled(true);
      }
      if (!mounted || ending) return;

      setState(() {
        connected = true;
        reconnecting = false;
        connecting = false;
        cameraOn = _isVideoCall;
        muted = false;
        error = null;
      });
      _startCallTimer();
      _refreshRemoteVideo();
    } on _PermissionFailure catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        connecting = false;
        connected = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Could not connect to the call. Check your internet connection and try again.';
        connecting = false;
        connected = false;
        reconnecting = false;
      });
    }
  }

  void _startCallTimer() {
    if (_connectedAt != null) return;
    _connectedAt = DateTime.now();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _connectedAt == null) return;
      setState(() => elapsed = DateTime.now().difference(_connectedAt!));
    });
  }

  void _refreshRemoteVideo() {
    VideoTrack? firstTrack;
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (!publication.isScreenShare && !publication.muted && track != null) {
          firstTrack = track;
          break;
        }
      }
      if (firstTrack != null) break;
    }

    if (!mounted || identical(firstTrack, _remoteVideoTrack)) return;
    setState(() => _remoteVideoTrack = firstTrack);
  }

  Future<void> toggleMic() async {
    if (!connected || ending) return;
    final nextMuted = !muted;
    try {
      await room.localParticipant?.setMicrophoneEnabled(!nextMuted);
      if (mounted) setState(() => muted = nextMuted);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Unable to change microphone settings. Check microphone permission.');
      }
    }
  }

  Future<void> toggleCamera() async {
    if (!connected || ending) return;
    final nextCameraOn = !cameraOn;
    try {
      if (nextCameraOn) {
        final permission = await Permission.camera.request();
        if (!permission.isGranted) {
          if (mounted) {
            setState(() {
              error = permission.isPermanentlyDenied
                  ? 'Camera access is blocked. Enable it in Settings to turn on video.'
                : 'Camera permission is required to turn on video.';
            });
          }
          return;
        }
        if (!mounted || ending) return;
      }
      await room.localParticipant?.setCameraEnabled(nextCameraOn);
      if (mounted) setState(() => cameraOn = nextCameraOn);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Unable to change camera settings. Check camera permission.');
      }
    }
  }

  Future<void> hangUp() async {
    if (ending) return;
    setState(() => ending = true);
    _callTimer?.cancel();
    try {
      await CallService.instance.endCall(widget.credentials.callId);
    } catch (_) {
      // Always release local media even if the network is unavailable.
    }
    try {
      await room.disconnect();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _disposeRoom() async {
    final listener = _roomListener;
    _roomListener = null;
    if (listener != null) await listener.dispose();
    try {
      await room.disconnect();
    } catch (_) {}
    await room.dispose();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    final channel = _callStateChannel;
    _callStateChannel = null;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel).then<void>((_) {}));
    }
    unawaited(WakelockPlus.disable());
    unawaited(_disposeRoom());
    super.dispose();
  }

  String get _statusLabel {
    if (ending) return 'Ending call…';
    if (reconnecting) return 'Reconnecting…';
    if (connecting) return widget.credentials.token.isEmpty ? 'Waiting for answer…' : 'Connecting…';
    if (connected) return 'Connected';
    return error == null ? 'Call ended' : 'Unable to connect';
  }

  String get _elapsedLabel {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  LocalVideoTrack? get _localCameraTrack {
    final publications = room.localParticipant?.videoTrackPublications ?? const [];
    for (final publication in publications) {
      if (publication.source == TrackSource.camera && publication.track != null) {
        return publication.track;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF070D1B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF070D1B),
          leading: const SizedBox.shrink(),
          title: Text(_isVideoCall ? 'Video call' : 'Audio call'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _isVideoCall ? _buildVideoCall() : _buildAudioCall(),
        ),
      ),
    );
  }

  Widget _buildVideoCall() {
    final remoteTrack = _remoteVideoTrack;
    final localTrack = cameraOn ? _localCameraTrack : null;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFF111C31)),
                  if (remoteTrack != null)
                    VideoTrackRenderer(
                      remoteTrack,
                      key: ObjectKey(remoteTrack),
                      fit: VideoViewFit.cover,
                    )
                  else
                    _remoteVideoPlaceholder(),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: _statusPill(),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _localVideoTile(localTrack),
                  ),
                  if (error != null)
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: _errorBanner(),
                    ),
                ],
              ),
            ),
          ),
        ),
        _buildControls(),
      ],
    );
  }

  Widget _remoteVideoPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _avatar(46),
            const SizedBox(height: 18),
            Text(
              widget.remoteName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              connected ? 'Waiting for video…' : _statusLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _localVideoTile(LocalVideoTrack? track) {
    return Container(
      width: 112,
      height: 156,
      decoration: BoxDecoration(
        color: const Color(0xFF202D44),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (track != null)
            VideoTrackRenderer(
              track,
              key: ObjectKey(track),
              fit: VideoViewFit.cover,
              mirrorMode: VideoViewMirrorMode.mirror,
            )
          else
            Center(
              child: Icon(
                cameraOn ? Icons.person : Icons.videocam_off,
                size: 36,
                color: Colors.white70,
              ),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  cameraOn ? 'You' : 'Camera off',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioCall() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _avatar(58),
                  const SizedBox(height: 22),
                  Text(
                    widget.remoteName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _statusPill(),
                  if (connected) ...[
                    const SizedBox(height: 14),
                    Text(_elapsedLabel, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 18),
                    _errorBanner(),
                  ],
                ],
              ),
            ),
          ),
        ),
        _buildControls(),
      ],
    );
  }

  Widget _avatar(double radius) => ProfileAvatar(
        path: widget.remoteAvatarPath,
        initials: widget.remoteName,
        radius: radius,
        backgroundColor: const Color(0xFF183B67),
        foregroundColor: const Color(0xFF35D5E8),
      );

  Widget _statusPill() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC080D18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (connecting || reconnecting) ...[
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
            ] else ...[
              Icon(
                connected ? Icons.circle : Icons.info_outline,
                size: 10,
                color: connected ? const Color(0xFF50D890) : Colors.white70,
              ),
              const SizedBox(width: 8),
            ],
            Text(_statusLabel, style: const TextStyle(fontSize: 13)),
            if (connected) ...[
              const SizedBox(width: 8),
              Text(_elapsedLabel, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xDD4B202B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x77F06B78)),
      ),
      child: Text(
        error!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFFFDDE1), fontSize: 13),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _controlButton(
                icon: muted ? Icons.mic_off : Icons.mic,
                label: muted ? 'Unmute' : 'Mute',
                selected: muted,
                onPressed: connected && !ending ? () => unawaited(toggleMic()) : null,
              ),
              if (_isVideoCall) ...[
                const SizedBox(width: 30),
                _controlButton(
                  icon: cameraOn ? Icons.videocam : Icons.videocam_off,
                  label: cameraOn ? 'Camera on' : 'Camera off',
                  selected: !cameraOn,
                  onPressed: connected && !ending ? () => unawaited(toggleCamera()) : null,
                ),
              ],
            ],
          ),
          const SizedBox(height: 22),
          SlideAction(
            label: ending ? 'Ending call…' : 'Slide to hang up',
            icon: Icons.call_end_rounded,
            glowColor: const Color(0xFFFF4D64),
            onCompleted: () => unawaited(hangUp()),
          ),
          const SizedBox(height: 10),
          WaterRippleButton(
            label: 'Hang up',
            icon: Icons.call_end_rounded,
            color: const Color(0xFFE53955),
            onPressed: ending ? null : () => unawaited(hangUp()),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback? onPressed,
  }) {
    final color = selected ? const Color(0xFF34435E) : const Color(0xFF176CC0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: IconButton.filled(
            onPressed: onPressed,
            style: IconButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF273247),
              disabledForegroundColor: Colors.white54,
            ),
            icon: Icon(icon, size: 25),
          ),
        ),
        const SizedBox(height: 7),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _PermissionFailure implements Exception {
  const _PermissionFailure(this.message);
  final String message;
}
