import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../core/theme.dart';
import 'blink_calls.dart';

/// Global incoming and ongoing call UI, shared by every authenticated route.
class BlinkCallHost extends StatefulWidget {
  const BlinkCallHost({super.key, required this.child});
  final Widget child;
  @override State<BlinkCallHost> createState() => _BlinkCallHostState();
}

class _BlinkCallHostState extends State<BlinkCallHost>
    with WidgetsBindingObserver {
  final calls = BlinkCalls.instance;
  Timer? refreshTimer;

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    calls.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(calls.connectIfSignedIn());
    });
    refreshTimer = Timer.periodic(const Duration(seconds: 6),
      (_) => unawaited(calls.connectIfSignedIn()));
  }

  void _changed() { if (mounted) setState(() {}); }

  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(calls.connectIfSignedIn());
    }
  }

  @override void dispose() {
    refreshTimer?.cancel();
    calls.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String get description {
    switch (calls.status) {
      case 'starting': return 'Preparing secure connection…';
      case 'ringing': return 'Ringing your friend…';
      case 'incoming': return 'Incoming ' +
        (calls.isVideo ? 'video' : 'voice') + ' call';
      case 'connecting': return 'Connecting securely…';
      case 'connected': return 'Connected';
      default: return '';
    }
  }

  Widget control(String label, IconData icon, VoidCallback callback,
      {Color color = const Color(0x44FFFFFF)}) =>
    Material(
      color: color,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: callback,
        borderRadius: BorderRadius.circular(23),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 82, minHeight: 67),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.white, size: 26),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.w900)),
            ]),
          ),
        ),
      ),
    );

  Widget callOverlay(BuildContext context) => Positioned.fill(
    child: Material(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF211B2A), Color(0xFF6B302B),
              Color(0xFFF06628)])),
        child: SafeArea(
          child: Stack(children: [
            if (calls.hasRemoteVideo)
              Positioned.fill(child: RTCVideoView(
                calls.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
            if (calls.hasLocalVideo)
              Positioned(top: 75, right: 16, width: 118, height: 170,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: RTCVideoView(calls.localRenderer, mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover))),
            Align(alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(19, 20, 19, 0),
                child: Row(children: [
                  const Text('✦  BLINK CONNECT',
                    style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(17)),
                    child: Text(calls.isVideo ? 'VIDEO CALL' : 'VOICE CALL',
                      style: const TextStyle(
                        fontSize: 10, color: Colors.white,
                        fontWeight: FontWeight.w800))),
                ]),
              )),
            if (!calls.hasRemoteVideo)
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 124, height: 124,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFC69F), BlinkColors.orange]),
                      borderRadius: BorderRadius.circular(39),
                      border: Border.all(color: const Color(0x99FFFFFF),
                        width: 2)),
                    child: Text(calls.peerName.isEmpty ? 'B'
                        : calls.peerName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white, fontSize: 53,
                        fontWeight: FontWeight.w900))),
                  const SizedBox(height: 22),
                  Text(calls.peerName, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 27,
                      fontWeight: FontWeight.w900)),
                  const SizedBox(height: 11),
                  Text(description, textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFEADB), fontSize: 13)),
                  if (calls.status == 'ringing' ||
                      calls.status == 'connecting') ...[
                    const SizedBox(height: 19),
                    const CircularProgressIndicator(color: Colors.white),
                  ],
                  const SizedBox(height: 78),
                ]),
              )),
            Align(alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 27),
                child: Wrap(
                  spacing: 11, runSpacing: 11,
                  alignment: WrapAlignment.center,
                  children: calls.status == 'incoming' ? [
                    control('Decline', Icons.call_end_rounded, calls.decline,
                      color: const Color(0xFFDC2E54)),
                    control('Answer', Icons.call_rounded,
                      () => unawaited(calls.accept()),
                      color: const Color(0xFF169C68)),
                  ] : [
                    if (calls.status == 'connecting' ||
                        calls.status == 'connected')
                      control(calls.muted ? 'Unmute' : 'Mute',
                        calls.muted ? Icons.mic_off_rounded
                          : Icons.mic_rounded, calls.toggleMute),
                    if (calls.status == 'connecting' ||
                        calls.status == 'connected')
                      control(
                        calls.speakerOn ? 'Speaker on' : 'Earpiece',
                        calls.speakerOn
                          ? Icons.volume_up_rounded
                          : Icons.hearing_rounded,
                        () => unawaited(calls.toggleSpeaker()),
                      ),
                    if (calls.isVideo && calls.hasLocalVideo)
                      control(calls.cameraOff ? 'Camera on' : 'Camera off',
                        calls.cameraOff ? Icons.videocam_off_rounded
                          : Icons.videocam_rounded, calls.toggleCamera),
                    control('End call', Icons.call_end_rounded, calls.hangUp,
                      color: const Color(0xFFDC2E54)),
                  ],
                ),
              )),
          ]),
        ),
      ),
    ),
  );

  @override Widget build(BuildContext context) => Stack(children: [
    widget.child,
    if (calls.status != 'idle') callOverlay(context),
    if (calls.status == 'idle' && calls.error.isNotEmpty)
      Positioned(
        bottom: MediaQuery.paddingOf(context).bottom + 70,
        left: 10, right: 10,
        child: Material(
          color: const Color(0xFF211B2A),
          elevation: 10,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 7, 5, 7),
            child: Row(children: [
              Expanded(child: Text(calls.error,
                style: const TextStyle(color: Colors.white, fontSize: 12))),
              TextButton(onPressed: calls.clearError,
                child: const Text('Dismiss',
                  style: TextStyle(color: Color(0xFFFFBE96)))),
            ]),
          ),
        ),
      ),
  ]);
}
