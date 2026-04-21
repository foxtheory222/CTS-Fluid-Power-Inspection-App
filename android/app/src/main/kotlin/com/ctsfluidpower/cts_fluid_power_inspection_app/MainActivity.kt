package com.ctsfluidpower.cts_fluid_power_inspection_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode

class MainActivity : FlutterActivity() {
    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun getTransparencyMode(): TransparencyMode =
        TransparencyMode.opaque
}
