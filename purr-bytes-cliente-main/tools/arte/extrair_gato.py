"""Normaliza a folha original do gato para a grade do jogo (ADR 0013).

    python tools/arte/extrair_gato.py

Entrada: tools/arte/gato_original.webp (5 linhas x 4 quadros, ampliada 10x, fundo
preto). Saida: recursos/arte/gato.png (quadros de 24x24). Depois rode
tools/gerar_sprite_frames.gd no Godot para atualizar o SpriteFrames.
Requer: pip install pillow numpy
"""
from pathlib import Path
from PIL import Image
import numpy as np

RAIZ = Path(__file__).resolve().parents[2]
im = np.array(Image.open(RAIZ / 'tools/arte/gato_original.webp').convert('RGB')).astype(int)
H, W, _ = im.shape
P = 10
# centro de cada pixel de arte (fronteiras em x~0.5, y~1.5 medidas por autocorrelacao)
xs = np.arange(1, W - 4, P); ys = np.arange(2, H - 4, P)
arte = np.zeros((len(ys), len(xs), 3), int)
for j, y in enumerate(ys):
    for i, x in enumerate(xs):
        bloco = im[y+2:y+8, x+2:x+8].reshape(-1, 3)
        arte[j, i] = np.median(bloco, axis=0)
opaco = arte.sum(2) > 45
# bandas de linhas/colunas com conteudo
def bandas(v, gap=3):
    idx = np.where(v)[0]; r = []; s = p = idx[0]
    for k in idx[1:]:
        if k - p > gap: r.append((s, p)); s = k
        p = k
    r.append((s, p)); return r
lin = bandas(opaco.any(1)); col = bandas(opaco.any(0))
assert len(lin) == 5 and len(col) == 4, (lin, col)
F = 24
folha = np.zeros((F*5, F*4, 4), np.uint8)
for r, (y0, y1) in enumerate(lin):
    for c, (x0, x1) in enumerate(col):
        sub = opaco[y0:y1+1, x0:x1+1]
        ys_, xs_ = np.where(sub)
        by0, by1 = ys_.min()+y0, ys_.max()+y0; bx0, bx1 = xs_.min()+x0, xs_.max()+x0
        h, w = by1-by0+1, bx1-bx0+1
        assert h <= F and w <= F, (r, c, h, w)
        oy = F - h - 1           # pes (sombra) alinhados a base do quadro
        ox = (F - w) // 2
        for yy in range(h):
            for xx in range(w):
                if opaco[by0+yy, bx0+xx]:
                    folha[r*F+oy+yy, c*F+ox+xx, :3] = arte[by0+yy, bx0+xx]
                    folha[r*F+oy+yy, c*F+ox+xx, 3] = 255
img = Image.fromarray(folha, 'RGBA')
# paleta enxuta: tira o ruido de compressao sem perder o desenho
rgb = img.convert('RGB').quantize(colors=14, method=Image.Quantize.MEDIANCUT).convert('RGB')
out = np.dstack([np.array(rgb), folha[:, :, 3]])
out[out[:, :, 3] == 0, :3] = 0
Image.fromarray(out.astype(np.uint8), 'RGBA').save(RAIZ / 'recursos/arte/gato.png')
print('gravado recursos/arte/gato.png')
