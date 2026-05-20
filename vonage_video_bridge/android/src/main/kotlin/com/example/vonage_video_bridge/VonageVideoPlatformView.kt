package com.example.vonage_video_bridge

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec

class VonageVideoPlatformView(
    context: Context,
    private val controller: VonageVideoController
) : PlatformView {
    private val root = FrameLayout(context)

    init {
        controller.attach(root)
    }

    override fun getView(): View = root

    override fun dispose() {
        controller.detach(root)
    }
}

class VonageVideoPlatformViewFactory(
    private val controller: VonageVideoController
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return VonageVideoPlatformView(context, controller)
    }
}
