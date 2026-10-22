package io.github.tsuchida.thunder_cloud_app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * ウィジェットで見る場所を選ぶ画面（場所の見せ方_画面一覧.png の「見る場所は、ウィジェットごとに選べます」）
 *
 * ウィジェットを置いたとき（と、ウィジェットを長押しして設定し直すとき）に出る。
 * アプリが書いた場所の一覧（いま・家・学校…）から1つ選ぶ。
 */
class CloudWidgetConfigureActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 選ばずに戻ったときは、ウィジェットを置かない
        setResult(RESULT_CANCELED)
        appWidgetId = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val spots = CloudWidgetViews.spots(HomeWidgetPlugin.getData(this))
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(32), dp(20), dp(24))
            setBackgroundColor(Color.parseColor("#F4F8FC"))
        }
        column.addView(TextView(this).apply {
            text = "ウィジェットで見る場所"
            setTextColor(Color.parseColor("#14284A"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            setPadding(0, 0, 0, dp(8))
        })
        column.addView(TextView(this).apply {
            text = if (spots.isEmpty()) {
                "アプリを一度開くと、見張っている場所から選べます。いまは、いまいる場所を出します。"
            } else {
                "タップすると、その場所のホームが開きます。"
            }
            setTextColor(Color.parseColor("#47597A"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setPadding(0, 0, 0, dp(16))
        })

        val choices = spots.ifEmpty { listOf(org.json.JSONObject().put("id", "now").put("label", "いま").put("placeName", "")) }
        for (spot in choices) {
            val id = spot.optString("id")
            val name = spot.optString("placeName")
            val label = spot.optString("label")
            column.addView(Button(this).apply {
                text = if (name.isNotEmpty() && name != label) "$label（$name）" else label
                isAllCaps = false
                setTextColor(Color.parseColor("#14284A"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                gravity = Gravity.CENTER_VERTICAL or Gravity.START
                setPadding(dp(18), 0, dp(18), 0)
                minHeight = dp(56)
                background = GradientDrawable().apply {
                    setColor(Color.WHITE)
                    cornerRadius = dp(18).toFloat()
                }
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(56)).apply {
                    bottomMargin = dp(10)
                }
                setOnClickListener { choose(id) }
            })
        }
        setContentView(ScrollView(this).apply { addView(column) })
    }

    private fun choose(spotId: String) {
        CloudWidgetViews.saveSpot(this, appWidgetId, spotId)
        CloudWidgetViews.updateAll(this)
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId))
        finish()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
