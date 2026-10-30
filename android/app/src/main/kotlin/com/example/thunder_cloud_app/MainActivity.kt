package io.github.tsuchida.thunder_cloud_app

import android.Manifest
import android.content.pm.PackageManager
import android.hardware.GeomagneticField
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var foregroundLocationResult: MethodChannel.Result? = null

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

        // 「常に」の人の場所を、アプリを閉じているあいだも書く定期処理を始める・止める
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "thunder_cloud/background_location")
            .setMethodCallHandler { call, result ->
                if (call.method == "sync") {
                    BackgroundLocation.sync(applicationContext)
                    result.success(BackgroundLocation.hasAlways(applicationContext))
                } else {
                    result.notImplemented()
                }
            }

        // 位置情報の「使用中」だけをお願いする。
        // geolocator は Android 10 でマニフェストに ACCESS_BACKGROUND_LOCATION があると「常に」も一緒に聞くので、
        // はじめての起動ではこちらを使う（CLAUDE.md:「常に」をいきなりお願いしない）
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "thunder_cloud/location_foreground")
            .setMethodCallHandler { call, result ->
                if (call.method != "request") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (hasForegroundLocation()) {
                    result.success(true)
                    return@setMethodCallHandler
                }
                foregroundLocationResult?.success(false)
                foregroundLocationResult = result
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                    FOREGROUND_LOCATION_REQUEST
                )
            }
    }

    private fun hasForegroundLocation(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == FOREGROUND_LOCATION_REQUEST) {
            foregroundLocationResult?.success(hasForegroundLocation())
            foregroundLocationResult = null
        }
    }

    companion object {
        private const val FOREGROUND_LOCATION_REQUEST = 4201
    }
}
