"""부드러운 효과음 합성 → assets/sounds/*.wav

사용: python tools/make_sfx.py
사인·삼각파에 느린 어택과 긴 릴리즈, 살짝 디튠한 두 겹, 저역 통과 필터, 짧은 잔향을 줘서
딱딱한 실로폰 대신 「글로켄슈필·마림바 + 패드」 느낌으로 만든다. (사용자 2026-11-09 「소리 너무 구려요, 부드럽게」)
"""
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets/sounds"


def env(n, a=0.01, d=0.08, s=0.5, r=0.3, hold=0.0):
    """ADSR (초 단위) 길이 n 샘플"""
    t = np.arange(n) / SR
    total = n / SR
    e = np.zeros(n)
    a_n = int(a * SR)
    d_n = int(d * SR)
    r_n = int(r * SR)
    h_n = max(0, n - a_n - d_n - r_n)
    idx = 0
    if a_n:
        e[idx:idx + a_n] = np.linspace(0, 1, a_n)
        idx += a_n
    if d_n:
        e[idx:idx + d_n] = np.linspace(1, s, d_n)
        idx += d_n
    if h_n:
        e[idx:idx + h_n] = s
        idx += h_n
    rem = n - idx
    if rem > 0:
        e[idx:] = s * np.linspace(1, 0, rem) ** 1.5
    del t, total
    return e


def tone(freq, dur, kind="bell", vol=0.6, a=0.008, r=None):
    """한 음. bell: 기음 + 약한 배음 + 디튠 겹, pad: 삼각파 겹."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    r = r if r is not None else dur * 0.7
    if kind == "bell":
        x = np.sin(2 * np.pi * freq * t) * 1.0
        x += np.sin(2 * np.pi * freq * 2.0 * t) * 0.25 * np.exp(-t * 6)
        x += np.sin(2 * np.pi * freq * 3.0 * t) * 0.08 * np.exp(-t * 9)
        x += np.sin(2 * np.pi * freq * 1.003 * t) * 0.5  # 디튠 → 부드러운 울림
        e = env(n, a=a, d=0.05, s=0.6, r=r)
    elif kind == "pad":
        tri = lambda f: 2 / np.pi * np.arcsin(np.sin(2 * np.pi * f * t))
        x = tri(freq) + tri(freq * 1.004) * 0.7 + tri(freq * 0.5) * 0.5
        e = env(n, a=max(a, 0.05), d=0.1, s=0.8, r=r)
    else:  # soft: 순수 사인
        x = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 1.002 * t)
        e = env(n, a=a, d=0.04, s=0.7, r=r)
    x = x / np.max(np.abs(x) + 1e-9)
    return x * e * vol


def lowpass(x, cutoff=3200.0, order=2):
    b, a = butter(order, cutoff / (SR / 2))
    return lfilter(b, a, x)


def reverb(x, amount=0.18, delays=(0.031, 0.047, 0.071)):
    y = x.copy()
    for i, d in enumerate(delays):
        k = int(d * SR)
        g = amount * (0.7 ** i)
        pad = np.zeros_like(x)
        pad[k:] = x[:-k] * g
        y += pad
    return y


def mix(*parts):
    """(offset_sec, signal) 들을 겹친다"""
    length = max(int(o * SR) + len(s) for o, s in parts)
    y = np.zeros(length)
    for o, s in parts:
        k = int(o * SR)
        y[k:k + len(s)] += s
    return y


def finish(x, cutoff=3400.0, rev=0.16, gain=0.85):
    x = lowpass(x, cutoff)
    x = reverb(x, rev)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    # 끝을 짧게 페이드해서 클릭 방지
    f = int(0.01 * SR)
    x[-f:] *= np.linspace(1, 0, f)
    x[:f] *= np.linspace(0, 1, f)
    return x


def save(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    wavfile.write(OUT / f"{name}.wav", SR, (x * 32767).astype(np.int16))
    print(f"{name:10s} {len(x) / SR:.2f}s")


# 음 이름 → 주파수 (C5 = 523.25)
N = {"C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.0, "A4": 440.0, "B4": 493.88,
     "C5": 523.25, "D5": 587.33, "E5": 659.25, "F5": 698.46, "G5": 783.99, "A5": 880.0, "B5": 987.77,
     "C6": 1046.5, "E6": 1318.5, "G6": 1568.0, "C3": 130.81, "G3": 196.0, "A3": 220.0, "E3": 164.81}


def main():
    # 정답: 포근한 두 음 (E5→G5) + 낮은 패드
    save("correct", finish(mix(
        (0.0, tone(N["E5"], 0.5, vol=0.6)),
        (0.09, tone(N["G5"], 0.7, vol=0.55)),
        (0.0, tone(N["C4"], 0.7, kind="pad", vol=0.18)),
    )))
    # 오답: 날카롭지 않은 낮은 두 음 (E4→C4), 사인
    save("wrong", finish(mix(
        (0.0, tone(N["E4"], 0.35, kind="soft", vol=0.5, a=0.02)),
        (0.16, tone(N["C4"], 0.55, kind="soft", vol=0.5, a=0.02)),
    ), cutoff=1800, rev=0.12, gain=0.7))
    # 톡 (타일 누름): 아주 짧은 마림바
    save("tap", finish(tone(N["A5"], 0.12, vol=0.5, a=0.002, r=0.09), cutoff=4000, rev=0.05, gain=0.55))
    # 짝 맞춤 / 1단계 통과
    save("match", finish(mix((0.0, tone(N["C5"], 0.3, vol=0.5)), (0.07, tone(N["E5"], 0.4, vol=0.5))), gain=0.7))
    # 카드 뒤집기: 부드러운 쓸림 (노이즈 → 저역)
    n = int(0.22 * SR)
    noise = np.random.default_rng(3).standard_normal(n)
    e = env(n, a=0.03, d=0.05, s=0.5, r=0.12)
    save("flip", finish(lowpass(noise, 900) * e, cutoff=1200, rev=0.08, gain=0.35))
    # 초 세기 / 넘어가기 직전: 아주 작은 톡
    save("tick", finish(tone(N["E5"], 0.1, kind="soft", vol=0.35, a=0.003, r=0.08), cutoff=2600, rev=0.03, gain=0.4))
    # 빠른 정답
    save("fast", finish(mix((0.0, tone(N["G5"], 0.25, vol=0.5)), (0.06, tone(N["C6"], 0.45, vol=0.5))), gain=0.7))
    # 콤보 3·5·10: 올라가는 아르페지오, 길어진다
    save("combo1", finish(mix(
        (0.0, tone(N["C5"], 0.35, vol=0.5)), (0.08, tone(N["E5"], 0.35, vol=0.5)), (0.16, tone(N["G5"], 0.6, vol=0.5)),
        (0.0, tone(N["C4"], 0.7, kind="pad", vol=0.15)),
    )))
    save("combo2", finish(mix(
        (0.0, tone(N["C5"], 0.3, vol=0.5)), (0.07, tone(N["E5"], 0.3, vol=0.5)), (0.14, tone(N["G5"], 0.3, vol=0.5)),
        (0.21, tone(N["C6"], 0.7, vol=0.55)), (0.0, tone(N["F4"], 0.9, kind="pad", vol=0.16)),
    )))
    save("combo3", finish(mix(
        (0.0, tone(N["C5"], 0.28, vol=0.5)), (0.06, tone(N["E5"], 0.28, vol=0.5)), (0.12, tone(N["G5"], 0.28, vol=0.5)),
        (0.18, tone(N["C6"], 0.28, vol=0.5)), (0.24, tone(N["E6"], 0.3, vol=0.5)), (0.30, tone(N["G6"], 0.9, vol=0.55)),
        (0.0, tone(N["C4"], 1.2, kind="pad", vol=0.18)), (0.0, tone(N["G4"], 1.2, kind="pad", vol=0.12)),
    )))
    # 한 판 끝: 따뜻한 화음 (C-E-G-C) 패드 + 벨
    save("complete", finish(mix(
        (0.0, tone(N["C4"], 1.6, kind="pad", vol=0.25)), (0.0, tone(N["E4"], 1.6, kind="pad", vol=0.2)),
        (0.0, tone(N["G4"], 1.6, kind="pad", vol=0.2)),
        (0.1, tone(N["C5"], 0.8, vol=0.4)), (0.25, tone(N["E5"], 0.8, vol=0.4)), (0.4, tone(N["G5"], 1.0, vol=0.45)),
    ), rev=0.22))
    # 퍼펙트 팡파르: 짧은 멜로디 (G5 C6 E6 G6 → E6 G6)
    save("fanfare", finish(mix(
        (0.0, tone(N["C4"], 2.0, kind="pad", vol=0.22)), (0.0, tone(N["G4"], 2.0, kind="pad", vol=0.15)),
        (0.0, tone(N["G5"], 0.3, vol=0.5)), (0.12, tone(N["C6"], 0.3, vol=0.5)), (0.24, tone(N["E6"], 0.3, vol=0.5)),
        (0.36, tone(N["G6"], 0.5, vol=0.5)), (0.7, tone(N["E6"], 0.3, vol=0.45)), (0.85, tone(N["G6"], 1.1, vol=0.55)),
        (0.85, tone(N["C5"], 1.1, vol=0.3)),
    ), rev=0.24))
    # 시간 촉박: 부드러운 두 번 톡
    save("hurry", finish(mix((0.0, tone(N["A4"], 0.15, kind="soft", vol=0.45)), (0.2, tone(N["A4"], 0.2, kind="soft", vol=0.45))), cutoff=2400, gain=0.6))
    # 시간 초과: 내려가는 세 음
    save("miss", finish(mix(
        (0.0, tone(N["E4"], 0.25, kind="soft", vol=0.45, a=0.02)), (0.15, tone(N["D4"], 0.25, kind="soft", vol=0.45, a=0.02)),
        (0.3, tone(N["C4"], 0.5, kind="soft", vol=0.45, a=0.02)),
    ), cutoff=1800, gain=0.65))


if __name__ == "__main__":
    main()
