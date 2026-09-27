"""Normaliza a folha original do cachorro para a grade do jogo (ADR 0013).

    python tools/arte/extrair_cachorro.py

Entrada: tools/arte/cachorro_original.webp (4 linhas x 4 quadros, fundo preto).
Diferente da folha do gato, esta foi reamostrada com escala fracionaria: nao ha
grade de pixel de arte para amostrar. Cada quadro e reduzido pela mesma escala
(ESCALA px de origem por pixel do jogo), com a cor tirada da mediana do miolo
de cada bloco e a paleta unificada no fim.

O contorno da arte e preto puro, igual ao fundo: por cor os dois sao
indistinguiveis. Por isso a silhueta vem da FORMA -- buracos pretos cercados
pelo corpo (olho, nariz, linhas internas) sao preenchidos e pintados de
CONTORNO -- e o contorno externo e redesenhado com 1 pixel em volta do corpo
(a sombra fica sem contorno, como no original).

A folha original tem costas, frente, lateral esquerda e lateral direita, sem
quadro de "sentado". A saida segue a grade comum a gato e cachorro
(tools/gerar_sprite_frames.gd):
  0 andar_baixo    <- frente (linha 2 da origem)
  1 andar_direita  <- lateral direita (linha 4 da origem)
  2 andar_cima     <- costas (linha 1 da origem)
  3 andar_esquerda <- lateral esquerda (linha 3 da origem)
  4 parado         <- primeiro quadro de frente, repetido (a folha nao tem
                      pose parada; repetir o quadro deixa o cachorro imovel)
Saida: recursos/arte/cachorro.png. Requer: pip install pillow numpy
"""
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np

RAIZ = Path(__file__).resolve().parents[2]
F = 24
ESCALA = 8.5
LIMIAR_FUNDO = 40
CONTORNO = (28, 20, 18, 255)
## Sombra: cinza escuro e sem saturacao. Nao recebe contorno.
SOMBRA_MAX_SOMA = 240
SOMBRA_MAX_SATURACAO = 18

im = np.array(Image.open(RAIZ / 'tools/arte/cachorro_original.webp').convert('RGB')).astype(float)
opaco = im.sum(2) > LIMIAR_FUNDO


def bandas(v, gap=12):
    idx = np.where(v)[0]; r = []; s = p = idx[0]
    for k in idx[1:]:
        if k - p > gap: r.append((s, p)); s = k
        p = k
    r.append((s, p))
    return [x for x in r if x[1] - x[0] > 20]   # descarta ruido de compressao


def preencher_buracos(mascara):
    """Preto cercado pelo corpo vira parte da silhueta (flood fill a partir da borda)."""
    alto, largo = mascara.shape
    img = Image.new('L', (largo + 2, alto + 2), 0)
    img.paste(Image.fromarray((mascara * 255).astype(np.uint8)), (1, 1))
    ImageDraw.floodfill(img, (0, 0), 128)
    return np.array(img)[1:-1, 1:-1] != 128


def e_sombra(cor):
    r, g, b = int(cor[0]), int(cor[1]), int(cor[2])
    return r + g + b <= SOMBRA_MAX_SOMA and max(r, g, b) - min(r, g, b) <= SOMBRA_MAX_SATURACAO


def reduzir(y0, y1, x0, x1):
    ys, xs = np.where(opaco[y0:y1 + 1, x0:x1 + 1])
    by0, by1, bx0, bx1 = ys.min() + y0, ys.max() + y0, xs.min() + x0, xs.max() + x0
    silhueta = preencher_buracos(opaco[by0:by1 + 1, bx0:bx1 + 1])
    h = int(np.ceil((by1 - by0 + 1) / ESCALA)); w = int(np.ceil((bx1 - bx0 + 1) / ESCALA))
    # +2: o contorno redesenhado ocupa um pixel de cada lado
    assert h + 2 <= F and w + 2 <= F, (w, h)
    q = np.zeros((F, F, 4), np.uint8)
    oy = F - h - 1; ox = (F - w) // 2        # pes (sombra) na base do quadro
    for j in range(h):
        for i in range(w):
            ya, yb = int(by0 + j * ESCALA), int(by0 + (j + 1) * ESCALA)
            xa, xb = int(bx0 + i * ESCALA), int(bx0 + (i + 1) * ESCALA)
            forma = silhueta[ya - by0:yb - by0, xa - bx0:xb - bx0]
            if forma.size == 0 or forma.mean() <= 0.5:
                continue
            bloco = opaco[ya:yb, xa:xb]
            if bloco.mean() < 0.45:
                # dentro da silhueta mas majoritariamente preto: e linha interna
                q[oy + j, ox + i] = CONTORNO
                continue
            miolo = im[ya + 1:yb - 1, xa + 1:xb - 1].reshape(-1, 3)
            miolo_opaco = opaco[ya + 1:yb - 1, xa + 1:xb - 1].reshape(-1)
            amostra = miolo[miolo_opaco] if miolo_opaco.any() else im[ya:yb, xa:xb].reshape(-1, 3)[bloco.reshape(-1)]
            q[oy + j, ox + i] = (*np.median(amostra, axis=0).astype(np.uint8), 255)
    return contornar(q)


def contornar(q):
    """1 pixel de contorno em volta do corpo; a sombra nao conta como corpo."""
    corpo = (q[:, :, 3] > 0) & ~np.array([[e_sombra(q[y, x]) for x in range(F)] for y in range(F)])
    saida = q.copy()
    for y in range(F):
        for x in range(F):
            if corpo[y, x] or (q[y, x, 3] > 0 and not e_sombra(q[y, x])):
                continue
            vizinhos = [(y + dy, x + dx) for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1))
                        if 0 <= y + dy < F and 0 <= x + dx < F]
            if any(corpo[v] for v in vizinhos):
                saida[y, x] = CONTORNO
    return saida


origem = []
for (y0, y1) in bandas(opaco.any(1)):
    colunas = bandas(opaco[y0:y1 + 1].any(0))
    assert len(colunas) == 4, colunas
    origem.append([reduzir(y0, y1, x0, x1) for (x0, x1) in colunas])
assert len(origem) == 4

grade = [
    origem[1],
    origem[3],
    origem[0],
    origem[2],
    [origem[1][0]] * 4,
]
folha = np.zeros((F * 5, F * 4, 4), np.uint8)
for r, linha in enumerate(grade):
    for c, q in enumerate(linha):
        folha[r * F:(r + 1) * F, c * F:(c + 1) * F] = q

rgb = np.array(Image.fromarray(folha[:, :, :3]).quantize(colors=16, method=Image.Quantize.MEDIANCUT).convert('RGB'))
e_contorno = np.all(folha == np.array(CONTORNO, np.uint8), axis=2)
rgb[e_contorno] = CONTORNO[:3]
out = np.dstack([rgb, folha[:, :, 3]])
out[out[:, :, 3] == 0, :3] = 0
Image.fromarray(out.astype(np.uint8), 'RGBA').save(RAIZ / 'recursos/arte/cachorro.png')
print('gravado recursos/arte/cachorro.png')
