"""Padroniza cor e textura dos sprites de cada personagem.

Para cada personagem:
 1. LÃª os PNGs ORIGINAIS da pasta de backup (nunca os jÃ¡ alterados), entÃ£o
    pode rodar de novo sem acumular mudanÃ§as.
 2. Acerta a cor (mÃ©dia e contraste em Lab) de cada frame para a dos frames de
    referÃªncia do mesmo personagem. Pixels cinza/pretos (corpo) e coloridos
    (laranja, vermelho) sÃ£o tratados separadamente; os coloridos sÃ³ sÃ£o
    acertados quando COLORFUL_MATCH Ã© True (no Bravios eles sÃ£o a bola e as
    ataduras, que nÃ£o devem mudar).
 3. Reduz todos os frames a UMA paleta do personagem (k-means em Lab), o que
    dÃ¡ a mesma "textura" chapada de pixel-art em todos. O alfa nÃ£o muda.

Uso: python tools/padronizar_sprites.py <pasta_backup> [personagem ...]
"""
import sys, glob, os
import numpy as np
import cv2
from PIL import Image

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CONFIG = {
    "bravios": dict(reference_skip=["special"], colorful_match=False, colors=96),
    "crocks": dict(reference_skip=["die", "combo", "sneak-attack", "special", "hurt"], colorful_match=True, colors=64),
}
CHROMA_NEUTRAL = 14.0   # abaixo disso o pixel conta como cinza/preto


def to_lab(rgb):
    return cv2.cvtColor((rgb.astype(np.float32) / 255.0).reshape(-1, 1, 3), cv2.COLOR_RGB2LAB).reshape(-1, 3)


def to_rgb(lab):
    out = cv2.cvtColor(lab.astype(np.float32).reshape(-1, 1, 3), cv2.COLOR_LAB2RGB).reshape(-1, 3)
    return np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8)


def load(path):
    im = np.array(Image.open(path).convert("RGBA"))
    mask = im[:, :, 3] > 0  # todo pixel visível (inclusive borda suave) é recolorido
    return im, mask


def class_masks(lab):
    chroma = np.hypot(lab[:, 1], lab[:, 2])
    return chroma < CHROMA_NEUTRAL, chroma >= CHROMA_NEUTRAL


def stats(lab):
    return lab.mean(0), lab.std(0) + 1e-3


def main():
    backup = sys.argv[1]
    only = sys.argv[2:] or list(CONFIG)
    for name in only:
        cfg = CONFIG[name]
        files = sorted([f for f in glob.glob(os.path.join(backup, name, "*", "*.png")) if os.path.basename(os.path.dirname(f)) != "main"])
        frames = []
        for f in files:
            im, mask = load(f)
            core = (im[:, :, 3] > 200)[mask]  # as estatísticas usam só os pixels opacos
            frames.append(dict(file=f, anim=os.path.basename(os.path.dirname(f)), im=im, mask=mask,
                               core=core, lab=to_lab(im[mask][:, :3])))
        # EstatÃ­sticas de referÃªncia por classe (pixels de todos os frames de referÃªncia).
        ref = [fr for fr in frames if fr["anim"] not in cfg["reference_skip"]]
        pooled = np.concatenate([fr["lab"][fr["core"]] for fr in ref])
        n_ref, c_ref = class_masks(pooled)
        ref_stats = {"neutral": stats(pooled[n_ref]), "color": stats(pooled[c_ref])}

        for fr in frames:
            lab = fr["lab"].copy()
            n, c = class_masks(lab)
            for key, sel in (("neutral", n), ("color", c)):
                if key == "color" and not cfg["colorful_match"]:
                    continue
                core_sel = sel & fr["core"]
                if core_sel.sum() < 50:
                    continue
                m, s = stats(lab[core_sel])
                rm, rs = ref_stats[key]
                gain = np.clip(rs / s, 0.6, 1.6)
                lab[sel] = (lab[sel] - m) * gain + rm
            fr["matched"] = lab

        # Paleta Ãºnica do personagem.
        pool = np.concatenate([fr["matched"] for fr in frames])
        rng = np.random.default_rng(1)
        sample = pool[rng.choice(len(pool), size=min(len(pool), 300000), replace=False)].astype(np.float32)
        crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 40, 0.5)
        _, _, centers = cv2.kmeans(sample, cfg["colors"], None, crit, 3, cv2.KMEANS_PP_CENTERS)

        for fr in frames:
            lab = fr["matched"]
            idx = np.empty(len(lab), dtype=np.int32)
            for i in range(0, len(lab), 50000):
                d = ((lab[i:i + 50000, None, :] - centers[None, :, :]) ** 2).sum(2)
                idx[i:i + 50000] = d.argmin(1)
            rgb = to_rgb(centers[idx])
            out = fr["im"].copy()
            out_rgb = out[:, :, :3]
            out_rgb[fr["mask"]] = rgb
            dest = os.path.join(PROJECT, "characters", name, fr["anim"], os.path.basename(fr["file"]))
            Image.fromarray(out).save(dest)
            print(name, fr["anim"], os.path.basename(fr["file"]))


if __name__ == "__main__":
    main()
