# こんがりベーカリー(仮題)

パンを焼いて設備を増やす放置・クリッカーゲーム。Godot 4.6 製。

- 企画書: [docs/concept.md](docs/concept.md)
- リリース計画: unityroom(Web) → BOOTH(DL版/支援版) → Steam

## 開発

```sh
# エディタで開く
godot -e

# 実行
godot

# Webビルド(要: export templates 4.6.3)
godot --headless --export-release "Web" build/web/index.html

# ローカルで動作確認
python3 -m http.server 8000 -d build/web
# → http://localhost:8000
```

## Webエクスポートの注意(unityroom向け)

- **スレッド無効**でエクスポートする(export_presets.cfg で設定済み)
- GDExtension依存のアドオンは使わない
- レンダラーは Compatibility(GL)
