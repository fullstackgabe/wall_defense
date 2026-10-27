"""Gera a camada de frente do mapa (árvores + portão) a partir de backgrounds/map_bg.png.

Cada árvore e o portão viram um recorte separado num atlas (backgrounds/map_fg.png) e
uma entrada em backgrounds/map_fg.json com a posição e a base (y do pé). O map.gd cria um
Sprite2D por recorte com y-sort, então os personagens passam por trás das copas e por
dentro do túnel do portão em vez de por cima.

Uso (precisa do Pillow):  python3 tools/build_occluders.py
Rodar de novo sempre que o map_bg.png mudar.
"""
import json
import os
from collections import deque

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "backgrounds", "map_bg.png")
OUT_PNG = os.path.join(ROOT, "backgrounds", "map_fg.png")
OUT_JSON = os.path.join(ROOT, "backgrounds", "map_fg.json")

FOREST_YMAX = 100              # floresta acaba no topo da muralha
GATE_RECT = (180, 86, 220, 144)  # x0, y0, x1, y1 (exclusivo) da torre do portão
GATE_OPENING = (188, 110, 212, 143)  # área onde fica o vão do arco
MIN_TREE = 40                  # pedaços de copa menores que isso são grudados no vizinho
GROW = 3                       # contorno/tronco: até 3 px de distância da copa

GROUND = {(105, 109, 128), (111, 115, 128), (61, 65, 75), (52, 62, 82), (42, 51, 71), (62, 75, 96)}

im = Image.open(SRC).convert("RGBA")
px = im.load()
W, H = im.size


def dark(c):
    return sum(c) < 60


def brown(c):
    r, g, b = c
    return r > g > b and r - b > 35


def neighbors(p, ymax):
    x, y = p
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        n = (x + dx, y + dy)
        if 0 <= n[0] < W and 0 <= n[1] < ymax:
            yield n


def components(ok, ymax):
    lab, comps = {}, []
    for y in range(ymax):
        for x in range(W):
            p = (x, y)
            if p in lab or not ok(p):
                continue
            i = len(comps)
            comp, q = [p], deque([p])
            lab[p] = i
            while q:
                for n in neighbors(q.popleft(), ymax):
                    if n not in lab and ok(n):
                        lab[n] = i
                        comp.append(n)
                        q.append(n)
            comps.append(comp)
    return comps


# --- Estrada (manchas marrons grandes) e sua borda ---------------------------
road = set()
for comp in components(lambda p: brown(px[p][:3]), FOREST_YMAX):
    if len(comp) > 60:
        road.update(comp)
road_edge = {(x + dx, y + dy) for (x, y) in road for dx in range(-2, 3) for dy in range(-2, 3)}

# --- Copas: regiões claras separadas pelo contorno preto ---------------------
def canopy(p):
    c = px[p][:3]
    return p not in road_edge and c not in GROUND and not dark(c) and not brown(c)


trees = [c for c in components(canopy, FOREST_YMAX)
         if len(c) >= MIN_TREE and min(y for _, y in c) < 85]

# Contorno, tronco e pedacinhos: BFS a partir das copas por pixels que não são chão
# nem estrada, até GROW px.
owner = {}
q = deque()
for i, comp in enumerate(trees):
    for p in comp:
        owner[p] = i
        q.append((p, 0))
while q:
    p, d = q.popleft()
    if d >= GROW:
        continue
    for n in neighbors(p, FOREST_YMAX):
        if n in owner or n in road:
            continue
        c = px[n][:3]
        if c in GROUND:
            continue
        owner[n] = owner[p]
        q.append((n, d + 1))

groups = [[] for _ in trees]
for p, i in owner.items():
    groups[i].append(p)

# Tons escuros da copa coincidem com as sombras do chão e deixam buracos: em cada
# coluna, preenche entre o pixel mais alto e o mais baixo da árvore (menos o chão claro).
LIGHT_GROUND = {(105, 109, 128), (111, 115, 128)}
for i, g in enumerate(groups):
    have = set(g)
    cols = {}
    for x, y in g:
        lo, hi = cols.get(x, (y, y))
        cols[x] = (min(lo, y), max(hi, y))
    for x, (lo, hi) in cols.items():
        for y in range(lo, hi + 1):
            p = (x, y)
            if p not in have and p not in road and owner.get(p, i) == i \
                    and px[p][:3] not in LIGHT_GROUND:
                g.append(p)
                have.add(p)

# --- Portão: torre inteira menos o vão do arco -------------------------------
gx0, gy0, gx1, gy1 = GATE_RECT
ox0, oy0, ox1, oy1 = GATE_OPENING
opening = set()
q = deque([(200, 125)])
opening.add((200, 125))
while q:
    x, y = q.popleft()
    for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if ox0 <= n[0] < ox1 and oy0 <= n[1] < oy1 and n not in opening:
            c = px[n][:3]
            if sum(c) < 120 or brown(c):
                opening.add(n)
                q.append(n)
gate = [(x, y) for x in range(gx0, gx1) for y in range(gy0, gy1)
        if (x, y) not in opening and not brown(px[x, y][:3])]
groups.append(gate)

# --- Atlas (prateleiras) ------------------------------------------------------
entries = []
ATLAS_W = 512
cx = cy = shelf_h = 0
crops = []
for g in groups:
    xs = [x for x, _ in g]
    ys = [y for _, y in g]
    x0, y0, x1, y1 = min(xs), min(ys), max(xs) + 1, max(ys) + 1
    w, h = x1 - x0, y1 - y0
    crop = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cp = crop.load()
    for x, y in g:
        cp[x - x0, y - y0] = px[x, y]
    if cx + w > ATLAS_W:
        cx, cy, shelf_h = 0, cy + shelf_h + 1, 0
    crops.append((crop, cx, cy))
    entries.append({"atlas": [cx, cy, w, h], "pos": [x0, y0], "base": y1})
    cx += w + 1
    shelf_h = max(shelf_h, h)

atlas = Image.new("RGBA", (ATLAS_W, cy + shelf_h), (0, 0, 0, 0))
for crop, x, y in crops:
    atlas.paste(crop, (x, y))
atlas.save(OUT_PNG)
with open(OUT_JSON, "w") as f:
    json.dump({"source_size": [W, H], "pieces": entries}, f)
print(f"{len(trees)} árvores + portão -> {OUT_PNG} ({atlas.size[0]}x{atlas.size[1]})")
