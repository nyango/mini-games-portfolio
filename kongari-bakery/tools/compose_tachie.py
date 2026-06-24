#!/usr/bin/env python3
"""坂本アヒル氏のPSDToolタイプ立ち絵素材から表情PNGを合成・書き出しする。
実行: /tmp/imgenv/bin/python tools/compose_tachie.py (プロジェクトルートで)
"""
from psd_tools import PSDImage
import os

OUT_DIR = "assets/characters"
TARGET_HEIGHT = 760

# {psdパス: {出力名: {"choices": {グループ名: 選択レイヤー名}, "extras": {グループ名: [追加表示レイヤー]}}}}
CONFIGS = {
    "art_src/ずんだもん立ち絵素材V3.2/ずんだもん立ち絵素材V3.2_基本版.psd": {
        "zundamon_normal": {
            "choices": {"!眉": "*基本眉", "!目": "*基本目", "!口": "*ほほえみ",
                "!右腕": "*腰", "!左腕": "*腰", "!枝豆": "*枝豆通常", "!顔色": "*ほっぺ基本"},
        },
        "zundamon_happy": {
            "choices": {"!眉": "*基本眉", "!目": "*にっこり", "!口": "*あは",
                "!右腕": "*手を挙げる", "!左腕": "*腰", "!枝豆": "*枝豆立ち", "!顔色": "*ほっぺ赤め"},
        },
        "zundamon_sad": {
            "choices": {"!眉": "*困り眉", "!目": "*UU", "!口": "*んえー",
                "!右腕": "*腰", "!左腕": "*腰", "!枝豆": "*枝豆萎え", "!顔色": "*ほっぺ基本"},
            "extras": {"!記号など": ["汗"]},
        },
        "zundamon_surprised": {
            "choices": {"!眉": "*上がり眉", "!目": "*〇〇", "!口": "*うわー",
                "!右腕": "*手を挙げる", "!左腕": "*手を挙げる", "!枝豆": "*枝豆立ち片折れ", "!顔色": "*ほっぺ基本"},
        },
    },
    "art_src/四国めたん立ち絵素材2.1 2/四国めたん立ち絵素材2.1.psd": {
        "metan_normal": {
            "choices": {"!眉": "*太眉ごきげん", "!目": "*目セット", "!口": "*ほほえみ", "!顔色": "*普通2"},
        },
        "metan_happy": {
            "choices": {"!眉": "*太眉ごきげん", "!目": "*目閉じ2", "!口": "*わあー", "!顔色": "*赤面"},
        },
        "metan_sad": {
            "choices": {"!眉": "*太眉こまり", "!目": "*目セット", "!口": "*うえー", "!顔色": "*普通2"},
            "extras": {"記号など": ["汗"]},
        },
    },
    "art_src/あんこもん立ち絵素材/あんこもん立ち絵素材.psd": {
        "ankomon_normal": {
            "choices": {"!眉": "*基本", "!目": "*基本目セット", "!口": "*ほほえみ",
                "!奥の腕": "*腰", "!手前の腕": "*腰", "!頭の豆": "*基本", "!頬・顔色": "*頬"},
        },
        "ankomon_happy": {
            "choices": {"!眉": "*上がり", "!目": "*にっこり", "!口": "*わあー",
                "!奥の腕": "*腰", "!手前の腕": "*手を挙げる", "!頭の豆": "*基本", "!頬・顔色": "*頬2"},
        },
        "ankomon_sad": {
            "choices": {"!眉": "*困り", "!目": "*閉じ", "!口": "*うへー",
                "!奥の腕": "*腰", "!手前の腕": "*腰", "!頭の豆": "*垂れ", "!頬・顔色": "*頬"},
            "extras": {"汗・涙": ["汗1"]},
        },
    },
}


def make_filter(choices: dict, extras: dict):
    def layer_filter(layer):
        name = layer.name
        parent = layer.parent
        pname = getattr(parent, "name", None)
        if pname in choices:
            if name.startswith("*"):
                return name == choices[pname]
            if name in extras.get(pname, []):
                return True
            return layer.visible
        if pname in extras and name in extras[pname]:
            return True
        if name.startswith("*"):
            return layer.visible  # 設定外のラジオグループはデフォルト表示に従う
        if name.startswith("!"):
            return True
        return layer.visible
    return layer_filter


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for psd_path, variants in CONFIGS.items():
        psd = PSDImage.open(psd_path)
        for out_name, config in variants.items():
            f = make_filter(config.get("choices", {}), config.get("extras", {}))
            image = psd.composite(layer_filter=f)
            bbox = image.getbbox()
            image = image.crop(bbox)
            scale = TARGET_HEIGHT / image.height
            image = image.resize((round(image.width * scale), TARGET_HEIGHT))
            out_path = os.path.join(OUT_DIR, out_name + ".png")
            image.save(out_path, optimize=True)
            print(f"{out_path}: {image.width}x{image.height}")


if __name__ == "__main__":
    main()
