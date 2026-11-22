"""Dibuja las formas de onda de un VCD (alternativa a una captura de GTKWave).
Uso: python3 vcd_a_png.py perip_spi_tb.vcd salida.png t_ini_ns t_fin_ns
"""
import sys, re
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

vcd, out = sys.argv[1], sys.argv[2]
t0, t1 = float(sys.argv[3]), float(sys.argv[4])
titulo = sys.argv[5] if len(sys.argv) > 5 else "perip_spi_tb"

WANT = [  # (ruta, etiqueta)
    ("perip_spi_tb.clk", "clk"),
    ("perip_spi_tb.dut.start", "start"),
    ("perip_spi_tb.dut.u_control.state", "estado"),
    ("perip_spi_tb.dut.u_control.fase", "fase"),
    ("perip_spi_tb.dut.u_datapath.tick", "tick"),
    ("perip_spi_tb.spi_cs_n", "spi_cs_n"),
    ("perip_spi_tb.spi_sck", "spi_sck"),
    ("perip_spi_tb.spi_mosi", "spi_mosi"),
    ("perip_spi_tb.spi_miso", "spi_miso"),
    ("perip_spi_tb.dut.u_datapath.bits", "bits"),
    ("perip_spi_tb.dut.u_datapath.rx", "rx"),
    ("perip_spi_tb.dut.done_core", "done"),
    ("perip_spi_tb.dut.r_done", "STATUS.DONE"),
]
ESTADOS = ["IDLE", "CS_SETUP", "LOAD", "LOW", "HIGH", "FIN", "CS_HOLD", "CS_REST", "DONE"]
FASES = ["CMD", "DIR", "DAT", "?"]

ids, width, scope = {}, {}, []
data = {}
tscale = 1.0
with open(vcd) as f:
    txt = f.read()
m = re.search(r"\$timescale\s+(\d+)\s*(\w+)", txt)
if m:
    tscale = int(m.group(1)) * {"s": 1e9, "ms": 1e6, "us": 1e3, "ns": 1, "ps": 1e-3}[m.group(2)]
head, body = txt.split("$enddefinitions", 1)
for tok in re.finditer(r"\$scope\s+\w+\s+(\S+)\s+\$end|\$upscope\s+\$end|\$var\s+\w+\s+(\d+)\s+(\S+)\s+(\S+)", head):
    if tok.group(1):
        scope.append(tok.group(1))
    elif tok.group(0).startswith("$upscope"):
        scope.pop()
    else:
        path = ".".join(scope + [tok.group(4)])
        ids.setdefault(tok.group(3), []).append(path)
        width[path] = int(tok.group(2))
want_paths = {p for p, _ in WANT}
for p in want_paths:
    data[p] = []
t = 0.0
for line in body.splitlines():
    line = line.strip()
    if not line:
        continue
    if line[0] == "#":
        t = int(line[1:]) * tscale
        continue
    if line[0] in "01xz":
        val, code = line[0], line[1:]
    elif line[0] == "b":
        val, code = line[1:].split()
    else:
        continue
    for p in ids.get(code, []):
        if p in want_paths:
            data[p].append((t, val))

def value_at(series, tt):
    v = None
    for ts, vv in series:
        if ts <= tt: v = vv
        else: break
    return v

def to_int(v):
    try: return int(v, 2)
    except Exception: return None

fig, axes = plt.subplots(len(WANT), 1, figsize=(18, 0.62 * len(WANT) + 1), sharex=True)
for ax, (p, label) in zip(axes, WANT):
    s = data[p]
    pts = [(t0, value_at(s, t0))] + [(ts, v) for ts, v in s if t0 < ts <= t1] + [(t1, None)]
    ax.set_yticks([]); ax.set_ylabel(label, rotation=0, ha="right", va="center", fontsize=9)
    for sp in ("top", "right", "left"): ax.spines[sp].set_visible(False)
    if width.get(p, 1) == 1:
        xs, ys = [], []
        for (ta, va), (tb, _) in zip(pts[:-1], pts[1:]):
            y = 1 if va == "1" else 0
            xs += [ta, tb]; ys += [y, y]
        ax.plot(xs, ys, color="#1f5fa8", lw=1.2, drawstyle="default")
        ax.set_ylim(-0.3, 1.3)
    else:
        for (ta, va), (tb, _) in zip(pts[:-1], pts[1:]):
            n = to_int(va) if va else None
            if label == "estado" and n is not None: txt = ESTADOS[n] if n < len(ESTADOS) else str(n)
            elif label == "fase" and n is not None: txt = FASES[n]
            elif label == "rx" and n is not None: txt = f"{n:06X}"
            elif n is not None: txt = str(n)
            else: txt = "x"
            ax.fill_between([ta, tb], 0.1, 0.9, color="#e8f1e4", edgecolor="#5a8a4a", lw=0.8)
            if tb - ta > (t1 - t0) / 60:
                ax.text((ta + tb) / 2, 0.5, txt, ha="center", va="center", fontsize=7)
        ax.set_ylim(0, 1)
axes[-1].set_xlabel("tiempo (ns)")
fig.suptitle(titulo, fontsize=12)
fig.tight_layout()
fig.savefig(out, dpi=110)
print("ok", out)
