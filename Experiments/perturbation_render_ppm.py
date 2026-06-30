from decimal import Decimal, getcontext
from pathlib import Path

getcontext().prec = 80

W, H = 80, 54
center_x = Decimal("-0.743643887037151")
center_y = Decimal("0.131825904205330")
scale = Decimal("1e-12")
max_iter = 4000
aspect = Decimal(W) / Decimal(H)

out = Path("Experiments/perturbation_test.ppm")

def classic(cx, cy, max_iter):
    x = Decimal(0)
    y = Decimal(0)
    for i in range(max_iter):
        if x*x + y*y > Decimal(4):
            return i
        x, y = x*x - y*y + cx, Decimal(2)*x*y + cy
    return max_iter

def reference_orbit(cx, cy, max_iter):
    orbit = []
    x = Decimal(0)
    y = Decimal(0)
    for i in range(max_iter):
        orbit.append((x, y))
        x, y = x*x - y*y + cx, Decimal(2)*x*y + cy
        if x*x + y*y > Decimal(4):
            return orbit, i + 1
    return orbit, max_iter

def perturb(dx, dy, orbit, ref_escape, max_iter):
    zx = Decimal(0)
    zy = Decimal(0)
    for i, (rx, ry) in enumerate(orbit[:max_iter]):
        nzx = Decimal(2)*(rx*zx - ry*zy) + (zx*zx - zy*zy) + dx
        nzy = Decimal(2)*(rx*zy + ry*zx) + Decimal(2)*zx*zy + dy
        zx, zy = nzx, nzy

        fx = rx + zx
        fy = ry + zy

        if fx*fx + fy*fy > Decimal(4):
            return i + 1
        if i + 1 >= ref_escape:
            return ref_escape
    return max_iter

refs = []
for ox in [Decimal("-0.5"), Decimal("0"), Decimal("0.5")]:
    for oy in [Decimal("-0.5"), Decimal("0"), Decimal("0.5")]:
        rx = center_x + ox * scale * aspect
        ry = center_y + oy * scale
        orbit, escaped = reference_orbit(rx, ry, max_iter)
        refs.append((rx, ry, orbit, escaped))

def choose_ref(x0, y0):
    return min(refs, key=lambda r: (x0-r[0])*(x0-r[0]) + (y0-r[1])*(y0-r[1]))

pixels = []

for py in range(H):
    if py % 20 == 0:
        print("row", py, "/", H)

    y0 = center_y + (Decimal(py) / Decimal(H - 1) - Decimal("0.5")) * scale

    for px in range(W):
        x0 = center_x + (Decimal(px) / Decimal(W - 1) - Decimal("0.5")) * scale * aspect

        rx, ry, orbit, escaped = choose_ref(x0, y0)
        it = perturb(x0-rx, y0-ry, orbit, escaped, max_iter)

        if it >= max_iter:
            pixels.append((0, 0, 0))
        else:
            t = it / max_iter
            r = int(255 * min(1.0, 2.2 * t))
            g = int(255 * min(1.0, 6.0 * t * (1.0 - t)))
            b = int(255 * min(1.0, 1.7 * (1.0 - t)))
            pixels.append((r, g, b))

with out.open("w") as f:
    f.write(f"P3\n{W} {H}\n255\n")
    for r, g, b in pixels:
        f.write(f"{r} {g} {b}\n")

print("wrote", out)
