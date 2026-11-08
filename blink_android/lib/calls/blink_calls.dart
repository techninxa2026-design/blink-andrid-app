import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../core/blink_auth_api.dart';
import '../core/live_api.dart';
import 'blink_call_audio_policy.dart';

/// Blink's signed-in one-to-one WebRTC session manager.
/// The NestJS server carries only authenticated signaling, never media.
class BlinkCalls extends ChangeNotifier {
  BlinkCalls._();
  static final BlinkCalls instance = BlinkCalls._();

  static const MethodChannel _native =
      MethodChannel('com.techinxa.blink_android/calls');

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  IO.Socket? _socket;
  RTCPeerConnection? _peer;
  MediaStream? _local;
  MediaStream? _remote;
  final List<RTCIceCandidate> _pendingIce = [];
  Timer? _mediaTimeout;
  Timer? _disconnectTimer;
  bool _turnConfigured = false;
  bool _isCaller = false;
  bool _restartAttempted = false;
  int _candidateRelayFailures = 0;
  int _sentCandidates = 0;
  int _relayCandidates = 0;
  int _receivedCandidates = 0;

  String _token = '';
  String status = 'idle';
  String callId = '';
  String peerId = '';
  String peerName = '';
  String kind = 'audio';
  String error = '';
  bool muted = false;
  bool cameraOff = false;
  bool speakerOn = false;
  bool connected = false;
  bool _prepared = false;
  bool _remoteSet = false;
  bool _renderersInitialized = false;
  bool get isVideo => kind == 'video';
  bool get hasRemoteVideo => _remote != null && isVideo;
  bool get hasLocalVideo => _local != null && isVideo;

  Map<String, dynamic> _map(dynamic raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  Future<void> connectIfSignedIn() async {
    final token = await BlinkAuthApi.getToken();
    if (token == null || token.isEmpty) {
      if (_socket != null) disconnect();
      return;
    }
    if (token == _token && _socket != null) return;
    disconnect();
    _token = token;

    final socket = IO.io(
      BlinkAuthApi.baseUrl + '/calls',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableForceNew()
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(900)
          .setReconnectionDelayMax(5000)
          .setTimeout(10000)
          .build(),
    );
    _socket = socket;
    socket.onConnect((_) {
      connected = true;
      notifyListeners();
    });
    socket.onDisconnect((_) {
      connected = false;
      if (status != 'idle') _reset('Call connection interrupted.');
      notifyListeners();
    });
    socket.onConnectError((_) {
      connected = false;
      notifyListeners();
    });
    socket.on('call-error', (raw) {
      final message = _map(raw)['error']?.toString() ?? '';
      if (message.isNotEmpty) {
        error = message;
        notifyListeners();
      }
    });
    socket.on('call-incoming', (raw) {
      final event = _map(raw);
      final id = event['callId']?.toString() ?? '';
      if (id.isEmpty || event['callerId'] is! String) return;
      if (status != 'idle') {
        socket.emit('call-rejected', {'callId': id});
        return;
      }
      _isCaller = false;
      callId = id;
      peerId = event['callerId'] as String;
      peerName = event['callerName']?.toString() ?? 'Blink friend';
      kind = event['kind'] == 'video' ? 'video' : 'audio';
      status = 'incoming';
      error = '';
      notifyListeners();
    });
    socket.on('call-taken', (raw) {
      if (_map(raw)['callId'] == callId && status == 'incoming') _reset();
    });
    socket.on('call-accepted', (raw) {
      if (_map(raw)['callId'] == callId && status == 'ringing') {
        unawaited(_makeOffer().catchError(_fail));
      }
    });
    socket.on('call-offer', (raw) {
      final event = _map(raw);
      if (event['callId'] == callId && event['sdp'] is Map) {
        unawaited(_onOffer(_map(event['sdp'])).catchError(_fail));
      }
    });
    socket.on('call-answer', (raw) {
      final event = _map(raw);
      if (event['callId'] == callId && event['sdp'] is Map) {
        unawaited(_onAnswer(_map(event['sdp'])).catchError(_fail));
      }
    });
    socket.on('ice-candidate', (raw) {
      final event = _map(raw);
      if (event['callId'] == callId && event['candidate'] is Map) {
        unawaited(_onCandidate(_map(event['candidate'])).catchError(_fail));
      }
    });
    socket.on('call-ice-restart-request', (raw) {
      if (_map(raw)['callId'] == callId && _isCaller &&
          !_restartAttempted && status != 'idle') {
        unawaited(_recoverIce().catchError(_fail));
      }
    });
    socket.on('call-ended', (raw) {
      if (_map(raw)['callId'] == callId) _reset();
    });
    socket.connect();
  }

  void disconnect() {
    _reset();
    _socket?.dispose();
    _socket = null;
    connected = false;
    _token = '';
    notifyListeners();
  }

  Future<Map<String, dynamic>> _ack(
    String event, Map<String, dynamic> data,
  ) async {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      throw StateError('Calling service is offline. Please reconnect.');
    }
    final result = _map(await socket.emitWithAckAsync(event, data)
        .timeout(const Duration(seconds: 9)));
    if (result['ok'] != true) {
      throw StateError(result['error']?.toString() ?? 'Call not available.');
    }
    return result;
  }

  Future<void> _awaitConnected() async {
    // A first call immediately after login must not race the socket handshake.
    for (var attempt = 0; attempt < 35; attempt++) {
      if (_socket?.connected == true) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    throw StateError('Calling service is offline. Please reconnect.');
  }

  Future<void> placeCall(
    String userId, String name, {bool video = false}
  ) async {
    if (status != 'idle' || userId.isEmpty) return;
    try {
      await connectIfSignedIn();
      await _awaitConnected();
      // An incoming invitation might have appeared during connection setup.
      if (status != 'idle') return;
      _isCaller = true;
      peerId = userId;
      peerName = name;
      kind = video ? 'video' : 'audio';
      status = 'starting';
      error = '';
      notifyListeners();

      final result = await _ack('call-initiate', {
        'calleeId': userId, 'kind': kind,
      });
      final id = result['callId']?.toString() ?? '';
      if (id.isEmpty) throw StateError('Call identifier missing.');
      // The caller may have tapped End while waiting for the ACK.
      if (status != 'starting') {
        _socket?.emit('call-ended', {'callId': id});
        return;
      }
      callId = id;
      status = 'ringing';
      notifyListeners();
    } catch (failure) {
      _reset(failure.toString());
    }
  }

  Future<void> accept() async {
    if (status != 'incoming' || callId.isEmpty) return;
    final id = callId;
    status = 'connecting';
    notifyListeners();
    try {
      await _prepare(id);
      if (id != callId) return;
      await _ack('call-accept', {'callId': id});
    } catch (failure) {
      _socket?.emit('call-rejected', {'callId': id});
      _reset(failure.toString());
    }
  }

  void decline() {
    if (callId.isNotEmpty) {
      _socket?.emit('call-rejected', {'callId': callId});
    }
    _reset();
  }

  void hangUp() {
    if (callId.isNotEmpty) {
      _socket?.emit('call-ended', {'callId': callId});
    }
    _reset();
  }

  void clearError() {
    error = '';
    notifyListeners();
  }

  void toggleMute() {
    muted = !muted;
    for (final track in _local?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
    notifyListeners();
  }

  void toggleCamera() {
    cameraOff = !cameraOff;
    for (final track in _local?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !cameraOff;
    }
    notifyListeners();
  }

  /// Let the user switch speaker/earpiece during an active call. Voice
  /// defaults to earpiece; video defaults to speakerphone. Wired/Bluetooth
  /// output remains under Android/WebRTC device routing where available.
  Future<void> toggleSpeaker() async {
    if (kIsWeb || _local == null || status == 'idle') return;
    final next = !speakerOn;
    try {
      await Helper.setSpeakerphoneOn(next);
      if (_local == null || status == 'idle') return;
      speakerOn = next;
      notifyListeners();
    } catch (error) {
      // Audio-route errors must not tear down the ongoing media session.
      debugPrint('Blink audio route unavailable: $error');
    }
  }

  Future<void> _applyAudioRoute() async {
    if (kIsWeb || status == 'idle') return;
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
    } catch (error) {
      debugPrint('Blink could not set call audio route: $error');
    }
  }

  Future<void> _prepare(String id) async {
    if (!_renderersInitialized) {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _renderersInitialized = true;
    }
    final result = _map(await LiveApi.call('GET', '/calls/ice'));
    final servers = arr(result['iceServers']);
    _turnConfigured = result['turnConfigured'] == true || servers.any((raw) {
      final entry = _map(raw);
      final urls = entry['urls'] is List
          ? (entry['urls'] as List).map((v) => v.toString()).toList()
          : <String>[entry['urls']?.toString() ?? ''];
      return urls.any((url) => url.startsWith('turn:') || url.startsWith('turns:'));
    });
    final config = <String, dynamic>{'iceServers': servers};
    final videoCall = isVideo;
    speakerOn = BlinkCallAudioPolicy.defaultSpeaker(video: videoCall);
    // Flutter WebRTC requires this BEFORE opening an Android microphone
    // session, otherwise audio may be captured/routed in media playback mode.
    if (!kIsWeb) {
      try {
        await Helper.setAndroidAudioConfiguration(
          AndroidAudioConfiguration.communication,
        );
      } catch (error) {
        debugPrint('Blink Android communication audio mode unavailable: $error');
      }
    }
    final local = await navigator.mediaDevices.getUserMedia(
      BlinkCallAudioPolicy.captureConstraints(video: videoCall),
    );
    if (id != callId) {
      for (final track in local.getTracks()) {track.stop();}
      await local.dispose();
      return;
    }
    _local = local;
    localRenderer.srcObject = local;
    if (!kIsWeb) {
      // Foreground service is started only after Android's permission flow
      // successfully grants microphone/camera capture.
      await _native.invokeMethod<void>('startCall', {'video': isVideo});
      // The foreground service and microphone startup can change routing.
      // Prefer the private earpiece for voice calls to avoid loudspeaker echo.
      await _applyAudioRoute();
    }

    final peer = await createPeerConnection(config);
    if (id != callId) {
      await peer.close();
      return;
    }
    _peer = peer;
    _prepared = true;
    _remoteSet = false;
    for (final track in local.getTracks()) {
      await peer.addTrack(track, local);
    }
    peer.onTrack = (event) {
      if (id != callId) return;
      if (event.streams.isNotEmpty) {
        _remote = event.streams.first;
        remoteRenderer.srcObject = _remote;
        notifyListeners();
      }
      if (event.track.kind == 'audio') {
        // WebRTC may reset the audio output once the remote track arrives.
        // Reapply the selected route without altering the microphone stream.
        unawaited(_applyAudioRoute());
      }
    };
    peer.onIceCandidate = (candidate) {
      if (id != callId || candidate.candidate == null) return;
      _sentCandidates++;
      if ((candidate.candidate ?? '').contains(' typ relay ')) {
        _relayCandidates++;
      }
      unawaited(_ack('ice-candidate', {
        'callId': id,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      }).catchError((Object _) {
        if (id == callId) {
          _candidateRelayFailures++;
          if (_candidateRelayFailures >= 3) {
            _fail(StateError(
              'Blink call signaling cannot relay ICE candidates. '
              'Check WebSocket connection and server logs.',
            ));
          }
        }
        return <String, dynamic>{'ok': false};
      }));
    };
    peer.onIceConnectionState = (state) {
      if (id != callId) return;
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _disconnectTimer?.cancel();
        _disconnectTimer = null;
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        unawaited(_recoverIce().catchError(_fail));
      } else if (state ==
          RTCIceConnectionState.RTCIceConnectionStateDisconnected &&
          _disconnectTimer == null) {
        _disconnectTimer = Timer(const Duration(seconds: 5), () {
          _disconnectTimer = null;
          if (id == callId) {
            unawaited(_recoverIce().catchError(_fail));
          }
        });
      }
    };
    peer.onConnectionState = (state) {
      if (id != callId) return;
      if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _clearMediaTimers();
        status = 'connected';
        notifyListeners();
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        unawaited(_recoverIce().catchError(_fail));
      }
    };
    _armMediaTimeout(id, const Duration(seconds: 30));
  }

  void _clearMediaTimers() {
    _mediaTimeout?.cancel();
    _disconnectTimer?.cancel();
    _mediaTimeout = null;
    _disconnectTimer = null;
  }

  StateError _mediaFailure() {
    // Counts are safe for troubleshooting (no private IPs or SDP exposed).
    final progress = 'ICE candidates sent: $_sentCandidates, '
        'received: $_receivedCandidates.';
    if (_candidateRelayFailures >= 3) {
      return StateError('ICE signaling failed. Check the Blink server WebSocket. $progress');
    }
    if (!_turnConfigured) {
      return StateError(
        'No network path found. Blink has no TURN relay configured. '
        'The API administrator must set CALL_TURN_URLS and '
        'CALL_TURN_SHARED_SECRET. $progress',
      );
    }
    if (_relayCandidates == 0) {
      return StateError(
        'TURN is configured but this device gathered no relay candidates. '
        'Check TURN credentials, public IP, UDP/TCP ports and firewall. '
        '$progress',
      );
    }
    if (_receivedCandidates == 0) {
      return StateError(
        'No peer ICE candidates could be applied. '
        'Check both devices and Blink Socket.IO signaling. $progress',
      );
    }
    return StateError(
      'TURN candidates were gathered but no media route worked. '
      'Check relay reachability and firewall ports. $progress',
    );
  }

  void _armMediaTimeout(String id, Duration duration) {
    _mediaTimeout?.cancel();
    _mediaTimeout = Timer(duration, () {
      if (id != callId || status == 'connected') return;
      if (!_restartAttempted) {
        unawaited(_recoverIce().catchError(_fail));
      } else {
        _fail(_mediaFailure());
      }
    });
  }

  Future<void> _recoverIce() async {
    final id = callId;
    final peer = _peer;
    if (id.isEmpty || peer == null || status == 'idle' ||
        _restartAttempted) return;
    _restartAttempted = true;
    status = 'connecting';
    notifyListeners();
    _armMediaTimeout(id, const Duration(seconds: 20));
    if (!_isCaller) {
      await _ack('call-ice-restart-request', {'callId': id});
      return;
    }
    // The original caller is the sole offerer for restart negotiation.
    await peer.restartIce();
    final offer = await peer.createOffer();
    if (id != callId) return;
    await peer.setLocalDescription(offer);
    await _ack('call-offer', {
      'callId': id,
      'sdp': {'type': offer.type, 'sdp': offer.sdp},
    });
  }

  Future<void> _makeOffer() async {
    final id = callId;
    if (id.isEmpty) return;
    status = 'connecting';
    notifyListeners();
    await _prepare(id);
    if (id != callId || _peer == null) return;
    final offer = await _peer!.createOffer();
    await _peer!.setLocalDescription(offer);
    await _ack('call-offer', {
      'callId': id,
      'sdp': {'type': offer.type, 'sdp': offer.sdp},
    });
  }

  Future<void> _onOffer(Map<String, dynamic> data) async {
    final peer = _peer;
    if (!_prepared || peer == null) return;
    await peer.setRemoteDescription(
      RTCSessionDescription(
        data['sdp']?.toString(), data['type']?.toString()),
    );
    _remoteSet = true;
    await _flushIce();
    final answer = await peer.createAnswer();
    await peer.setLocalDescription(answer);
    await _ack('call-answer', {
      'callId': callId, 'sdp': {
        'type': answer.type, 'sdp': answer.sdp,
      },
    });
  }

  Future<void> _onAnswer(Map<String, dynamic> data) async {
    final peer = _peer;
    if (peer == null) return;
    await peer.setRemoteDescription(
      RTCSessionDescription(
        data['sdp']?.toString(), data['type']?.toString()),
    );
    _remoteSet = true;
    await _flushIce();
  }

  Future<void> _onCandidate(Map<String, dynamic> data) async {
    final candidate = RTCIceCandidate(
      data['candidate']?.toString(),
      data['sdpMid']?.toString(),
      (data['sdpMLineIndex'] as num?)?.toInt(),
    );
    if (!_remoteSet || _peer == null) {
      _pendingIce.add(candidate);
      return;
    }
    try {
      await _peer!.addCandidate(candidate);
      _receivedCandidates++;
    } catch (_) {
      // Trickle candidates from the previous ICE generation can be stale.
      // The connection timeout still detects a genuine routing failure.
    }
  }

  Future<void> _flushIce() async {
    final pending = List<RTCIceCandidate>.of(_pendingIce);
    _pendingIce.clear();
    for (final candidate in pending) {
      try {
        await _peer?.addCandidate(candidate);
        _receivedCandidates++;
      } catch (_) {
        // A candidate raced against an ICE restart; use the next generation.
      }
    }
  }

  void _fail(dynamic failure) {
    final message = failure.toString();
    hangUp();
    error = message;
    notifyListeners();
  }

  void _reset([String message = '']) {
    _clearMediaTimers();
    final peer = _peer;
    _peer = null;
    _prepared = false;
    _remoteSet = false;
    _pendingIce.clear();
    if (peer != null) {
      peer.onTrack = null;
      peer.onIceCandidate = null;
      peer.onConnectionState = null;
      unawaited(peer.close());
    }
    final local = _local;
    final wasCapturingAudio = local?.getAudioTracks().isNotEmpty ?? false;
    _local = null;
    _remote = null;
    if (local != null) {
      for (final track in local.getTracks()) {track.stop();}
      unawaited(local.dispose());
    }
    if (!kIsWeb && wasCapturingAudio) {
      // Release WebRTC's communication-device selection when the call ends;
      // ordinary app playback should not stay on the call earpiece.
      unawaited(Helper.clearAndroidCommunicationDevice().catchError(
        (Object error) => debugPrint('Blink audio route cleanup: $error'),
      ));
    }
    if (_renderersInitialized) {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    }
    if (!kIsWeb) {
      unawaited(_native.invokeMethod<void>('stopCall').catchError((_) {}));
    }
    status = 'idle';
    callId = '';
    peerId = '';
    peerName = '';
    muted = false;
    cameraOff = false;
    speakerOn = false;
    _turnConfigured = false;
    _isCaller = false;
    _restartAttempted = false;
    _candidateRelayFailures = 0;
    _sentCandidates = 0;
    _relayCandidates = 0;
    _receivedCandidates = 0;
    error = message;
    notifyListeners();
  }
}
