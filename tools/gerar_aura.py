"""Gera a aura branca do especial da Bravios (pixel-art, tira de 8 quadros).

Saída: objects/bola_basquete/aura_especial.png (8 quadros 128x160).
O centro do quadro é o centro do corpo da pantera; a aura sobe como chama
branca e é desenhada ATRÁS do sprite do personagem.

Uso: python tools/gerar_aura.py
"""
import os
import numpy as np
from PIL import Image

from gerar_fogo import value_noise

OUT = os.path.join(os.path.dirname(__file__), "..", "objects", "bola_basquete")
W, H, N = 128, 160, 8

# (limiar, cor): do contorno externo azulado ao núcleo branco.
PALETTE = [
    (0.08, (120, 170, 255, 90)),
    (0.20, (170, 210, 255, 170)),
    (0.36, (215, 236, 255, 225)),
    (0.55, (245, 250, 255, 255)),
    (0.78, (255, 255, 255, 255)),
]


def frame(i):
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    dx = (xs - W / 2) / 40.0           # semi-largura do corpo ~ 40 px de arte
    dy = (ys - H / 2 - 4) / 58.0       # semi-altura ~ 58 px de arte
    # Chama mais larga embaixo e afinando para cima.
    dist = np.sqrt((dx * (1 + 0.25 * np.clip(-dy, -1, 1))) ** 2 + dy ** 2)
    body = np.clip(1.25 - dist, 0, 1)

    # Línguas subindo: ruído periódico em y, rolando para cima (loop perfeito).
    period = 8
    cell = 16.0
    scroll = (i / N) * period * cell
    n1 = value_noise(H, W, cell, 7.0, -scroll, 0, period, seed=21).T
    n2 = value_noise(H, W, cell * 0.5, 4.0, -scroll * 2, 0, period * 2, seed=22).T
    noise = 0.65 * n1 + 0.35 * n2
    up = np.clip(-dy, 0, 1.2)          # mais ruído no topo: pontas de chama
    inten = body * (1.0 + 0.1 * up) + (noise - 0.5) * (0.25 + 0.7 * up) * np.sqrt(body)
    inten = np.where(dy > 1.3, 0, inten)

    img = np.zeros((H, W, 4), np.uint8)
    for th, col in PALETTE:
        img[inten > th] = col

    # Faíscas brancas subindo.
    rng = np.random.default_rng(5)
    for k in range(16):
        x = rng.integers(14, W - 14)
        y0 = rng.uniform(0, H)
        y = int((y0 - (i / N) * H) % H)
        sz = 2 if rng.random() > 0.5 else 1
        if img[y, x, 3] == 0 and y < H - 2:
            img[y:y + sz, x:x + sz] = (255, 255, 255, 230)
    return img


if __name__ == "__main__":
    sheet = np.zeros((H, W * N, 4), np.uint8)
    for k in range(N):
        sheet[:, k * W:(k + 1) * W] = frame(k)
    path = os.path.join(OUT, "aura_especial.png")
    Image.fromarray(sheet).save(path)
    print("salvo", os.path.normpath(path), sheet.shape)
