#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct Uniforms {
    float centerX;
    float centerY;
    float scale;
    uint maxIterations;
    float aspectRatio;
    uint fractalMode;
    uint fractalPalette;
};

vertex VertexOut fullscreen_vertex(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    
    float2 pos = positions[vertexID];
    
    VertexOut out;
    out.position = float4(pos, 0.0, 1.0);
    out.uv = pos * 0.5 + 0.5;
    
    return out;
}

static uint fractalIteration(
    uint mode,
    float x0,
    float y0,
    uint maxIterations
) {
    float x;
    float y;
    float cx;
    float cy;
    
    if (mode == 0 || mode == 6) {
        x = 0.0;
        y = 0.0;
        cx = x0;
        cy = y0;
    } else if (mode == 1) {
        x = x0;
        y = y0;
        cx = -0.8;
        cy = 0.156;
    } else if (mode == 2) {
        x = 0.0;
        y = 0.0;
        cx = x0;
        cy = y0;
    } else if (mode == 3) {
        x = 0.0;
        y = 0.0;
        cx = x0;
        cy = y0;
    } else if (mode == 4) {
        x = x0;
        y = y0;
        cx = 0.0;
        cy = 0.0;
    } else {
        x = 0.0;
        y = 0.0;
        cx = x0;
        cy = y0;
    }
    
    uint iteration = 0;
    
    while ((x * x + y * y <= 4.0) && iteration < maxIterations) {
        if (mode == 0 || mode == 1 || mode == 6) {
            float xtemp = x * x - y * y + cx;
            y = 2.0 * x * y + cy;
            x = xtemp;
        } else if (mode == 2) {
            float ax = abs(x);
            float ay = abs(y);
            float xtemp = ax * ax - ay * ay + cx;
            y = 2.0 * ax * ay + cy;
            x = xtemp;
        } else if (mode == 3) {
            float xtemp = x * x - y * y + cx;
            y = -2.0 * x * y + cy;
            x = xtemp;
        } else if (mode == 4) {
            float r2 = x * x + y * y + 0.000001;
            
            x = x / r2;
            y = y / r2;
            
            x = abs(x);
            y = abs(y);
            
            x = x - 1.0;
            y = y - 0.5;
            
            float angle = 0.45;
            float cosA = cos(angle);
            float sinA = sin(angle);
            
            float rx = x * cosA - y * sinA;
            float ry = x * sinA + y * cosA;
            
            x = rx;
            y = ry;
        } else {
            float xtemp = x * x - y * y + cx;
            y = 2.0 * x * y + cy;
            x = xtemp;
        }
        
        iteration += 1;
    }
    
    return iteration;
}

static float3 paletteColor(
    float relief,
    float ridge,
    float glow,
    uint palette
) {
    float3 color;
    
    if (palette == 0) {
        color = float3(
            0.02 + 0.18 * relief + 0.18 * glow + 0.10 * ridge,
            0.08 + 0.65 * relief + 0.28 * glow + 0.12 * ridge,
            0.22 + 1.05 * relief + 0.30 * glow
        );
    } else if (palette == 1) {
        color = float3(
            0.01 + 0.08 * relief + 0.16 * glow,
            0.10 + 0.95 * relief + 0.40 * glow + 0.10 * ridge,
            0.28 + 1.20 * relief + 0.25 * ridge
        );
    } else if (palette == 2) {
        color = float3(
            0.20 + 1.20 * relief + 0.35 * glow,
            0.04 + 0.45 * relief + 0.28 * glow + 0.18 * ridge,
            0.01 + 0.08 * relief + 0.05 * glow
        );
    } else if (palette == 3) {
        color = float3(
            0.16 + 0.62 * relief + 0.20 * glow,
            0.32 + 0.95 * relief + 0.25 * ridge,
            0.55 + 1.10 * relief + 0.20 * glow
        );
    } else if (palette == 4) {
        color = float3(
            0.22 + 1.00 * relief + 0.35 * glow,
            0.12 + 0.62 * relief + 0.20 * ridge,
            0.02 + 0.18 * relief + 0.06 * glow
        );
    } else if (palette == 5) {
        color = float3(
            0.12 + 0.75 * relief + 0.25 * glow,
            0.02 + 0.18 * relief + 0.08 * ridge,
            0.24 + 1.05 * relief + 0.35 * glow
        );
    } else {
        float yellowSpark = pow(glow, 1.35);
        float cyanEdge = pow(relief, 0.55);
        
        color = float3(
            0.00 + 0.05 * cyanEdge + 0.80 * yellowSpark + 0.10 * ridge,
            0.04 + 0.70 * cyanEdge + 0.95 * yellowSpark + 0.20 * ridge,
            0.18 + 1.05 * cyanEdge + 0.18 * yellowSpark + 0.18 * ridge
        );
    }
    
    return clamp(color, 0.0, 1.0);
}

static float3 insideColor(uint mode, uint palette) {
    if (mode == 0 || mode == 6) {
        return float3(0.0, 0.0, 0.0);
    }
    
    if (mode == 4) {
        if (palette == 0) {
            return float3(0.02, 0.04, 0.11);
        } else if (palette == 1) {
            return float3(0.00, 0.03, 0.12);
        } else if (palette == 2) {
            return float3(0.08, 0.01, 0.00);
        } else if (palette == 3) {
            return float3(0.04, 0.08, 0.12);
        } else if (palette == 4) {
            return float3(0.08, 0.04, 0.00);
        } else if (palette == 5) {
            return float3(0.05, 0.00, 0.10);
        } else {
            return float3(0.00, 0.01, 0.08);
        }
    }
    
    return float3(0.0, 0.0, 0.0);
}

static uint mandelbrotIterationOnly(
    float x0,
    float y0,
    uint maxIterations
) {
    float x = 0.0;
    float y = 0.0;
    uint iteration = 0;
    
    while ((x * x + y * y <= 4.0) && iteration < maxIterations) {
        float xtemp = x * x - y * y + x0;
        y = 2.0 * x * y + y0;
        x = xtemp;
        iteration += 1;
    }
    
    return iteration;
}

static float reliefHeight(
    float x0,
    float y0,
    uint maxIterations
) {
    uint iteration = mandelbrotIterationOnly(x0, y0, maxIterations);
    
    if (iteration == maxIterations) {
        return 1.0;
    }
    
    float t = float(iteration) / float(maxIterations);
    return pow(t, 0.35);
}

static float4 renderMandelbrotRelief(
    float2 uv,
    constant Uniforms& uniforms
) {
    float x0 = uniforms.centerX + (uv.x - 0.5) * uniforms.scale * uniforms.aspectRatio;
    float y0 = uniforms.centerY + (0.5 - uv.y) * uniforms.scale;
    
    uint centerIteration = mandelbrotIterationOnly(
        x0,
        y0,
        uniforms.maxIterations
    );
    
    if (centerIteration == uniforms.maxIterations) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }
    
    float pixelStep = uniforms.scale / 900.0;
    
    float h  = reliefHeight(x0, y0, uniforms.maxIterations);
    float hx = reliefHeight(x0 + pixelStep, y0, uniforms.maxIterations);
    float hy = reliefHeight(x0, y0 + pixelStep, uniforms.maxIterations);
    
    float3 normal = normalize(float3(
        (h - hx) * 3.5,
        (h - hy) * 3.5,
        0.08
    ));
    
    float3 lightDir = normalize(float3(-0.55, 0.75, 0.65));
    float3 viewDir = float3(0.0, 0.0, 1.0);
    float3 halfDir = normalize(lightDir + viewDir);
    
    float diffuse = max(dot(normal, lightDir), 0.0);
    float specular = pow(max(dot(normal, halfDir), 0.0), 42.0);
    float rim = pow(1.0 - max(dot(normal, viewDir), 0.0), 2.0);
    
    float ridge = 0.5 + 0.5 * sin(45.0 * h);
    float glow = exp(-8.0 * abs(h - 0.52));
    
    float3 color = paletteColor(
        h,
        ridge,
        glow,
        uniforms.fractalPalette
    );
    
    color *= 0.18 + 1.15 * diffuse;
    color += paletteColor(0.9, 1.0, 0.7, uniforms.fractalPalette) * rim * 0.28;
    color += float3(1.0, 0.75, 0.25) * specular * 0.55;
    color += paletteColor(0.8, 0.6, 1.0, uniforms.fractalPalette) * glow * 0.16;
    
    return float4(clamp(color, 0.0, 1.0), 1.0);
}

static float2 complexMul(float2 a, float2 b) {
    return float2(
        a.x * b.x - a.y * b.y,
        a.x * b.y + a.y * b.x
    );
}

static float2 complexDiv(float2 a, float2 b) {
    float denominator = b.x * b.x + b.y * b.y + 0.000000001;
    
    return float2(
        (a.x * b.x + a.y * b.y) / denominator,
        (a.y * b.x - a.x * b.y) / denominator
    );
}

static float4 renderNewton(
    float2 uv,
    constant Uniforms& uniforms
) {
    float x0 = uniforms.centerX + (uv.x - 0.5) * uniforms.scale * uniforms.aspectRatio;
    float y0 = uniforms.centerY + (0.5 - uv.y) * uniforms.scale;
    
    float2 z = float2(x0, y0);
    
    float2 rootA = float2(1.0, 0.0);
    float2 rootB = float2(-0.5, 0.8660254);
    float2 rootC = float2(-0.5, -0.8660254);
    
    uint iteration = 0;
    
    for (uint i = 0; i < uniforms.maxIterations; i++) {
        float2 z2 = complexMul(z, z);
        float2 z3 = complexMul(z2, z);
        
        float2 numerator = float2(z3.x - 1.0, z3.y);
        float2 denominator = complexMul(float2(3.0, 0.0), z2);
        
        float2 correction = complexDiv(numerator, denominator);
        z -= correction;
        
        iteration = i;
        
        if (length(correction) < 0.000001) {
            break;
        }
    }
    
    float dA = length(z - rootA);
    float dB = length(z - rootB);
    float dC = length(z - rootC);
    
    uint rootIndex = 0;
    float minD = dA;
    
    if (dB < minD) {
        minD = dB;
        rootIndex = 1;
    }
    
    if (dC < minD) {
        rootIndex = 2;
    }
    
    float t = float(iteration) / float(uniforms.maxIterations);
    float convergence = 1.0 - t;
    
    float edge = pow(t, 0.32);
    float glow = pow(max(convergence, 0.0), 0.28);
    float rings = 0.5 + 0.5 * sin(float(iteration) * 1.45);
    float fine = 0.5 + 0.5 * sin(float(iteration) * 4.8);
    
    float3 rootColor;
    
    if (uniforms.fractalPalette == 0) {
        if (rootIndex == 0) {
            rootColor = float3(0.02, 0.80, 1.00);
        } else if (rootIndex == 1) {
            rootColor = float3(0.05, 0.32, 1.00);
        } else {
            rootColor = float3(0.00, 1.00, 0.72);
        }
    } else if (uniforms.fractalPalette == 1) {
        if (rootIndex == 0) {
            rootColor = float3(0.00, 1.00, 1.00);
        } else if (rootIndex == 1) {
            rootColor = float3(0.20, 0.35, 1.00);
        } else {
            rootColor = float3(0.75, 0.00, 1.00);
        }
    } else if (uniforms.fractalPalette == 2) {
        if (rootIndex == 0) {
            rootColor = float3(1.00, 0.18, 0.02);
        } else if (rootIndex == 1) {
            rootColor = float3(1.00, 0.72, 0.02);
        } else {
            rootColor = float3(0.95, 0.05, 0.00);
        }
    } else if (uniforms.fractalPalette == 3) {
        if (rootIndex == 0) {
            rootColor = float3(0.70, 1.00, 1.00);
        } else if (rootIndex == 1) {
            rootColor = float3(0.25, 0.65, 1.00);
        } else {
            rootColor = float3(0.88, 0.92, 1.00);
        }
    } else if (uniforms.fractalPalette == 4) {
        if (rootIndex == 0) {
            rootColor = float3(1.00, 0.72, 0.05);
        } else if (rootIndex == 1) {
            rootColor = float3(1.00, 0.38, 0.02);
        } else {
            rootColor = float3(0.75, 0.95, 0.05);
        }
    } else if (uniforms.fractalPalette == 5) {
        if (rootIndex == 0) {
            rootColor = float3(0.95, 0.15, 1.00);
        } else if (rootIndex == 1) {
            rootColor = float3(0.35, 0.15, 1.00);
        } else {
            rootColor = float3(1.00, 0.35, 0.75);
        }
    } else {
        if (rootIndex == 0) {
            rootColor = float3(0.00, 0.95, 1.00);
        } else if (rootIndex == 1) {
            rootColor = float3(0.08, 0.38, 1.00);
        } else {
            rootColor = float3(0.82, 1.00, 0.15);
        }
    }
    
    float background = 0.05 + 0.12 * edge;
    float lineBoost = pow(rings, 5.0) * 0.45 + pow(fine, 10.0) * 0.35;
    float brightness = 0.22 + 1.25 * glow + lineBoost;
    
    float3 color = background + rootColor * brightness;
    
    return float4(clamp(color, 0.0, 1.0), 1.0);
}

static float mandelbulbDE(float3 p) {
    float3 z = p;
    float dr = 1.0;
    float r = 0.0;
    float power = 8.0;
    
    for (int i = 0; i < 12; i++) {
        r = length(z);
        
        if (r > 2.0) {
            break;
        }
        
        float theta = acos(clamp(z.z / max(r, 0.000001), -1.0, 1.0));
        float phi = atan2(z.y, z.x);
        
        dr = pow(r, power - 1.0) * power * dr + 1.0;
        
        float zr = pow(r, power);
        theta = theta * power;
        phi = phi * power;
        
        z = zr * float3(
            sin(theta) * cos(phi),
            sin(phi) * sin(theta),
            cos(theta)
        );
        
        z += p;
    }
    
    return 0.5 * log(r) * r / dr;
}

static float mandelboxDE(float3 p) {
    float3 z = p;
    float scaleFactor = 2.4;
    float dr = 1.0;
    
    float minRadius = 0.45;
    float fixedRadius = 1.0;
    
    for (int i = 0; i < 12; i++) {
        z = clamp(z, -1.0, 1.0) * 2.0 - z;
        
        float r2 = dot(z, z);
        
        if (r2 < minRadius * minRadius) {
            float factor = fixedRadius * fixedRadius / (minRadius * minRadius);
            z *= factor;
            dr *= factor;
        } else if (r2 < fixedRadius * fixedRadius) {
            float factor = fixedRadius * fixedRadius / r2;
            z *= factor;
            dr *= factor;
        }
        
        z = z * scaleFactor + p;
        dr = dr * abs(scaleFactor) + 1.0;
    }
    
    return length(z) / abs(dr);
}

static float3 estimateNormal(float3 p, uint mode) {
    float e = 0.0015;
    
    float dx;
    float dy;
    float dz;
    
    if (mode == 7) {
        dx = mandelboxDE(p + float3(e, 0.0, 0.0)) - mandelboxDE(p - float3(e, 0.0, 0.0));
        dy = mandelboxDE(p + float3(0.0, e, 0.0)) - mandelboxDE(p - float3(0.0, e, 0.0));
        dz = mandelboxDE(p + float3(0.0, 0.0, e)) - mandelboxDE(p - float3(0.0, 0.0, e));
    } else {
        dx = mandelbulbDE(p + float3(e, 0.0, 0.0)) - mandelbulbDE(p - float3(e, 0.0, 0.0));
        dy = mandelbulbDE(p + float3(0.0, e, 0.0)) - mandelbulbDE(p - float3(0.0, e, 0.0));
        dz = mandelbulbDE(p + float3(0.0, 0.0, e)) - mandelbulbDE(p - float3(0.0, 0.0, e));
    }
    
    return normalize(float3(dx, dy, dz));
}

static float4 renderRaymarched3D(
    float2 uv,
    constant Uniforms& uniforms,
    uint mode
) {
    float2 p;
    p.x = (uv.x - 0.5) * 2.0 * uniforms.aspectRatio;
    p.y = (uv.y - 0.5) * 2.0;
    
    float zoom = uniforms.scale / 2.8;
    p = p * zoom;
    p.x += uniforms.centerX;
    p.y += uniforms.centerY;
    
    float3 ro = float3(0.0, 0.0, -4.2);
    float3 rd = normalize(float3(p.x, p.y, 1.65));
    
    float totalDistance = 0.0;
    float hitDistance = 0.0;
    bool hit = false;
    
    float3 hitPoint = float3(0.0);
    
    for (int i = 0; i < 120; i++) {
        float3 pos = ro + rd * totalDistance;
        
        float d;
        if (mode == 7) {
            d = mandelboxDE(pos);
        } else {
            d = mandelbulbDE(pos);
        }
        
        if (d < 0.0012) {
            hit = true;
            hitDistance = totalDistance;
            hitPoint = pos;
            break;
        }
        
        totalDistance += d;
        
        if (totalDistance > 9.0) {
            break;
        }
    }
    
    if (!hit) {
        float vignette = 1.0 - smoothstep(0.2, 1.7, length(p));
        float glow = exp(-0.35 * totalDistance);
        float3 background = paletteColor(
            0.22 + 0.18 * glow,
            vignette,
            glow,
            uniforms.fractalPalette
        ) * 0.28;
        
        return float4(background, 1.0);
    }
    
    float3 normal = estimateNormal(hitPoint, mode);
    
    float3 lightDir = normalize(float3(-0.45, 0.65, -0.8));
    float3 viewDir = normalize(ro - hitPoint);
    float3 halfDir = normalize(lightDir + viewDir);
    
    float diffuse = max(dot(normal, lightDir), 0.0);
    float specular = pow(max(dot(normal, halfDir), 0.0), 48.0);
    float rim = pow(1.0 - max(dot(normal, viewDir), 0.0), 2.2);
    
    float depth = clamp(hitDistance / 6.5, 0.0, 1.0);
    float ao = clamp(1.0 - hitDistance * 0.08, 0.25, 1.0);
    
    float stripe = 0.5 + 0.5 * sin(28.0 * hitPoint.y + 18.0 * hitPoint.x);
    
    float3 color = paletteColor(
        mode == 7 ? 0.78 : 0.65,
        stripe,
        0.35,
        uniforms.fractalPalette
    );
    
    color *= 0.18 + 1.05 * diffuse;
    color += float3(1.0, 0.75, 0.25) * specular * 0.85;
    color += paletteColor(0.9, 1.0, 0.7, uniforms.fractalPalette) * rim * 0.45;
    color *= ao;
    
    color = mix(color, float3(0.01, 0.02, 0.08), depth * 0.35);
    
    return float4(clamp(color, 0.0, 1.0), 1.0);
}


static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float2 rotate2(float2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

static float3 flamePalette(float t, uint palette) {
    float3 a = paletteColor(fract(t + 0.05), 0.85, 0.65, palette);
    float3 b = paletteColor(fract(t + 0.36), 0.55, 0.80, palette);
    float3 pastel = mix(a, b, 0.45);
    return mix(pastel, float3(1.0, 0.86, 0.98), 0.18);
}

static float4 renderFlameSpiral(float2 uv, constant Uniforms& uniforms) {
    float2 p;
    p.x = (uv.x - 0.5) * uniforms.scale * uniforms.aspectRatio + uniforms.centerX;
    p.y = (0.5 - uv.y) * uniforms.scale + uniforms.centerY;

    // “Flame Flow” preview:
    // no polar sector folding, no fmod, no angle-based petals.
    // Pixel-shader approximation, not yet a true stochastic IFS flame renderer.
    p *= 2.75;

    float2 z = p;
    float density = 0.0;
    float glow = 0.0;
    float veins = 0.0;
    float colorSeed = 0.0;

    float iterPhase = clamp(float(uniforms.maxIterations) / 50000.0, 0.0, 1.0);

    for (int i = 0; i < 12; i++) {
        float fi = float(i);

        float r = length(z) + 0.001;
        float rot = 0.85 / (0.38 + r) + 0.28 * sin(3.4 * z.x - 2.9 * z.y + fi * 0.71);
        z = rotate2(z, rot);

        float2 w;
        w.x = sin(3.20 * z.y + 0.92 * sin(3.7 * z.x + fi * 0.63));
        w.y = cos(3.05 * z.x - 0.86 * cos(3.5 * z.y - fi * 0.58));

        float2 q;
        q.x = sin(4.10 * z.x + 1.35 * w.x + fi * 0.37);
        q.y = cos(3.85 * z.y - 1.25 * w.y - fi * 0.41);

        z += 0.105 * w + 0.045 * q;

        float inv = 1.0 / (0.35 + dot(z, z));
        z = mix(z, z * inv, 0.105);

        z = z * (0.86 + 0.028 * sin(fi + r * 2.4))
          + 0.026 * float2(sin(fi * 1.31), cos(fi * 1.47));

        float rr = length(z) + 0.001;
        float mist = exp(-0.82 * rr);

        float field1 = sin(5.0 * z.x + 2.2 * sin(2.7 * z.y) + fi * 0.51);
        float field2 = cos(4.6 * z.y - 2.0 * sin(2.3 * z.x) - fi * 0.43);
        float field3 = sin(3.1 * (z.x + z.y) + 1.7 * cos(2.0 * (z.x - z.y)) + fi);

        float veinLine = exp(-55.0 * abs(field1 * field2));
        float softLine = pow(0.5 + 0.5 * field3, 11.0);

        density += mist * (0.030 + 0.010 * fi);
        veins += veinLine * mist * (0.95 + 0.080 * fi);
        glow += softLine * mist * (0.58 - 0.018 * fi);

        float grain = hash21(floor((z + fi) * 380.0)) * 0.018;
        colorSeed += (0.09 + 0.015 * fi) * (0.5 + 0.5 * field3) + grain;
    }

    float r0 = length(p) + 0.001;

    float centerHole = smoothstep(0.045, 0.185, r0);
    float outerFade = exp(-0.070 * r0 * r0);

    float bodyFlow =
        0.5
        + 0.22 * sin(2.1 * p.x + 1.4 * sin(2.0 * p.y))
        + 0.18 * cos(2.0 * p.y - 1.2 * cos(1.8 * p.x))
        + 0.10 * sin(1.4 * (p.x + p.y));

    bodyFlow = clamp(bodyFlow, 0.0, 1.0);

    float finalDensity =
        (0.04 * density + 1.25 * glow + 3.20 * veins)
        * centerHole
        * outerFade
        * (0.32 + 1.05 * bodyFlow);

    float t = fract(
        0.12
        + 0.28 * colorSeed
        + 0.22 * r0
        + 0.13 * sin(1.7 * p.x - 1.3 * p.y)
        + 0.18 * iterPhase
    );

    // Sharper pearlescent flame palette with real color separation.
    float3 c1 = flamePalette(t + 0.00, uniforms.fractalPalette);
    float3 c2 = flamePalette(t + 0.31 + 0.22 * sin(4.0 * p.x), uniforms.fractalPalette);
    float3 c3 = flamePalette(t + 0.62 + 0.18 * cos(3.6 * p.y), uniforms.fractalPalette);

    float colorSplit = clamp(0.45 * veins + 0.35 * glow + 0.20 * bodyFlow, 0.0, 1.0);
    float3 flame = mix(c1, c2, smoothstep(0.08, 0.75, colorSplit));
    flame = mix(flame, c3, 0.45 * smoothstep(0.18, 1.10, veins));

    float3 bg = float3(0.010, 0.014, 0.020);
    float3 smoke = flamePalette(t + 0.42, uniforms.fractalPalette) * 0.13;
    bg = mix(bg, smoke, clamp(density * 0.18, 0.0, 0.45));

    float3 color = bg + flame * finalDensity * 3.40;
    color += float3(0.70, 0.90, 1.00) * pow(clamp(glow * centerHole, 0.0, 1.0), 1.25) * 0.32;

    float core = 1.0 - smoothstep(0.045, 0.175, r0);
    color = mix(color, float3(0.0, 0.0, 0.0), core * 0.88);

    color = 1.0 - exp(-color * 1.85);
    color = pow(clamp(color, 0.0, 1.0), float3(0.82));

    return float4(clamp(color, 0.0, 1.0), 1.0);
}

fragment float4 fractal_fragment(
    VertexOut in [[stage_in]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    if (uniforms.fractalMode == 5) {
        return renderRaymarched3D(in.uv, uniforms, 5);
    }
    
    if (uniforms.fractalMode == 7) {
        return renderRaymarched3D(in.uv, uniforms, 7);
    }
    
    if (uniforms.fractalMode == 6) {
        return renderMandelbrotRelief(in.uv, uniforms);
    }
    
    if (uniforms.fractalMode == 8) {
        return renderNewton(in.uv, uniforms);
    }
    
    if (uniforms.fractalMode == 9) {
        return renderFlameSpiral(in.uv, uniforms);
    }
    
    float2 uv = in.uv;
    
    float x0 = uniforms.centerX + (uv.x - 0.5) * uniforms.scale * uniforms.aspectRatio;
    float y0 = uniforms.centerY + (0.5 - uv.y) * uniforms.scale;
    
    uint iteration = fractalIteration(
        uniforms.fractalMode,
        x0,
        y0,
        uniforms.maxIterations
    );
    
    if (iteration == uniforms.maxIterations) {
        return float4(
            insideColor(
                uniforms.fractalMode,
                uniforms.fractalPalette
            ),
            1.0
        );
    }
    
    float t = float(iteration) / float(uniforms.maxIterations);
    float k = sqrt(t);
    
    float relief;
    float ridge;
    float glow;
    
    if (uniforms.fractalMode == 4) {
        relief = pow(k, 0.38);
        ridge = 0.5 + 0.5 * sin(70.0 * k);
        glow = exp(-8.0 * abs(k - 0.42));
    } else {
        relief = t;
        ridge = 0.5 + 0.5 * sin(38.0 * k);
        glow = exp(-7.0 * abs(k - 0.45));
    }
    
    float3 color = paletteColor(
        relief,
        ridge,
        glow,
        uniforms.fractalPalette
    );
    
    return float4(color, 1.0);
}
