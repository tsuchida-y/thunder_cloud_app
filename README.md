# ThunderCloudApp

## 背景・目的

- 入道雲が好きなので、自分が見える範囲で入道雲を見逃したくないと思い作成した。
- 自分の好きなもののためにアプリ開発を行なってみたかったから作成した。

## 機能

- 現在地を取得し、東西南北30km離れたところの気象状況を取得する。
- 入道雲が出現していると判断されたら画面に入道雲の画像を出現させる
- 5秒に一度、天気情報を取得しUIを更新する

## 工夫した点

- アプリの背景を地図にし、右上に方角がわかる画像を配置することで自分の位置からどこに入道雲が出現したか分かりやすくした。
- ファイルを複数に分け、可読性を向上させた

## ファイル構成

- `main.dart`：アプリのエントリーポイントがあるファイル
- `screens`
  - `weather_screen.dart`：特定の方向に入道雲があるかを地図とカスタムウィジェットで視覚的に表示する画面を構築するファイル
- `services`
  - `geolocator.dart`：デバイスの位置情報権限を確認し、現在地（緯度と経度）を取得するための関数を提供するファイル
  - `weather_api.dart`：OpenWeatherMap API を使用して北、南、東、西の各方向に一定距離離れた地点の天候データを取得するファイル
- `widgets`
  - `cloud_avatar.dart`：天候の状態（入道雲または晴れ）に応じて背景画像を切り替えるファイル
  - `direction_image.dart`：方角の画像を保持するファイル

## 使用方法

1. アプリを起動するとホーム画面が表示される。
2. 位置情報を許可するかの確認画面が表示されるので許可する。
3. アプリは定期的に天気情報を取得し、画面に表示する。

## 今後

- 入道雲サーチの数値があっているかを実際に確認する

## 実際の画面


<table>
  <tr>
    <td align="center">
      <p><strong>Pixel 4 API 35</strong></p>
      <img src="https://github.com/user-attachments/assets/b3f9dd55-85d6-46da-b439-bdd5b95dcced" width="300px" />
    </td>
    <td align="center">
      <p><strong>iPhone 16 Plus</strong></p>
      <img src="https://github.com/user-attachments/assets/2a06f13c-1b97-4542-b6ff-11f37fe3cdd1" width="300px" />
    </td>
  </tr>
</table>
