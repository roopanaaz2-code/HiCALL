import 'package:material_ui/material_ui.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.credentials, required this.remoteName});
  final CallCredentials credentials;
  final String remoteName;
  @override State<CallScreen> createState() => _CallScreenState();
}
class _CallScreenState extends State<CallScreen> {
  late final Room room;
  bool connecting = true, connected = false, muted = false, cameraOn = false, ending = false;
  String? error;
  @override void initState() { super.initState(); room = Room(); connect(); }

  Future<void> connect() async {
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) { throw Exception('Microphone permission is required.'); }
      if (widget.credentials.callType == 'video') {
        final camera = await Permission.camera.request();
        if (!camera.isGranted) throw Exception('Camera permission is required for video calls.');
      }
      await room.connect(widget.credentials.serverUrl, widget.credentials.token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (widget.credentials.callType == 'video') {
        await room.localParticipant?.setCameraEnabled(true);
        cameraOn = true;
      }
      if (mounted) { setState(() { connected = true; connecting = false; }); }
    } catch (e) { if (mounted) { setState(() { error = e.toString(); connecting = false; }); } }
  }

  Future<void> toggleMic() async {
    final next = !muted;
    await room.localParticipant?.setMicrophoneEnabled(!next);
    if (mounted) { setState(() => muted = next); }
  }
  Future<void> toggleCamera() async {
    final next = !cameraOn;
    await room.localParticipant?.setCameraEnabled(next);
    if (mounted) { setState(() => cameraOn = next); }
  }
  Future<void> hangUp() async {
    if (ending) { return; }
    setState(() => ending = true);
    try { await room.disconnect(); } catch (_) {}
    try { await CallService.instance.endCall(widget.credentials.callId); } catch (_) {}
    if (mounted) { Navigator.of(context).pop(); }
  }
  @override void dispose() { room.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final video = widget.credentials.callType == 'video';
    return PopScope(canPop: false, child: Scaffold(
      appBar: AppBar(leading: const SizedBox.shrink(), title: Text(video ? 'Video call' : 'Audio call')),
      body: SafeArea(child: Column(children: [
        const Spacer(),
        CircleAvatar(radius: 48, backgroundColor: const Color(0xFF123A69),
          child: Icon(video ? Icons.videocam : Icons.person, size: 48, color: const Color(0xFF16D5F4))),
        const SizedBox(height: 18),
        Text(widget.remoteName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(connecting ? 'Connecting…' : connected ? 'Connected' : 'Call not connected', style: const TextStyle(color: Colors.white70)),
        if (error != null) Padding(padding: const EdgeInsets.all(20), child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent))),
        const Spacer(),
        if (connected) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          control(muted ? Icons.mic_off : Icons.mic, toggleMic, muted),
          if (video) ...[const SizedBox(width: 24), control(cameraOn ? Icons.videocam : Icons.videocam_off, toggleCamera, !cameraOn)],
        ]),
        const SizedBox(height: 28),
        Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 30), child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD9364F)),
          onPressed: ending ? null : hangUp, child: Text(ending ? 'Ending…' : 'End call'))),
      ])),
    ));
  }

  Widget control(IconData icon, VoidCallback action, bool selected) => CircleAvatar(
    radius: 28, backgroundColor: selected ? const Color(0xFF087DE0) : const Color(0xFF26334F),
    child: IconButton(onPressed: action, icon: Icon(icon, color: Colors.white)));
}
