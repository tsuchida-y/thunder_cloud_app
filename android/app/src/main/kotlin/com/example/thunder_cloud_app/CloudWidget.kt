package io.github.tsuchida.thunder_cloud_app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import kotlin.math.cos
import kotlin.math.sin
import org.json.JSONArray
import org.json.JSONObject

/**
 * ホーム画面のウィジェット（docs/design/Widget.html と 場所の見せ方_画面一覧.png、Plus の機能）
 *
 * アプリが見張っているすべての場所の空（lib/services/widget/sky_widget.dart の spots）から、
 * ウィジェットごとに選んだ場所（CloudWidgetConfigureActivity）の分だけを出す。選んでいなければ最初の場所（いま）。
 * 中身はアプリを開いたときに新しくなるので、いつの空かが分かるよう「15:21 時点」を出す。
 * タップすると、その場所に切り替えたホームが開く（thundercloud://spot?id=…）。
 */
object CloudWidgetViews {
    private const val CONFIG_PREFS = "cloud_widget_config"

    fun saveSpot(context: Context, appWidgetId: Int, spotId: String) {
        context.getSharedPreferences(CONFIG_PREFS, Context.MODE_PRIVATE).edit().putString("spot_$appWidgetId", spotId).apply()
    }

    private fun savedSpot(context: Context, appWidgetId: Int): String? =
        context.getSharedPreferences(CONFIG_PREFS, Context.MODE_PRIVATE).getString("spot_$appWidgetId", null)

    /** アプリが書いた場所の一覧 */
    fun spots(data: SharedPreferences): List<JSONObject> {
        val raw = data.getString("spots", null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { array.getJSONObject(it) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /** 置いてあるウィジェットを、すべて描き直す（場所を選んだあとなど） */
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val data = HomeWidgetPlugin.getData(context)
        for ((cls, medium) in listOf(CloudWidgetSmall::class.java to false, CloudWidgetMedium::class.java to true)) {
            for (id in manager.getAppWidgetIds(ComponentName(context, cls))) {
                manager.updateAppWidget(id, build(context, data, id, medium))
            }
        }
    }

    fun build(context: Context, data: SharedPreferences, appWidgetId: Int, medium: Boolean): RemoteViews {
        val plus = data.getString("plus", "0") == "1"
        val time = data.getString("time", "") ?: ""
        val all = spots(data)
        val chosen = savedSpot(context, appWidgetId)
        val spot = all.firstOrNull { it.optString("id") == chosen } ?: all.firstOrNull()

        val mode = spot?.optString("mode") ?: "none"
        val label = spot?.optString("label").orEmpty()
        val placeName = spot?.optString("placeName").orEmpty()
        val direction = spot?.optString("direction").orEmpty()
        val km = spot?.optInt("km", -1) ?: -1
        val fists = spot?.optString("fists").orEmpty()
        val bearing = spot?.optDouble("bearingDeg", -1.0) ?: -1.0
        val hasCloud = plus && mode == "clouds"

        val layout = if (medium) R.layout.cloud_widget_medium else R.layout.cloud_widget_small
        val views = RemoteViews(context.packageName, layout)
        views.setInt(
            R.id.widget_root, "setBackgroundResource",
            if (hasCloud) R.drawable.cloud_widget_bg else R.drawable.cloud_widget_bg_calm
        )
        val uri = Uri.parse("thundercloud://spot?id=${Uri.encode(spot?.optString("id") ?: "now")}")
        views.setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri))

        // 上の見出し: 小は「家」、中は「いま ・ 滝沢市」
        val heading = when {
            spot == null -> "入道雲"
            medium && placeName.isNotEmpty() -> "$label ・ $placeName"
            else -> label
        }
        views.setTextViewText(R.id.widget_label, heading)

        val (headline, sub, detail) = when {
            !plus -> Triple("Plus の機能です", "", "")
            mode == "clouds" -> if (medium) {
                Triple("${direction}に入道雲", "約${km}km先", "${fists}の高さ")
            } else {
                Triple(direction, "${km}km", "")
            }
            mode == "night" -> Triple("見張りはお休み中", "", "")
            mode == "empty" -> Triple("静かな空", "", "")
            else -> Triple("アプリを開いて空を確かめてください", "", "")
        }
        views.setTextViewText(R.id.widget_headline, headline)
        setOptional(views, R.id.widget_sub, sub)
        if (medium) setOptional(views, R.id.widget_detail, detail)
        // 気象庁のデータから出した中身なので、出典を出す（CLAUDE.md）
        setOptional(views, R.id.widget_time, if (plus && time.isNotEmpty()) "$time 時点 ・ 出典：気象庁" else "")

        // 小さな方位の丸（北が上、雲の方角に点）。小は雲があるときだけ、中はいつも
        val showCompass = plus && (medium || hasCloud)
        if (showCompass) {
            val sizePx = (context.resources.displayMetrics.density * if (medium) 96 else 40).toInt()
            views.setImageViewBitmap(R.id.widget_compass, compass(sizePx, if (hasCloud && bearing >= 0) bearing else null))
        }
        views.setViewVisibility(R.id.widget_compass, if (showCompass) View.VISIBLE else View.GONE)
        return views
    }

    private fun compass(size: Int, bearingDeg: Double?): Bitmap {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val c = size / 2f
        val r = size / 2f - size * 0.05f
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(46, 255, 255, 255) }
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = size * 0.025f
            color = Color.argb(153, 255, 255, 255)
        }
        val white = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        canvas.drawCircle(c, c, r, fill)
        canvas.drawCircle(c, c, r, stroke)
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = size * 0.16f
            textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
        }
        canvas.drawText("N", c, size * 0.22f, text)
        canvas.drawCircle(c, c, size * 0.055f, white)
        if (bearingDeg != null) {
            val a = Math.toRadians(bearingDeg)
            val d = r * 0.6f
            canvas.drawCircle(c + (sin(a) * d).toFloat(), c - (cos(a) * d).toFloat(), size * 0.11f, white)
        }
        return bitmap
    }

    private fun setOptional(views: RemoteViews, id: Int, text: String) {
        views.setTextViewText(id, text)
        views.setViewVisibility(id, if (text.isEmpty()) View.GONE else View.VISIBLE)
    }
}

class CloudWidgetSmall : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, CloudWidgetViews.build(context, widgetData, it, medium = false)) }
    }
}

class CloudWidgetMedium : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, CloudWidgetViews.build(context, widgetData, it, medium = true)) }
    }
}
