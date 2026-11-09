"""리링(VAVELING) 캐릭터에 간호사 모자·청진기를 합성해 앱 아이콘과 마스코트 그림을 만든다.

사용: python tools/make_icon.py
입력: tools/src/liling_v2.png (443x640 RGBA)
출력:
  assets/images/mascot/liling_nurse.png        전신 마스코트 (모자+청진기)
  assets/images/mascot/liling_nurse_face.png   얼굴 (홈·결과 화면용, 512x512 투명)
  assets/icon/app_icon.png                     1024 런처 아이콘 (배경 포함)
  assets/icon/app_icon_fg.png                  1024 어댑티브 전경 (투명)
  web/icons/Icon-192.png, Icon-512.png, Icon-maskable-192.png, Icon-maskable-512.png
  web/favicon.png, web/apple-touch-icon.png
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools/src/liling_v2.png"

MINT = (94, 205, 190)
MINT_DARK = (56, 170, 160)
PINK = (255, 143, 171)
RED = (232, 72, 85)
WHITE = (255, 255, 255)


def draw_cap(img, cx, top, width, scale=1.0, tilt=-8):
    """간호사 모자: 흰 사다리꼴 + 붉은 십자. cx·top 은 모자 밑변 가운데 기준."""
    w = int(width)
    h = int(width * 0.42)
    pad = int(w * 0.3)
    cap = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(cap)
    x0, y0 = pad, pad
    poly = [
        (x0 + w * 0.18, y0),
        (x0 + w * 0.82, y0),
        (x0 + w, y0 + h * 0.86),
        (x0 + w * 0.5, y0 + h),
        (x0, y0 + h * 0.86),
    ]
    shadow = Image.new("RGBA", cap.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon([(x + 4 * scale, y + 6 * scale) for x, y in poly], fill=(60, 90, 120, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(4 * scale))
    cap.alpha_composite(shadow)
    d.polygon(poly, fill=WHITE, outline=(205, 215, 230))
    d.line([(x0 + w * 0.18, y0 + h * 0.08), (x0 + w * 0.82, y0 + h * 0.08)], fill=(225, 232, 242), width=max(2, int(3 * scale)))
    cw = w * 0.22
    ct = cw * 0.34
    ccx, ccy = x0 + w * 0.5, y0 + h * 0.5
    d.rounded_rectangle([ccx - cw / 2, ccy - ct / 2, ccx + cw / 2, ccy + ct / 2], radius=ct * 0.3, fill=RED)
    d.rounded_rectangle([ccx - ct / 2, ccy - cw / 2, ccx + ct / 2, ccy + cw / 2], radius=ct * 0.3, fill=RED)
    cap = cap.rotate(tilt, resample=Image.BICUBIC, expand=True)
    px = int(cx - cap.width / 2)
    py = int(top - cap.height / 2 - h * 0.1)
    img.alpha_composite(cap, (px, py))


def draw_stethoscope(img, neck_cx, neck_y, w, scale=1.0):
    """목에 두른 청진기: 어깨 양쪽에서 내려와 가슴 쪽에서 둥근 청진판."""
    d = ImageDraw.Draw(img)
    tube = (70, 85, 110)
    lw = max(3, int(7 * scale))
    lx, rx = neck_cx - w * 0.38, neck_cx + w * 0.38
    d.line([(lx, neck_y), (lx - w * 0.05, neck_y + w * 0.45), (lx + w * 0.25, neck_y + w * 0.72)], fill=tube, width=lw, joint="curve")
    d.line([(rx, neck_y), (rx + w * 0.08, neck_y + w * 0.5), (rx - w * 0.05, neck_y + w * 0.78)], fill=tube, width=lw, joint="curve")
    d.arc([lx, neck_y - w * 0.22, rx, neck_y + w * 0.22], start=200, end=340, fill=tube, width=lw)
    r = w * 0.11
    cx, cy = rx - w * 0.05, neck_y + w * 0.78
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(170, 180, 200), outline=(110, 120, 140), width=max(2, int(3 * scale)))
    d.ellipse([cx - r * 0.55, cy - r * 0.55, cx + r * 0.55, cy + r * 0.55], fill=(225, 230, 240))
    r2 = w * 0.045
    ex, ey = lx + w * 0.25, neck_y + w * 0.72
    d.ellipse([ex - r2, ey - r2, ex + r2, ey + r2], fill=(170, 180, 200))


def rounded_bg(size, radius_ratio=0.22):
    """민트 → 진한 민트 세로 그라데이션 둥근 사각형."""
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad = Image.new("RGBA", (size, size))
    gp = grad.load()
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(MINT[i] * (1 - t) + MINT_DARK[i] * t) for i in range(3)) + (255,)
        for x in range(size):
            gp[x, y] = c
    mask = Image.new("L", (size, size), 0)
    if radius_ratio > 0:
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * radius_ratio), fill=255)
    else:
        ImageDraw.Draw(mask).rectangle([0, 0, size - 1, size - 1], fill=255)
    bg.paste(grad, (0, 0), mask)
    deco = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dd = ImageDraw.Draw(deco)
    dd.ellipse([-size * 0.2, size * 0.78, size * 0.7, size * 1.3], fill=(255, 255, 255, 40))
    dd.ellipse([size * 0.45, size * 0.84, size * 1.2, size * 1.4], fill=(255, 255, 255, 35))
    deco.putalpha(Image.composite(deco.getchannel("A"), Image.new("L", (size, size), 0), mask))
    bg.alpha_composite(deco)
    return bg


def main():
    src = Image.open(SRC).convert("RGBA")
    W, H = src.size  # 443x640

    # 전신 마스코트
    body = Image.new("RGBA", (W, H + 40), (0, 0, 0, 0))
    body.alpha_composite(src, (0, 40))
    draw_cap(body, cx=W * 0.47, top=118, width=W * 0.30, scale=1.0, tilt=-10)
    draw_stethoscope(body, neck_cx=W * 0.52, neck_y=40 + H * 0.515, w=W * 0.22, scale=0.8)
    out_dir = ROOT / "assets/images/mascot"
    out_dir.mkdir(parents=True, exist_ok=True)
    body.save(out_dir / "liling_nurse.png", optimize=True)

    # 얼굴 (머리 부분 크롭 → 정사각)
    face_src = body.crop((int(W * 0.08), 0, int(W * 0.92), int(H * 0.56)))
    fw, fh = face_src.size
    side = max(fw, fh)
    face = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    face.alpha_composite(face_src, ((side - fw) // 2, (side - fh) // 2))
    face = face.resize((512, 512), Image.LANCZOS)
    face.save(out_dir / "liling_nurse_face.png", optimize=True)

    # 아이콘
    size = 1024

    def make_fg(scale_ratio, dy_ratio):
        fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        target = int(size * scale_ratio)
        head = face_src.resize((int(fw * target / fh), target), Image.LANCZOS)
        sh = Image.new("RGBA", head.size, (0, 0, 0, 0))
        sh.paste((0, 40, 60, 110), (0, 0), head.getchannel("A"))
        sh = sh.filter(ImageFilter.GaussianBlur(18))
        px = (size - head.width) // 2
        py = int(size * dy_ratio)
        fg.alpha_composite(sh, (px + 6, py + 16))
        fg.alpha_composite(head, (px, py))
        return fg

    bg = rounded_bg(size)
    icon = bg.copy()
    icon.alpha_composite(make_fg(0.86, 0.12))
    badge = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bd = ImageDraw.Draw(badge)
    bx, by, br = size * 0.80, size * 0.80, size * 0.13
    bd.ellipse([bx - br, by - br, bx + br, by + br], fill=WHITE)
    bd.ellipse([bx - br, by - br, bx + br, by + br], outline=(230, 236, 242), width=6)
    hr = br * 0.42
    hx, hy = bx, by + hr * 0.1
    bd.ellipse([hx - hr, hy - hr * 0.9, hx, hy + hr * 0.1], fill=PINK)
    bd.ellipse([hx, hy - hr * 0.9, hx + hr, hy + hr * 0.1], fill=PINK)
    bd.polygon([(hx - hr * 0.98, hy - hr * 0.25), (hx + hr * 0.98, hy - hr * 0.25), (hx, hy + hr * 0.95)], fill=PINK)
    icon.alpha_composite(badge)
    (ROOT / "assets/icon").mkdir(parents=True, exist_ok=True)
    icon.convert("RGB").save(ROOT / "assets/icon/app_icon.png", optimize=True)

    fg_adaptive = make_fg(0.62, 0.22)
    fg_adaptive.save(ROOT / "assets/icon/app_icon_fg.png", optimize=True)

    web_icons = ROOT / "web/icons"
    web_icons.mkdir(parents=True, exist_ok=True)
    for s in (192, 512):
        icon.resize((s, s), Image.LANCZOS).convert("RGB").save(web_icons / f"Icon-{s}.png", optimize=True)
        m = rounded_bg(size, radius_ratio=0.0)
        m.alpha_composite(fg_adaptive)
        m.resize((s, s), Image.LANCZOS).convert("RGB").save(web_icons / f"Icon-maskable-{s}.png", optimize=True)
    icon.resize((64, 64), Image.LANCZOS).save(ROOT / "web/favicon.png", optimize=True)
    icon.resize((180, 180), Image.LANCZOS).convert("RGB").save(ROOT / "web/apple-touch-icon.png", optimize=True)
    print("done")


if __name__ == "__main__":
    main()
