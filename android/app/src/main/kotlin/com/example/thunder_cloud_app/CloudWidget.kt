package io.github.tsuchida.thunder_cloud_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * ホーム画面のウィジェット（docs/design/Widget.html、Plus の機能）
 *
 * アプリがホームで計算した結果（lib/services/widget/sky_widget.dart）を表示するだけ。
 * 中身はアプリを開いたときに新しくなるので、いつの空かが分かるよう「15:21 時点」を出す。
 * タップするとアプリのホームが開く。
 */
private object CloudWidgetViews {
    fun build(context: Context, data: SharedPreferences, medium: Boolean): RemoteViews {
        val plus = data.getString("plus", "0") == "1"
        val mode = data.getString("mode", "none") ?: "none"
        val direction = data.getString("direction", "") ?: ""
        val km = data.getString("km", "") ?: ""
        val fists = data.getString("fists", "") ?: ""
        val place = data.getString("place", "") ?: ""
        val time = data.getString("time", "") ?: ""

        val hasCloud = plus && mode == "clouds"
        val layout = if (medium) R.layout.cloud_widget_medium else R.layout.cloud_widget_small
        val views = RemoteViews(context.packageName, layout)
        views.setInt(
            R.id.widget_root, "setBackgroundResource",
            if (hasCloud) R.drawable.cloud_widget_bg else R.drawable.cloud_widget_bg_calm
        )
        views.setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))

        views.setTextViewText(R.id.widget_label, if (medium && place.isNotEmpty()) "入道雲 ・ $place" else "入道雲")
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
        return views
    }

    private fun setOptional(views: RemoteViews, id: Int, text: String) {
        views.setTextViewText(id, text)
        views.setViewVisibility(id, if (text.isEmpty()) View.GONE else View.VISIBLE)
    }
}

class CloudWidgetSmall : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, CloudWidgetViews.build(context, widgetData, medium = false)) }
    }
}

class CloudWidgetMedium : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, CloudWidgetViews.build(context, widgetData, medium = true)) }
    }
}
