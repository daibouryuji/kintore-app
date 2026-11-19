# 筋トレ記録（Flutter Web / PWA）

自分専用の筋トレ記録アプリです。iPhone の Safari で開いて「ホーム画面に追加」すると、アプリのように使えます。

## 機能

- **今日**：曜日（または順番モードなら前回の次）のメニューを表示。ずれた日はプルダウンで別メニューに切り替え。
  セットごとに重量・回数を入力し、チェックを入れたセットが記録になります。前回の値が最初から入っています。
- **種目**：数の制限なく追加・編集・削除。種目ごとのメモ（例：セーフティの高さ9）、履歴、最高重量。
- **メニュー**：プッシュ・プルなどを登録し、基本の曜日・種目・目標セット数/回数を設定。並び順が順番モードの順番。
- **体重**：日付ごとに記録、グラフと前回差。
- **設定**：バックアップの書き出し・復元（JSON）、記録のCSVコピー。

初回起動時に PPL＋上半身/下半身 の5メニューが入っています（自由に変更・削除できます）。

## セットアップ

Flutter SDK（3.27 以降）が入っている前提です。

```bash
# 1. 空のプロジェクトを作る
flutter create --platforms=web kintore_app
cd kintore_app

# 2. 依存パッケージを追加
flutter pub add shared_preferences
flutter pub add flutter_localizations --sdk=flutter

# 3. この zip の lib/ と web/manifest.json で上書きする
#    （lib/ の中身は全部置き換え、test/ は削除してOK）

# 4. 動作確認（パソコンのブラウザ）
flutter run -d chrome
```

`web/index.html` の `apple-mobile-web-app-title` の値を「筋トレ」などに変えると、ホーム画面のアプリ名になります。

## iPhone で使う（公開）

PWA として iPhone で使うには HTTPS で公開する必要があります。無料でできる方法の例：

### GitHub Pages

```bash
flutter build web --release --base-href /kintore_app/
```

`build/web` の中身を GitHub リポジトリ `kintore_app` の `gh-pages` ブランチ（または Pages に設定したフォルダ）に置き、
`https://<ユーザー名>.github.io/kintore_app/` を iPhone の Safari で開いて「共有 → ホーム画面に追加」。

### Firebase Hosting

```bash
flutter build web --release
firebase init hosting   # public ディレクトリに build/web を指定
firebase deploy
```

## データについて

- データはブラウザ（ホーム画面に追加したアプリ）の中に保存されます。サーバーには送られません。
- Safari で開いたときと、ホーム画面から開いたときでは保存場所が別です。ホーム画面のアプリで使ってください。
- 機種変更やデータ削除に備えて、ときどき「設定 → バックアップを書き出す」でコピーし、メモアプリなどに貼っておいてください。
- アプリを更新しても、同じURLで公開している限りデータは残ります。
