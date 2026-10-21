import SwiftUI
import WidgetKit

/// ホーム画面のウィジェット（docs/design/Widget.html、Plus の機能）
///
/// アプリがホームで計算した結果（lib/services/widget/sky_widget.dart）を App Group の UserDefaults から読むだけ。
/// 中身はアプリを開いたときに新しくなるので、いつの空かが分かるよう「15:21 時点」を出す。
/// タップするとアプリのホームが開く。
///
/// 使い方: Xcode で File > New > Target > Widget Extension（名前 CloudWidget）を足し、
/// できたひな形のファイルをこのファイルに置き換える。アプリとウィジェットの両方に
/// App Group「group.com.tsuchida.thundercloud」を付ける（docs/残りの作業と確認事項.md）。

private let appGroupId = "group.com.tsuchida.thundercloud"

struct SkyEntry: TimelineEntry {
  let date: Date
  let plus: Bool
  let mode: String
  let direction: String
  let km: String
  let fists: String
  let place: String
  let time: String

  static let placeholder = SkyEntry(date: Date(), plus: true, mode: "clouds", direction: "南東", km: "42",
                                    fists: "こぶし1つ半", place: "滝沢市", time: "15:21")

  static func load() -> SkyEntry {
    let data = UserDefaults(suiteName: appGroupId)
    func value(_ key: String) -> String { data?.string(forKey: key) ?? "" }
    return SkyEntry(date: Date(), plus: value("plus") == "1", mode: value("mode"), direction: value("direction"),
                    km: value("km"), fists: value("fists"), place: value("place"), time: value("time"))
  }
}

struct SkyProvider: TimelineProvider {
  func placeholder(in context: Context) -> SkyEntry { .placeholder }

  func getSnapshot(in context: Context, completion: @escaping (SkyEntry) -> Void) {
    completion(context.isPreview ? .placeholder : .load())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SkyEntry>) -> Void) {
    // アプリが新しい中身を書いたときに描き直してもらうので、自分からは更新しない
    completion(Timeline(entries: [.load()], policy: .never))
  }
}

struct CloudWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: SkyEntry

  private var hasCloud: Bool { entry.plus && entry.mode == "clouds" }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(family == .systemMedium && !entry.place.isEmpty ? "入道雲 ・ \(entry.place)" : "入道雲")
        .font(.system(size: 12, weight: .bold))
      Spacer(minLength: 0)
      content
      if entry.plus && !entry.time.isEmpty {
        Text("\(entry.time) 時点").font(.system(size: 11)).opacity(0.8)
      }
    }
    .foregroundColor(.white)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .containerBackground(for: .widget) {
      LinearGradient(
        colors: hasCloud
          ? [Color(red: 0x1C / 255, green: 0x4F / 255, blue: 0xA8 / 255), Color(red: 0x3A / 255, green: 0x7B / 255, blue: 0xC8 / 255)]
          : [Color(red: 0x2A / 255, green: 0x62 / 255, blue: 0xB8 / 255), Color(red: 0x4F / 255, green: 0x8A / 255, blue: 0xD0 / 255)],
        startPoint: .top, endPoint: .bottom)
    }
  }

  @ViewBuilder private var content: some View {
    if !entry.plus {
      Text("Plus の機能です").font(.system(size: 16, weight: .bold))
    } else if entry.mode == "clouds" {
      if family == .systemMedium {
        Text("\(entry.direction)に入道雲").font(.system(size: 22, weight: .bold))
        Text("約\(entry.km)km先").font(.system(size: 15))
        Text("\(entry.fists)の高さ").font(.system(size: 13))
      } else {
        Text(entry.direction).font(.system(size: 26, weight: .bold))
        Text("\(entry.km)km").font(.system(size: 15, weight: .semibold))
      }
    } else if entry.mode == "night" {
      Text("見張りはお休み中").font(.system(size: 16, weight: .bold))
    } else if entry.mode == "empty" {
      Text("静かな空").font(.system(size: 18, weight: .bold))
    } else {
      Text("アプリを開いて空を確かめてください").font(.system(size: 14, weight: .bold))
    }
  }
}

@main
struct CloudWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "CloudWidget", provider: SkyProvider()) { entry in
      CloudWidgetView(entry: entry)
    }
    .configurationDisplayName("入道雲")
    .description("アプリを開かずに、入道雲の方角と距離が分かります。")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
