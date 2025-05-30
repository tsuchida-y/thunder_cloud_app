# 入道雲サーチアプリ

## 背景・目的

- **入道雲を見逃さないために**  
  自分の好きな入道雲が、どの方向で出現しているかを知りたいという思いから開発しました。  
- **自分の好きなもののためにアプリ開発に挑戦**  
  趣味としてのクラウド観察と Flutter を利用して、実用的なアプリ作成に挑戦。

## 機能

- **入道雲の出現方向の表示**  
  自分の現在位置を基準に、東西南北のどこに入道雲が出現しているかを表示します。
- **定期的な天気情報取得**  
  5秒ごとに天気情報を API を通じて取得し、リアルタイムに画面を更新します。
- **地図表示**  
  現在地や周辺の情報を GoogleMap 上に表示し、視覚的に分かりやすくしています。
- **方向ごとのウィジェット配置**  
  各方向の入道雲情報に応じて、画面上に `CloudAvatar` 等のウィジェットを動的に配置しています。

## ファイル構成

```
thunder_cloud_app/
├── lib/
│   ├── main.dart                          // アプリのエントリーポイント
│   ├── constants/
│   │   └── avatar_positions.dart          // ウィジェットの配置位置などの定数
│   ├── screens/
│   │   └── weather_screen.dart            // 天気情報表示画面の状態管理
│   ├── services/
│   │   ├── geolocator.dart                // 現在地取得のロジック
│   │   ├── location_service.dart          // 位置情報サービス（Google Maps用型変換）
│   │   ├── weather_service.dart           // 天気サービス統合インターフェース
│   │   └── weather/
│   │       ├── weather_api.dart           // OpenWeatherMap API へのリクエスト実装
│   │       ├── directional_weather.dart   // 方向ごとの天気取得ロジック
│   │       └── weather_logic.dart         // 入道雲判定ロジック
│   └── widgets/
│       ├── cloud_avatar.dart              // 入道雲または青空の画像を表示するウィジェット
│       ├── direction_image.dart           // 画面上に方向を示す画像
│       ├── weather_app_bar.dart           // AppBar専用ウィジェット
│       ├── weather_map_view.dart          // GoogleMap背景表示ウィジェット
│       └── weather_overlay.dart           // 天気情報オーバーレイウィジェット
```
## 工夫した点
- 位置情報と距離計算
  * 緯度1度あたりの距離を考慮した正確な方向計算（特に経度は緯度によって距離が変わるため、三角関数を使用）
  * 現在地から約30kmの距離にある各方向のポイントを計算し、最適な天気情報を取得
  * 方向ごとに一般化されたメソッド（fetchWeatherInDirection）で、コードの冗長性を削減
  * UI・ロジック・定数などの責務ごとにファイルを分割し、保守性と再利用性を向上
- ユーザー体験の向上
  * Timer.periodic を使用した定期的な天気情報更新により、リアルタイムな情報提供を実現
  * GoogleMap と連携した視覚的なインターフェースで方向感覚を分かりやすく表現
  * 入道雲の条件判定ロジックを最適化し、より正確な検出を実現

## 使用方法

1. **セットアップ**  
   - プロジェクトルートに `.env` ファイルを作成し、API キーなどの環境変数を設定します。  
     例：
     ```
     OpenWhetherAPI_Key=your_api_key_here
     CLOUDY_IMAGE_PATH=image/cloud2.jpg
     CLEAR_IMAGE_PATH=image/bluesky.jpg
     ```
   - 必要な依存パッケージをインストールします。
     ```bash
     flutter pub get
     ```

2. **アプリの起動**  
   - `main.dart` をエントリーポイントとして、Flutter アプリを起動します。
     ```bash
     flutter run
     ```

3. **動作確認**  
   - アプリ起動後、現在地が地図上に表示され、5秒ごとに各方向の天気情報が更新されます。
   - 入道雲と判断される条件の場合、対応する方向のウィジェット（CloudAvatar）が更新されます。

## アプリの動作例

以下は、アプリを実際に動作させた際のスクリーンショットです。

<table>
  <tr>
    <td><img src="./assets/images/place_permission.png" alt="アプリのメイン画面2" width="300"/></td>
    <td><img src="./assets/images/thunder_cloud.png" alt="アプリのメイン画面1" width="300"/></td>
  </tr>
</table>


## 今後の展望

- **画像保存・共有機能**
    * 入手した入道雲の写真を保存、もしくは SNS などで共有できるようにする。
    * アップするたびにモンスターが成長していくとか
- **拡張機能**  
    * 入道雲以外の雲情報や、柔軟なカスタム描画によるウィジェット表現の導入。
- **UI/UX の改善**  
    * 現在地取得やエラーハンドリングをさらに強化し、ユーザーにとって使いやすいインターフェースを実現する。

## 開発用メモ
- 使用可能なiOSシミュレータ
```
xcrun simctl list devices
```

- シミュレータの起動
```
xcrun simctl boot <UDID>
xcrun simctl boot CD928AEE-F546-4212-A73D-E491C33E041F
```
- シミュレータを開く
```
open -a Simulator
```
