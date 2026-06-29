from decimal import Decimal, getcontext

getcontext().prec = 80

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

center_x = Decimal("-0.743643887037151")
center_y = Decimal("0.131825904205330")
scales = [Decimal("1e-12"), Decimal("1e-15"), Decimal("1e-18"), Decimal("1e-24")]
max_iter = 10000

samples = [
    (Decimal("0"), Decimal("0")),
    (Decimal("-0.25"), Decimal("-0.25")),
    (Decimal("0.25"), Decimal("-0.25")),
    (Decimal("-0.25"), Decimal("0.25")),
    (Decimal("0.25"), Decimal("0.25")),
    (Decimal("0.45"), Decimal("0.1")),
    (Decimal("-0.45"), Decimal("-0.1")),
]

for scale in scales:
    refs = []
    for ox in [Decimal("-0.5"), Decimal("0"), Decimal("0.5")]:
        for oy in [Decimal("-0.5"), Decimal("0"), Decimal("0.5")]:
            rx = center_x + ox * scale
            ry = center_y + oy * scale
            orbit, escaped = reference_orbit(rx, ry, max_iter)
            refs.append((rx, ry, orbit, escaped))

    print("\nScale", scale)
    failures = 0

    for sx, sy in samples:
        x0 = center_x + sx * scale
        y0 = center_y + sy * scale
        c = classic(x0, y0, max_iter)

        best = None
        for rx, ry, orbit, escaped in refs:
            p = perturb(x0 - rx, y0 - ry, orbit, escaped, max_iter)
            d = abs(c - p)
            if best is None or d < best[0]:
                best = (d, p)

        print("sample", (sx, sy), "classic", c, "perturb", best[1], "delta", best[0])
        if best[0] > 2:
            failures += 1

    print("✅ passed" if failures == 0 else f"❌ failed: {failures}")
