"""Gera os sprites de fogo da bola do especial da Bravios (pixel-art).

Saída (em objects/bola_basquete/):
  fogo_rastro.png    - 8 quadros 144x96 em tira horizontal. A bola fica em
                       (104, 48) com raio ~26 px; as chamas vão para a ESQUERDA
                       (a bola viaja para a direita).
  fogo_explosao.png  - 8 quadros 128x128 da explosão no impacto.

Uso: python tools/gerar_fogo.py
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "objects", "bola_basquete")

# Paleta de fogo (do mais frio/externo para o mais quente/interno).
PALETTE = [
    (0.10, (96, 18, 20, 150)),
    (0.22, (170, 30, 18, 230)),
    (0.36, (226, 72, 20, 255)),
    (0.52, (250, 140, 30, 255)),
    (0.68, (255, 202, 64, 255)),
    (0.84, (255, 240, 150, 255)),
]


def value_noise(w, h, cell_x, cell_y, shift_x, shift_y, period_x, seed):
    """Value noise suave; periódico em x com `period_x` células (loop)."""
    rng = np.random.default_rng(seed)
    gx = period_x
    gy = int(h / cell_y) + 4
    lattice = rng.random((gy, gx))
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    fx = (xs + shift_x) / cell_x
    fy = (ys + shift_y) / cell_y
    x0 = np.floor(fx).astype(int)
    y0 = np.floor(fy).astype(int)
    tx = fx - x0
    ty = fy - y0
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)
    x0m, x1m = x0 % gx, (x0 + 1) % gx
    y0m, y1m = y0 % gy, (y0 + 1) % gy
    a = lattice[y0m, x0m]
    b = lattice[y0m, x1m]
    c = lattice[y1m, x0m]
    d = lattice[y1m, x1m]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def colorize(v, dither=True):
    """Converte intensidade 0..1 em pixels de paleta (com borda pixelada)."""
    h, w = v.shape
    img = np.zeros((h, w, 4), np.uint8)
    for th, col in PALETTE:
        img[v > th] = col
    return img


def rastro_frame(i, n, w=144, h=96):
    cx, cy = 104.0, 48.0
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    behind = cx - xs                      # distância atrás do centro da bola
    u = np.clip(behind / 100.0, -0.4, 1.2)  # 0 na bola, 1 na ponta
    dy = ys - cy
    # Largura da chama: abraça a bola e afina até a ponta.
    half = np.where(behind > 0, 34.0 * np.clip(1 - u, 0, 1) ** 0.75 + 4.0, 0.0)
    cap = 34.0 * np.sqrt(np.clip(1 - (np.maximum(-behind, 0) / 24.0) ** 2, 0, None))
    half = np.where(behind <= 0, cap, half)
    v = np.abs(dy) / np.maximum(half, 1e-3)
    body = np.clip(1 - v ** 1.6, 0, 1)

    # Línguas de fogo: ruído esticado ao longo do fluxo, rolando para a esquerda.
    period = 8
    cell_x = 18.0
    scroll = (i / n) * period * cell_x       # um ciclo completo = loop perfeito
    n1 = value_noise(w, h, cell_x, 9.0, scroll, 0, period, seed=3)
    n2 = value_noise(w, h, cell_x * 0.5, 5.0, scroll * 2 + 7, i * 0, period * 2, seed=9)
    noise = 0.65 * n1 + 0.35 * n2
    tail = np.clip(u, 0, 1)
    intensity = body * (1.0 - 0.95 * tail) + (noise - 0.5) * (0.35 + 0.9 * tail) * body ** 0.5
    # Núcleo quente perto da bola.
    intensity += np.clip(1 - (np.hypot(np.maximum(behind, 0) * 0.8, dy) / 30.0), 0, 1) * 0.35
    intensity = np.where(behind < -24, 0, intensity)
    return colorize(intensity)


def explosao_frame(i, n, s=128):
    c = s / 2
    ys, xs = np.mgrid[0:s, 0:s].astype(np.float32)
    r = np.hypot(xs - c, ys - c)
    t = i / (n - 1)
    radius = 14 + 46 * np.sqrt(t)
    ang = np.arctan2(ys - c, xs - c)
    # Bordas irregulares (picos de chama) que mudam por quadro.
    rng = np.random.default_rng(100 + i)
    spikes = np.zeros_like(ang)
    for k in range(3, 9):
        spikes += rng.uniform(0.5, 1.0) / k * np.sin(k * ang + rng.uniform(0, 6.28))
    edge = radius * (1 + 0.5 * spikes)
    base = np.clip(1 - r / np.maximum(edge, 1), 0, 1)
    noise = value_noise(s, s, 10.0, 10.0, i * 13, i * 7, 13, seed=5)
    inten = base * (1.25 - 0.9 * t) + (noise - 0.5) * 0.5 * base ** 0.4
    inten *= (1 - 0.15 * t)
    img = colorize(inten)
    # Faíscas: pixels brilhantes voando para fora.
    sp = np.random.default_rng(7)
    for k in range(14):
        a = sp.uniform(0, 6.2832)
        d = (8 + sp.uniform(30, 58) * np.sqrt(t))
        px = int(c + np.cos(a) * d)
        py = int(c + np.sin(a) * d + 6 * t * t * 20)
        sz = 2 if sp.random() > 0.4 else 1
        if t < 0.95 and 0 <= px < s - 2 and 0 <= py < s - 2:
            img[py:py + sz, px:px + sz] = (255, 236, 140, 255)
    return img


def strip(frames, path):
    h, w = frames[0].shape[:2]
    sheet = np.zeros((h, w * len(frames), 4), np.uint8)
    for k, f in enumerate(frames):
        sheet[:, k * w:(k + 1) * w] = f
    Image.fromarray(sheet).save(path)
    print("salvo", os.path.normpath(path), sheet.shape)


if __name__ == "__main__":
    n = 8
    strip([rastro_frame(i, n) for i in range(n)], os.path.join(OUT, "fogo_rastro.png"))
    strip([explosao_frame(i, n) for i in range(n)], os.path.join(OUT, "fogo_explosao.png"))
