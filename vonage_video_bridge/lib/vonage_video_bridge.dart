import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VonageVideoBridge {
  VonageVideoBridge._();

  static const MethodChannel _methods = MethodChannel('vonage_video_bridge/methods');
  static const EventChannel _events = EventChannel('vonage_video_bridge/events');

  static Stream<VonageVideoEvent>? _eventStream;

  static Stream<VonageVideoEvent> get events {
    _eventStream ??= _events.receiveBroadcastStream().map((dynamic event) {
      final data = Map<String, dynamic>.from(event as Map);
      return VonageVideoEvent(
        type: data['type'] as String,
        message: data['message'] as String?,
        streamId: data['streamId'] as String?,
      );
    });
    return _eventStream!;
  }

  static Future<void> connect({
    required String applicationId,
    required String sessionId,
    required String token,
    String publisherName = 'Flutter',
  }) {
    return _methods.invokeMethod<void>('connect', <String, dynamic>{
      'applicationId': applicationId,
      'sessionId': sessionId,
      'token': token,
      'publisherName': publisherName,
    });
  }

  static Future<void> publish() {
    return _methods.invokeMethod<void>('publish');
  }

  static Future<void> setAudioEnabled(bool enabled) {
    return _methods.invokeMethod<void>('setAudioEnabled', enabled);
  }

  static Future<void> setVideoEnabled(bool enabled) {
    return _methods.invokeMethod<void>('setVideoEnabled', enabled);
  }

  static Future<void> switchCamera() {
    return _methods.invokeMethod<void>('switchCamera');
  }

  static Future<void> disconnect() {
    return _methods.invokeMethod<void>('disconnect');
  }
}

class VonageVideoEvent {
  const VonageVideoEvent({
    required this.type,
    this.message,
    this.streamId,
  });

  final String type;
  final String? message;
  final String? streamId;
}

class VonageVideoView extends StatelessWidget {
  const VonageVideoView({super.key});

  static const String _viewType = 'vonage_video_bridge/view';

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      throw UnsupportedError('VonageVideoView supports Android and iOS only.');
    }

    if (Platform.isAndroid) {
      return const AndroidView(
        viewType: _viewType,
        creationParamsCodec: StandardMessageCodec(),
      );
    }

    if (Platform.isIOS) {
      return const UiKitView(
        viewType: _viewType,
        creationParamsCodec: StandardMessageCodec(),
      );
    }

    throw UnsupportedError('VonageVideoView supports Android and iOS only.');
  }
}
