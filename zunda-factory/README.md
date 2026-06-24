# ずんだもん増殖工場(仮)

**設計して、眺めて、蹂躙する。** 生産ラインを設計してずんだもんを量産し、
自動で戦う大群がこげパン軍団を押し返すディフェンス×経済シミュレーション。

- コンセプト: 「計画がハマる瞬間」×「物量と破壊の瞬間」を1画面で
- 左パネル: 生産ライン(ずんだ畑 → 培養槽 → 軍団)。産出と消費のバランス設計が核
- 右画面: 5レーンのオートバトル。設計の良し悪しが戦線の押し引きとして可視化される

## 開発

```sh
# 実行 (プロジェクトルートで)
/Applications/Godot.app/Contents/MacOS/Godot

# Webビルド
/Applications/Godot.app/Contents/MacOS/Godot --headless --export-release "Web" build/web/index.html

# ローカル確認
python3 -m http.server 8766 -d build/web
```

- Godot 4.6 / Compatibilityレンダラー / Webエクスポートはスレッド無効(unityroom対応)
- 効果音は `tools/gen_audio.py` で合成

## クレジット

- ずんだもん司令官 立ち絵: 坂本アヒル様
- SD大群ユニット: 本プロジェクト自作(二次創作)
- 東北ずん子・ずんだもんプロジェクト ガイドライン準拠の二次創作です
  https://zunko.jp/guideline.html
