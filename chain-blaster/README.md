# CHAIN BLASTER

Godot 4.6製の物理連鎖爆破パズルです。

## コンセプト

1発の爆風で赤い爆薬クレートを誘爆させ、ステージ上の赤クレートをすべて吹き飛ばします。
物理の崩れ方・誘爆タイミング・スローモーション・画面揺れで爽快感を出すミニゲームです。

## 遊び方

- クリック/タップ: その場所で爆破
- 赤いクレート: 誘爆対象。全部破壊すればクリア
- 茶色いクレート: 物理障害物。爆風で動くがクリア対象ではない
- Rキー: レベル1からリセット
- CLEAR後にクリック/タップ: 次のレベルへ

## 開発

```sh
cd chain-blaster
/Applications/Godot.app/Contents/MacOS/Godot
```

## Webビルド

```sh
cd chain-blaster
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
```

GitHub Pages向けに `build/web/coi-serviceworker.js` を同梱しています。
