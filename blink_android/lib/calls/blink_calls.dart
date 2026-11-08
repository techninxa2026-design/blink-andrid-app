import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../core/blink_auth_api.dart';
import '../core/live_api.dart';

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

  String _token = '';
  String status = 'idle';
  String callId = '';
  String peerId = '';
  String peerName = '';
  String kind = 'audio';
  String error = '';
  bool muted = false;
  bool cameraOff = false;
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

  Future<void> placeCall(
    String userId, String name, {bool video = false},
  ) async {
    if (status != 'idle' || userId.isEmpty) return;
    peerId = userId;
    peerName = name;
    kind = video ? 'video' : 'audio';
    status = 'starting';
    error = '';
    notifyListeners();
    try {
      await connectIfSignedIn();
      final result = await _ack('call-initiate', {
        'calleeId': userId, 'kind': kind,
      });
      final id = result['callId']?.toString() ?? '';
      if (id.isEmpty) throw StateError('Call identifier missing.');
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

  Future<void> _prepare(String id) async {
    if (!_renderersInitialized) {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _renderersInitialized = true;
    }
    final result = _map(await LiveApi.call('GET', '/calls/ice'));
    final servers = arr(result['iceServers']);
    final config = <String, dynamic>{'iceServers': servers};
    final local = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
      },
      'video': isVideo
          ? {'facingMode': 'user', 'width': 720, 'height': 1280}
          : false,
    });
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
    };
    peer.onIceCandidate = (candidate) {
      if (id == callId && candidate.candidate != null) {
        _socket?.emit('ice-candidate', {
          'callId': id,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      }
    };
    peer.onConnectionState = (state) {
      if (id != callId) return;
      if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _mediaTimeout?.cancel();
        _mediaTimeout = null;
        status = 'connected';
        notifyListeners();
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _fail(StateError('Media connection failed. Try again.'));
      }
    };
    _mediaTimeout?.cancel();
    _mediaTimeout = Timer(const Duration(seconds: 30), () {
      if (id == callId && status != 'connected') {
        _fail(StateError('Media connection timed out. TURN may be required.'));
      }
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
    await _peer!.addCandidate(candidate);
  }

  Future<void> _flushIce() async {
    final pending = List<RTCIceCandidate>.of(_pendingIce);
    _pendingIce.clear();
    for (final candidate in pending) {
      await _peer?.addCandidate(candidate);
    }
  }

  void _fail(dynamic failure) {
    final message = failure.toString();
    hangUp();
    error = message;
    notifyListeners();
  }

  void _reset([String message = '']) {
    _mediaTimeout?.cancel();
    _mediaTimeout = null;
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
    _local = null;
    _remote = null;
    if (local != null) {
      for (final track in local.getTracks()) {track.stop();}
      unawaited(local.dispose());
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
    error = message;
    notifyListeners();
  }
}
