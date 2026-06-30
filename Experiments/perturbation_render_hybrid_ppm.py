from decimal import Decimal, getcontext
from pathlib import Path

getcontext().prec = 80

W, H = 240, 160
center_x_dec = Decimal("-0.743643887037151")
center_y_dec = Decimal("0.131825904205330")
scale_dec = Decimal("1e-12")
max_iter = 4000
aspect_dec = Decimal(W) / Decimal(H)

out = Path("Experiments/perturbation_hybrid_test.ppm")

def reference_orbit_decimal(cx, cy, max_iter):
    orbit = []
    x = Decimal(0)
    y = Decimal(0)
    for i in range(max_iter):
        orbit.append((float(x), float(y)))
        x, y = x*x - y*y + cx, Decimal(2)*x*y + cy
        if x*x + y*y > Decimal(4):
            return orbit, i + 1
    return orbit, max_iter

def perturb_double(dx, dy, orbit, ref_escape, max_iter):
    zx = 0.0
    zy = 0.0
    limit = min(max_iter, len(orbit))

    for i in range(limit):
        rx, ry = orbit[i]

        nzx = 2.0 * (rx*zx - ry*zy) + (zx*zx - zy*zy) + dx
        nzy = 2.0 * (rx*zy + ry*zx) + 2.0*zx*zy + dy
        zx, zy = nzx, nzy

        fx = rx + zx
        fy = ry + zy

        if fx*fx + fy*fy > 4.0:
            return i + 1
        if i + 1 >= ref_escape:
            return ref_escape

    return max_iter

refs = []
for ox in [Decimal("-0.5"), Decimal("0"), Decimal("0.5")]:
    for oy in [Decimal("-0.5"), Decimal("0"), Decimal("0.5")]:
        rx_dec = center_x_dec + ox * scale_dec * aspect_dec
        ry_dec = center_y_dec + oy * scale_dec
        orbit, escaped = reference_orbit_decimal(rx_dec, ry_dec, max_iter)
        refs.append((float(rx_dec), float(ry_dec), orbit, escaped))

def choose_ref(x0, y0):
    return min(refs, key=lambda r: (x0-r[0])*(x0-r[0]) + (y0-r[1])*(y0-r[1]))

pixels = []

center_x = float(center_x_dec)
center_y = float(center_y_dec)
scale = float(scale_dec)
aspect = float(aspect_dec)

for py in range(H):
    if py % 20 == 0:
        print("row", py, "/", H)

    y0 = center_y + (py / max(H - 1, 1) - 0.5) * scale

    for px in range(W):
        x0 = center_x + (px / max(W - 1, 1) - 0.5) * scale * aspect

        rx, ry, orbit, escaped = choose_ref(x0, y0)
        it = perturb_double(x0-rx, y0-ry, orbit, escaped, max_iter)

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
