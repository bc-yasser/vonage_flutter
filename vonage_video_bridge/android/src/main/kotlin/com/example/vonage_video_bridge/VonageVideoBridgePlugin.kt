package com.example.vonage_video_bridge

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.opentok.android.BaseVideoRenderer
import com.opentok.android.OpentokError
import com.opentok.android.Publisher
import com.opentok.android.PublisherKit
import com.opentok.android.Session
import com.opentok.android.Stream
import com.opentok.android.Subscriber
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class VonageVideoBridgePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ActivityAware {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var controller: VonageVideoController

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        controller = VonageVideoController(binding.applicationContext)
        methodChannel = MethodChannel(binding.binaryMessenger, "vonage_video_bridge/methods")
        eventChannel = EventChannel(binding.binaryMessenger, "vonage_video_bridge/events")
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        binding.platformViewRegistry.registerViewFactory(
            "vonage_video_bridge/view",
            VonageVideoPlatformViewFactory(controller)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        controller.disconnect()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        controller.activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        controller.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        controller.activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        controller.activity = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        controller.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        controller.eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "connect" -> {
                    val applicationId = call.argument<String>("applicationId") ?: error("applicationId is required")
                    val sessionId = call.argument<String>("sessionId") ?: error("sessionId is required")
                    val token = call.argument<String>("token") ?: error("token is required")
                    val publisherName = call.argument<String>("publisherName") ?: "Flutter"
                    controller.connect(applicationId, sessionId, token, publisherName)
                    result.success(null)
                }
                "publish" -> {
                    controller.publish()
                    result.success(null)
                }
                "setAudioEnabled" -> {
                    controller.setAudioEnabled(call.arguments as Boolean)
                    result.success(null)
                }
                "setVideoEnabled" -> {
                    controller.setVideoEnabled(call.arguments as Boolean)
                    result.success(null)
                }
                "switchCamera" -> {
                    controller.switchCamera()
                    result.success(null)
                }
                "disconnect" -> {
                    controller.disconnect()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("VONAGE_VIDEO_ERROR", e.message, null)
        }
    }
}

class VonageVideoController(
    private val context: Context
) : Session.SessionListener, PublisherKit.PublisherListener {
    var activity: Activity? = null
    var eventSink: EventChannel.EventSink? = null

    private var session: Session? = null
    private var publisher: Publisher? = null
    private var subscriber: Subscriber? = null
    private var container: FrameLayout? = null

    fun attach(root: FrameLayout) {
        container = root
        renderViews()
    }

    fun detach(root: FrameLayout) {
        if (container === root) {
            container = null
        }
    }

    fun connect(applicationId: String, sessionId: String, token: String, publisherName: String) {
        ensurePermissions()
        disconnect()
        publisher = Publisher.Builder(context).name(publisherName).build().also {
            it.setPublisherListener(this)
            it.renderer?.setStyle(BaseVideoRenderer.STYLE_VIDEO_SCALE, BaseVideoRenderer.STYLE_VIDEO_FILL)
        }
        session = Session.Builder(context, applicationId, sessionId).build().also {
            it.setSessionListener(this)
            it.connect(token)
        }
        event("connecting")
        renderViews()
    }

    fun publish() {
        val activeSession = session ?: error("Session is not connected")
        val activePublisher = publisher ?: error("Publisher is not ready")
        activeSession.publish(activePublisher)
        renderViews()
    }

    fun setAudioEnabled(enabled: Boolean) {
        publisher?.publishAudio = enabled
    }

    fun setVideoEnabled(enabled: Boolean) {
        publisher?.publishVideo = enabled
    }

    fun switchCamera() {
        publisher?.cycleCamera()
    }

    fun disconnect() {
        subscriber?.let { session?.unsubscribe(it) }
        publisher?.let { session?.unpublish(it) }
        session?.disconnect()
        subscriber = null
        publisher = null
        session = null
        container?.removeAllViews()
        event("disconnected")
    }

    override fun onConnected(session: Session) {
        event("connected")
        publish()
    }

    override fun onDisconnected(session: Session) {
        event("disconnected")
    }

    override fun onStreamReceived(session: Session, stream: Stream) {
        event("streamReceived", streamId = stream.streamId)
        subscriber = Subscriber.Builder(context, stream).build()
        session.subscribe(subscriber)
        renderViews()
    }

    override fun onStreamDropped(session: Session, stream: Stream) {
        event("streamDropped", streamId = stream.streamId)
        subscriber = null
        renderViews()
    }

    override fun onError(session: Session, opentokError: OpentokError) {
        event("error", opentokError.message)
    }

    override fun onStreamCreated(publisherKit: PublisherKit, stream: Stream) {
        event("publisherStreamCreated", streamId = stream.streamId)
    }

    override fun onStreamDestroyed(publisherKit: PublisherKit, stream: Stream) {
        event("publisherStreamDestroyed", streamId = stream.streamId)
    }

    override fun onError(publisherKit: PublisherKit, opentokError: OpentokError) {
        event("error", opentokError.message)
    }

    private fun renderViews() {
        val root = container ?: return
        root.removeAllViews()

        subscriber?.view?.let { remote ->
            addFullSize(root, remote)
        }

        publisher?.view?.let { local ->
            val size = (120 * root.resources.displayMetrics.density).toInt()
            val params = FrameLayout.LayoutParams(size, size).apply {
                gravity = Gravity.TOP or Gravity.END
                topMargin = 24
                rightMargin = 24
            }
            if (local.parent != null) {
                (local.parent as? FrameLayout)?.removeView(local)
            }
            root.addView(local, params)
        }
    }

    private fun addFullSize(root: FrameLayout, view: View) {
        if (view.parent != null) {
            (view.parent as? FrameLayout)?.removeView(view)
        }
        root.addView(
            view,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )
    }

    private fun ensurePermissions() {
        val currentActivity = activity ?: return
        val missing = arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO)
            .filter {
                ContextCompat.checkSelfPermission(currentActivity, it) != PackageManager.PERMISSION_GRANTED
            }
            .toTypedArray()
        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(currentActivity, missing, 7001)
        }
    }

    private fun event(type: String, message: String? = null, streamId: String? = null) {
        eventSink?.success(
            mapOf(
                "type" to type,
                "message" to message,
                "streamId" to streamId
            )
        )
    }
}
