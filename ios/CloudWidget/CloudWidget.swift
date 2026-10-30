import AppIntents
import SwiftUI
import WidgetKit

/// ホーム画面のウィジェット（docs/design/Widget.html と 場所の見せ方_画面一覧.png、Plus の機能）
///
/// アプリが見張っているすべての場所の空（lib/services/widget/sky_widget.dart の spots）を App Group から読み、
/// ウィジェットごとに選んだ場所（長押し > ウィジェットを編集）の分だけを出す。選んでいなければ最初の場所（いま）。
/// 中身はアプリを開いたときに新しくなるので、いつの空かが分かるよう「15:21 時点」を出す。
/// タップすると、その場所に切り替えたホームが開く（thundercloud://spot?id=…）。
///
/// 使い方: Xcode で File > New > Target > Widget Extension（名前 CloudWidget）を足し、
/// できたひな形のファイルをこのファイルに置き換える。アプリとウィジェットの両方に
/// App Group「group.com.tsuchida.thundercloud」を付ける（docs/お願いしたい作業の手順.md の3）。

private let appGroupId = "group.com.tsuchida.thundercloud"

// MARK: - アプリが書いた中身

/// 1つの場所の空（sky_widget.dart の WidgetSpot.toJson と同じ形）
struct SpotData: Decodable {
  let id: String
  let label: String
  let placeName: String
  let mode: String
  let direction: String
  let bearingDeg: Double
  let km: Int
  let fists: String

  /// 「家（盛岡市）」
  var title: String { placeName.isEmpty || placeName == label ? label : "\(label)（\(placeName)）" }
}

enum SharedSky {
  static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

  static func spots() -> [SpotData] {
    guard let raw = defaults?.string(forKey: "spots"), let data = raw.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([SpotData].self, from: data)) ?? []
  }

  static var isPlus: Bool { defaults?.string(forKey: "plus") == "1" }
  static var time: String { defaults?.string(forKey: "time") ?? "" }
}

// MARK: - 見る場所を選ぶ設定

struct SpotEntity: AppEntity {
  let id: String
  let title: String

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "場所"
  static var defaultQuery = SpotQuery()

  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

struct SpotQuery: EntityQuery {
  private func all() -> [SpotEntity] {
    let spots = SharedSky.spots().map { SpotEntity(id: $0.id, title: $0.title) }
    // アプリをまだ開いていないときも、いまいる場所は選べるようにする
    return spots.isEmpty ? [SpotEntity(id: "now", title: "現在地")] : spots
  }

  func entities(for identifiers: [String]) async throws -> [SpotEntity] {
    all().filter { identifiers.contains($0.id) }
  }

  func suggestedEntities() async throws -> [SpotEntity] { all() }

  func defaultResult() async -> SpotEntity? { all().first }
}

struct SelectSpotIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "見る場所"
  static var description = IntentDescription("ウィジェットで見る場所を選びます。タップすると、その場所のホームが開きます。")

  @Parameter(title: "場所")
  var spot: SpotEntity?
}

// MARK: - タイムライン

struct SkyEntry: TimelineEntry {
  let date: Date
  let plus: Bool
  let time: String
  let spot: SpotData?

  static let placeholder = SkyEntry(
    date: Date(), plus: true, time: "15:21",
    spot: SpotData(id: "now", label: "現在地", placeName: "滝沢市", mode: "clouds", direction: "南東",
                   bearingDeg: 135, km: 42, fists: "こぶし1つ半"))

  static func load(spotId: String?) -> SkyEntry {
    let spots = SharedSky.spots()
    let spot = spots.first { $0.id == spotId } ?? spots.first
    return SkyEntry(date: Date(), plus: SharedSky.isPlus, time: SharedSky.time, spot: spot)
  }
}

struct SkyProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> SkyEntry { .placeholder }

  func snapshot(for configuration: SelectSpotIntent, in context: Context) async -> SkyEntry {
    context.isPreview ? .placeholder : .load(spotId: configuration.spot?.id)
  }

  func timeline(for configuration: SelectSpotIntent, in context: Context) async -> Timeline<SkyEntry> {
    // アプリが新しい中身を書いたときに描き直してもらうので、自分からは更新しない
    Timeline(entries: [.load(spotId: configuration.spot?.id)], policy: .never)
  }
}

// MARK: - 見た目

/// 小さな方位の丸（北が上、雲の方角に点）
struct CompassView: View {
  let bearingDeg: Double?

  var body: some View {
    GeometryReader { geo in
      let size = min(geo.size.width, geo.size.height)
      let r = size / 2
      ZStack {
        Circle().fill(Color.white.opacity(0.18))
        Circle().stroke(Color.white.opacity(0.6), lineWidth: max(1, size * 0.025))
        Text("N").font(.system(size: size * 0.16, weight: .bold)).foregroundColor(.white)
          .position(x: r, y: size * 0.17)
        Circle().fill(Color.white).frame(width: size * 0.11, height: size * 0.11).position(x: r, y: r)
        if let bearing = bearingDeg {
          let a = bearing * .pi / 180
          let d = r * 0.6
          Circle().fill(Color.white).frame(width: size * 0.22, height: size * 0.22)
            .position(x: r + CGFloat(sin(a)) * d, y: r - CGFloat(cos(a)) * d)
        }
      }
      .frame(width: size, height: size)
    }
    .accessibilityLabel("雲の方角")
  }
}

struct CloudWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: SkyEntry

  private var spot: SpotData? { entry.spot }
  private var hasCloud: Bool { entry.plus && spot?.mode == "clouds" }
  private var bearing: Double? { hasCloud && (spot?.bearingDeg ?? -1) >= 0 ? spot?.bearingDeg : nil }

  var body: some View {
    Group {
      if family == .systemMedium {
        HStack(spacing: 16) {
          if entry.plus { CompassView(bearingDeg: bearing).frame(width: 96, height: 96) }
          VStack(alignment: .leading, spacing: 2) {
            Text(mediumHeading).font(.system(size: 12, weight: .bold)).lineLimit(1)
            content
            footer
          }
          Spacer(minLength: 0)
        }
      } else {
        VStack(alignment: .leading, spacing: 2) {
          HStack(alignment: .top) {
            Text(spot?.label ?? "入道雲").font(.system(size: 12, weight: .bold)).lineLimit(1)
            Spacer(minLength: 0)
            if hasCloud { CompassView(bearingDeg: bearing).frame(width: 40, height: 40) }
          }
          Spacer(minLength: 0)
          content
          footer
        }
      }
    }
    .foregroundColor(.white)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .widgetURL(URL(string: "thundercloud://spot?id=\(spot?.id ?? "now")&homeWidget"))
    .containerBackground(for: .widget) {
      LinearGradient(
        colors: hasCloud
          ? [Color(red: 0x1C / 255, green: 0x4F / 255, blue: 0xA8 / 255), Color(red: 0x3A / 255, green: 0x7B / 255, blue: 0xC8 / 255)]
          : [Color(red: 0x2A / 255, green: 0x62 / 255, blue: 0xB8 / 255), Color(red: 0x4F / 255, green: 0x8A / 255, blue: 0xD0 / 255)],
        startPoint: .top, endPoint: .bottom)
    }
  }

  /// 中の見出し「現在地 ・ 滝沢市」
  private var mediumHeading: String {
    guard let spot = spot else { return "入道雲" }
    return spot.placeName.isEmpty ? spot.label : "\(spot.label) ・ \(spot.placeName)"
  }

  @ViewBuilder private var footer: some View {
    // 気象庁のデータから出した中身なので、出典を出す（CLAUDE.md）
    if entry.plus && !entry.time.isEmpty {
      Text("\(entry.time) 時点 ・ 出典：気象庁").font(.system(size: 10)).opacity(0.8).lineLimit(1).minimumScaleFactor(0.8)
    }
  }

  @ViewBuilder private var content: some View {
    if !entry.plus {
      Text("Plus の機能です").font(.system(size: 16, weight: .bold))
    } else if let spot = spot, spot.mode == "clouds" {
      if family == .systemMedium {
        Text("\(spot.direction)に入道雲").font(.system(size: 20, weight: .bold))
        Text("約\(spot.km)km先").font(.system(size: 13))
        Text("\(spot.fists)の高さ").font(.system(size: 13))
      } else {
        Text(spot.direction).font(.system(size: 26, weight: .bold))
        Text("\(spot.km)km").font(.system(size: 15, weight: .semibold))
      }
    } else if spot?.mode == "night" {
      Text("見張りはお休み中").font(.system(size: 16, weight: .bold))
    } else if spot?.mode == "empty" {
      Text("静かな空").font(.system(size: 18, weight: .bold))
    } else {
      Text("アプリを開いて空を確かめてください").font(.system(size: 14, weight: .bold))
    }
  }
}

@main
struct CloudWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: "CloudWidget", intent: SelectSpotIntent.self, provider: SkyProvider()) { entry in
      CloudWidgetView(entry: entry)
    }
    .configurationDisplayName("入道雲")
    .description("アプリを開かずに、入道雲の方角と距離が分かります。見る場所は、ウィジェットごとに選べます。")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
