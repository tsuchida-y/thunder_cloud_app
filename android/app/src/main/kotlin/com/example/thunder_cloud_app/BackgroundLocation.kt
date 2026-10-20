package io.github.tsuchida.thunder_cloud_app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.roundToLong

/**
 * 位置情報を「常に」にした人の場所を、アプリを閉じているあいだも members に書く（Android）
 *
 * - WorkManager で15分ごと（Android が決める最短の間隔）に、電池をあまり使わない精度で場所を取る
 * - 前に書いた場所から1km以上動いたときだけ書く。位置は小数第2位（約1km）に丸める
 * - lastOpenedAt は書かない（サーバーは「開いて10分以内の人には送らない」に使うため）
 * - Firestore には REST で書く（同じプロセスの Flutter 側の Firestore と設定がぶつからないように）。
 *   本人のログインの ID トークンを付けるので、firestore.rules の「本人だけが自分の members を書ける」がそのまま効く
 * - 「常に」でなくなったら何もしない（アプリが次に開いたときに止める）
 */
object BackgroundLocation {
    private const val WORK_NAME = "background_location"

    fun hasAlways(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    /** 「常に」なら定期処理を始め、そうでなければ止める（アプリを開くたびに呼ぶ） */
    fun sync(context: Context) {
        val workManager = WorkManager.getInstance(context)
        if (!hasAlways(context)) {
            workManager.cancelUniqueWork(WORK_NAME)
            return
        }
        val request = PeriodicWorkRequestBuilder<BackgroundLocationWorker>(15, TimeUnit.MINUTES)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        workManager.enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
    }
}

class BackgroundLocationWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    companion object {
        private const val TAG = "BackgroundLocation"
        private const val PREFS = "background_location"
        private const val MIN_MOVE_METERS = 1000f
    }

    override fun doWork(): Result {
        if (!BackgroundLocation.hasAlways(applicationContext)) return Result.success()
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return Result.success()

        return try {
            val client = LocationServices.getFusedLocationProviderClient(applicationContext)
            val location: Location = Tasks.await(
                client.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, CancellationTokenSource().token),
                30, TimeUnit.SECONDS
            ) ?: return Result.success()

            val prefs = applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (prefs.contains("lat")) {
                val distance = FloatArray(1)
                Location.distanceBetween(
                    prefs.getFloat("lat", 0f).toDouble(), prefs.getFloat("lng", 0f).toDouble(),
                    location.latitude, location.longitude, distance
                )
                if (distance[0] < MIN_MOVE_METERS) return Result.success()
            }

            val user = FirebaseAuth.getInstance().currentUser ?: return Result.success()
            val idToken = Tasks.await(user.getIdToken(false), 30, TimeUnit.SECONDS).token ?: return Result.retry()
            val projectId = FirebaseApp.getInstance().options.projectId ?: return Result.success()
            if (!writeLocation(projectId, uid, idToken, location)) return Result.retry()
            prefs.edit()
                .putFloat("lat", location.latitude.toFloat())
                .putFloat("lng", location.longitude.toFloat())
                .apply()
            Result.success()
        } catch (e: SecurityException) {
            Result.success()
        } catch (e: Exception) {
            Log.w(TAG, "場所を書けませんでした", e)
            Result.retry()
        }
    }

    private fun round2(value: Double): Double = (value * 100).roundToLong() / 100.0

    /** members/{uid} の location だけを書き換える（Firestore REST の commit） */
    private fun writeLocation(projectId: String, uid: String, idToken: String, location: Location): Boolean {
        val docName = "projects/$projectId/databases/(default)/documents/members/$uid"
        val fields = JSONObject()
            .put("location", JSONObject().put("mapValue", JSONObject().put("fields", JSONObject()
                .put("latitude", JSONObject().put("doubleValue", round2(location.latitude)))
                .put("longitude", JSONObject().put("doubleValue", round2(location.longitude))))))
            .put("locationSource", JSONObject().put("stringValue", "background"))
        val write = JSONObject()
            .put("update", JSONObject().put("name", docName).put("fields", fields))
            .put("updateMask", JSONObject().put("fieldPaths", JSONArray().put("location").put("locationSource")))
            .put("updateTransforms", JSONArray().put(
                JSONObject().put("fieldPath", "locationUpdatedAt").put("setToServerValue", "REQUEST_TIME")))
            // アプリが作った members があるときだけ書く
            .put("currentDocument", JSONObject().put("exists", true))
        val body = JSONObject().put("writes", JSONArray().put(write)).toString()

        val url = URL("https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:commit")
        val connection = url.openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 20000
            connection.readTimeout = 20000
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $idToken")
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val code = connection.responseCode
            if (code !in 200..299) Log.w(TAG, "場所を書けませんでした: HTTP $code")
            code in 200..299
        } finally {
            connection.disconnect()
        }
    }
}
