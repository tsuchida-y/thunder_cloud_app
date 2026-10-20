package io.github.tsuchida.thunder_cloud_app

import android.hardware.GeomagneticField
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 方角ガイド用: その場所の磁北と真北のずれ（偏角、東向きが正）を返す。
        // Android の方位センサーは磁北を基準にするので、アプリ側でこの値を足して真北にする。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "thunder_cloud/geomagnetic")
            .setMethodCallHandler { call, result ->
                if (call.method == "declination") {
                    val latitude = call.argument<Double>("latitude")
                    val longitude = call.argument<Double>("longitude")
                    if (latitude == null || longitude == null) {
                        result.error("bad_args", "latitude と longitude が必要です", null)
                    } else {
                        val field = GeomagneticField(
                            latitude.toFloat(), longitude.toFloat(), 0f, System.currentTimeMillis()
                        )
                        result.success(field.declination.toDouble())
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
