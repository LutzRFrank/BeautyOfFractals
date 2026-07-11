#include <metal_stdlib>
using namespace metal;

// BeautyOfFractals
//
// MandelbrotShader.metal
//
// GPU preview shaders for BeautyOfFractals.
//
// Optimized for responsive interactive rendering. Extreme deep zooms are
// refined by the separate high-precision CPU rendering path.
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
    
    if (mode == 0 || mode == 6 || mode == 9 || mode == 10) {
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
        } else if (mode == 10) {
            float realSquared = x * x - y * y;
            float imaginarySquared = 2.0 * x * y;
            x = abs(realSquared) + cx;
            y = imaginarySquared + cy;
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
        } else if (mode == 9) {
            float x2 = x * x - y * y;
            float y2 = 2.0 * x * y;
            float x4 = x2 * x2 - y2 * y2;
            float y4 = 2.0 * x2 * y2;

            x = x4 * x4 - y4 * y4 + cx;
            y = 2.0 * x4 * y4 + cy;
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
    } else if (palette == 6) {
        float yellowSpark = pow(glow, 1.35);
        float cyanEdge = pow(relief, 0.55);
        
        color = float3(
            0.00 + 0.05 * cyanEdge + 0.80 * yellowSpark + 0.10 * ridge,
            0.04 + 0.70 * cyanEdge + 0.95 * yellowSpark + 0.20 * ridge,
            0.18 + 1.05 * cyanEdge + 0.18 * yellowSpark + 0.18 * ridge
        );
    } else if (palette == 14) {
        // Keep the deep-blue atmosphere while lifting midtones and fine information edges.
        float body = pow(relief, 0.56);
        float detail = pow(ridge, 1.35);
        float light = pow(glow, 1.15);
        float phase = fract(0.10 + 3.60 * pow(relief, 0.62) + 5.40 * ridge + 0.55 * glow);
        float cyanBand = smoothstep(0.01, 0.06, phase) * (1.0 - smoothstep(0.12, 0.17, phase));
        float violetBand = smoothstep(0.19, 0.24, phase) * (1.0 - smoothstep(0.31, 0.36, phase));
        float magentaBand = smoothstep(0.40, 0.45, phase) * (1.0 - smoothstep(0.53, 0.58, phase));
        float greenBand = smoothstep(0.60, 0.64, phase) * (1.0 - smoothstep(0.69, 0.73, phase));
        float warmBand = smoothstep(0.76, 0.82, phase) * (1.0 - smoothstep(0.88, 0.94, phase));

        color = float3(
            0.006 + 0.036 * body + 0.31 * light,
            0.022 + 0.50 * body + 0.40 * light,
            0.135 + 0.91 * body + 0.11 * light
        );
        float accent = detail * (0.30 + 0.78 * body);
        color += accent * (
            float3(0.03, 0.78, 1.12) * cyanBand
            + float3(0.62, 0.08, 0.90) * violetBand
            + float3(1.02, 0.08, 0.82) * magentaBand
            + float3(0.14, 1.02, 0.18) * greenBand
            + float3(1.08, 0.62, 0.03) * warmBand
        );
    } else if (palette == 7) {
        float detail = pow(ridge, 0.72);
        float warmBody = pow(relief, 0.58);
        float hotGlow = pow(glow, 0.82);
        float darkFiligree = pow(1.0 - clamp(relief + glow * 0.35, 0.0, 1.0), 2.8) * ridge;
        
        color = float3(
            0.40 + 0.82 * warmBody + 0.60 * hotGlow + 0.42 * detail - 0.30 * darkFiligree,
            0.28 + 0.78 * warmBody + 0.42 * hotGlow + 0.12 * detail - 0.36 * darkFiligree,
            0.08 + 0.24 * warmBody + 0.05 * hotGlow + 0.04 * detail - 0.22 * darkFiligree
        );
    } else if (palette == 8) {
        float detail = pow(ridge, 0.58);
        float warmBody = pow(relief, 0.52);
        float ember = pow(glow, 0.72);
        float darkFiligree = pow(1.0 - clamp(relief * 0.8 + glow * 0.45, 0.0, 1.0), 2.2) * ridge;
        
        color = float3(
            0.18 + 1.10 * warmBody + 0.92 * ember + 0.58 * detail - 0.40 * darkFiligree,
            0.05 + 0.45 * warmBody + 0.36 * ember + 0.16 * detail - 0.32 * darkFiligree,
            0.01 + 0.10 * warmBody + 0.04 * ember + 0.04 * detail - 0.20 * darkFiligree
        );
    } else if (palette == 9) {
        // Solar Pop:
        // high-contrast lemon, ivory, coral-red and charcoal bands.
        // More colorful and stepped than Solar Coral, but kept separate as palette 9.
        float detail = pow(ridge, 0.50);
        float body = pow(relief, 0.44);
        float light = pow(glow, 0.60);
        
        float phase = fract(0.06 + 2.75 * relief + 4.15 * glow + 6.80 * ridge);
        float micro = 0.5 + 0.5 * cos(62.0 * ridge + 15.0 * glow - 9.0 * relief);
        
        float redBand = smoothstep(0.08, 0.18, phase) * (1.0 - smoothstep(0.30, 0.44, phase));
        float lemonBand = smoothstep(0.28, 0.42, phase) * (1.0 - smoothstep(0.56, 0.70, phase));
        float ivoryBand = smoothstep(0.58, 0.72, phase) * (1.0 - smoothstep(0.82, 0.96, phase));
        float darkBand = smoothstep(0.80, 0.94, phase);
        
        float3 warmOrange = float3(1.00, 0.50, 0.02);
        float3 lemon = float3(1.00, 0.95, 0.04);
        float3 coralRed = float3(1.00, 0.08, 0.025);
        float3 ivory = float3(1.00, 0.94, 0.74);
        float3 charcoal = float3(0.050, 0.038, 0.030);
        
        float3 base = warmOrange;
        base = mix(base, lemon, 0.78 * lemonBand);
        base = mix(base, coralRed, 0.70 * redBand);
        base = mix(base, ivory, 0.58 * ivoryBand * (0.35 + 0.65 * detail));
        base = mix(base, charcoal, 0.36 * darkBand * detail);
        
        float edgeSpark = pow(detail, 0.68) * (0.50 + 0.50 * micro);
        float lift = 0.56 + 0.72 * body + 0.44 * light;
        
        color = base * lift
              + float3(0.48, 0.32, 0.07) * edgeSpark
              + float3(0.38, 0.04, 0.02) * redBand * detail;
    } else if (palette == 10) {
        // Rainbows:
        // Explicit spectral cycles: red → yellow → green → cyan → blue → magenta.
        float phase = fract(0.08 + 5.20 * pow(relief, 0.58) + 0.72 * ridge + 0.35 * glow);
        float h6 = phase * 6.0;

        float red = clamp(abs(h6 - 3.0) - 1.0, 0.0, 1.0);
        float green = clamp(2.0 - abs(h6 - 2.0), 0.0, 1.0);
        float blue = clamp(2.0 - abs(h6 - 4.0), 0.0, 1.0);

        float brightness = 0.58 + 0.48 * pow(relief, 0.32) + 0.18 * glow;
        float sparkle = 0.10 + 0.20 * pow(ridge, 1.60);

        color = float3(
            red * brightness + sparkle,
            green * brightness + sparkle,
            blue * brightness + sparkle
        );
    } else if (palette == 11) {
        // Abyss:
        // Deep navy water, cyan and ice reefs, balanced by broad sand-gold
        // and amber currents inspired by a warm ocean-floor glow.
        float body = pow(relief, 0.46);
        float detail = pow(ridge, 0.64);
        float iceGlow = pow(glow, 0.74);

        float phase = fract(0.08 + 2.30 * relief + 1.90 * glow + 3.35 * ridge);
        float iceBand = smoothstep(0.24, 0.38, phase)
                      * (1.0 - smoothstep(0.57, 0.72, phase));
        float goldBand = smoothstep(0.80, 0.87, phase)
                       * (1.0 - smoothstep(0.94, 0.990, phase));

        float warmPhase = fract(0.16 + 0.82 * relief + 0.46 * glow + 0.74 * ridge);
        float warmBody = smoothstep(0.18, 0.34, warmPhase)
                       * (1.0 - smoothstep(0.62, 0.80, warmPhase));

        float3 midnight = float3(0.003, 0.014, 0.070);
        float3 cobalt = float3(0.010, 0.145, 0.470);
        float3 cyan = float3(0.000, 0.860, 1.000);
        float3 ice = float3(0.880, 1.000, 1.000);
        float3 sandGold = float3(0.82, 0.66, 0.30);

        float3 base = mix(midnight, cobalt, min(0.88, 0.44 + 0.34 * body));
        base = mix(base, cyan, min(0.78, 0.44 * body + 0.32 * detail + 0.16 * iceGlow));
        base = mix(base, sandGold, 0.46 * warmBody * (0.36 + 0.64 * body));
        base = mix(
            base,
            ice,
            min(0.88, 0.72 * iceBand * (0.24 + 0.76 * detail) + 0.50 * iceGlow)
        );

        float amberGlow = 0.44 * goldBand * (0.24 + 0.76 * detail);
        float reefSpark = 0.16 * pow(detail, 1.38) + 0.14 * iceGlow;
        float lift = 0.66 + 0.50 * body + 0.34 * iceGlow;

        color = base * lift
              + float3(0.52, 0.26, 0.03) * amberGlow
              + float3(0.05, 0.23, 0.30) * reefSpark;
    } else if (palette == 13) {
        float body = pow(relief, 0.58);
        float ridgeGold = pow(ridge, 2.40);
        float ridgeHot = pow(ridge, 5.20);
        float ridgeChampagne = pow(ridge, 10.0);
        float glowGold = pow(glow, 1.10);
        float phase = fract(0.05 + 1.10 * relief + 1.35 * glow + 5.80 * ridge);
        float band = smoothstep(0.26, 0.44, phase)
                   * (1.0 - smoothstep(0.72, 0.90, phase));
        float darkCrack = pow(1.0 - clamp(relief * 0.84 + glow * 0.36, 0.0, 1.0), 2.10) * pow(ridge, 1.25);
        float facet = 0.5 + 0.5 * cos(96.0 * ridge + 23.0 * glow - 11.0 * relief);

        float3 shadow = float3(0.015, 0.010, 0.004);
        float3 darkBronze = float3(0.120, 0.055, 0.010);
        float3 bronze = float3(0.360, 0.180, 0.035);
        float3 antiqueGold = float3(0.780, 0.480, 0.090);
        float3 hotGold = float3(1.000, 0.720, 0.160);
        float3 champagne = float3(1.000, 0.940, 0.700);

        float ramp = clamp(0.10 + 0.66 * body + 0.16 * glowGold, 0.0, 1.0);
        float3 base;
        if (ramp < 0.22) {
            base = mix(shadow, darkBronze, ramp / 0.22);
        } else if (ramp < 0.46) {
            base = mix(darkBronze, bronze, (ramp - 0.22) / 0.24);
        } else if (ramp < 0.72) {
            base = mix(bronze, antiqueGold, (ramp - 0.46) / 0.26);
        } else {
            base = mix(antiqueGold, hotGold, (ramp - 0.72) / 0.28);
        }

        base = mix(base, antiqueGold, 0.34 * band * (0.40 + 0.60 * ridgeGold));
        base = mix(base, hotGold, 0.58 * ridgeGold * (0.35 + 0.65 * glowGold));
        base = mix(base, champagne, 0.86 * ridgeChampagne * (0.45 + 0.55 * facet));
        base = mix(base, shadow, 0.46 * darkCrack);

        color = base
              + float3(0.24, 0.19, 0.10) * ridgeHot
              + float3(0.04, 0.03, 0.015) * ridgeGold;
    } else {
        // Deep Current:
        // Explicit blue-gold ocean ramp with broad, clean amber phases.
        float detail = pow(ridge, 0.72);
        float iceGlow = pow(glow, 0.82);

        float phase = fract(0.04 + 1.12 * relief + 0.42 * glow + 0.84 * ridge);

        float3 midnight = float3(0.004, 0.018, 0.085);
        float3 cobalt = float3(0.010, 0.155, 0.520);
        float3 cyan = float3(0.000, 0.720, 0.980);
        float3 ice = float3(0.850, 0.980, 1.000);
        float3 deepBlue = float3(0.010, 0.080, 0.260);
        float3 sandGold = float3(0.88, 0.64, 0.22);
        float3 amber = float3(1.000, 0.300, 0.045);

        float3 base;
        if (phase < 0.14) {
            base = mix(midnight, cobalt, phase / 0.14);
        } else if (phase < 0.28) {
            base = mix(cobalt, cyan, (phase - 0.14) / 0.14);
        } else if (phase < 0.42) {
            base = mix(cyan, ice, (phase - 0.28) / 0.14);
        } else if (phase < 0.54) {
            base = mix(ice, deepBlue, (phase - 0.42) / 0.12);
        } else if (phase < 0.68) {
            base = mix(deepBlue, sandGold, (phase - 0.54) / 0.14);
        } else if (phase < 0.84) {
            base = mix(sandGold, amber, (phase - 0.68) / 0.16);
        } else {
            base = mix(amber, midnight, (phase - 0.84) / 0.16);
        }

        float iceEdge = 0.22 * pow(detail, 1.38) * (0.28 + 0.72 * iceGlow);
        float goldEdge = 0.14 * pow(detail, 1.18)
                       * smoothstep(0.62, 0.86, phase);
        float lift = 0.54 + 0.34 * pow(relief, 0.48) + 0.24 * iceGlow;

        color = base * lift
              + float3(0.48, 0.72, 0.80) * iceEdge
              + float3(0.58, 0.31, 0.05) * goldEdge;
    }
    
    return clamp(color, 0.0, 1.0);
}

static float3 auricInteriorColor(float2 uv) {
    float x = uv.x * 2.0 - 1.0;
    float y = uv.y * 2.0 - 1.0;
    float radius = min(length(float2(x, y)), 1.35);

    float3 body = float3(0.550, 0.340, 0.080);
    float3 shadow = float3(0.160, 0.075, 0.015);
    float3 hotGold = float3(0.950, 0.650, 0.160);
    float3 champagne = float3(1.000, 0.920, 0.650);

    float diagonal = 1.0 - smoothstep(0.08, 0.62, abs(x - y + 0.18));
    float upperLeftGlow = exp(-5.2 * ((x + 0.42) * (x + 0.42) + (y + 0.38) * (y + 0.38)));
    float edgeShadow = smoothstep(0.48, 1.12, radius);
    float lowerShadow = smoothstep(-0.18, 0.92, y);
    float facet = 0.5 + 0.5 * cos(18.0 * x - 13.0 * y + 7.0 * radius);
    float band = 0.5 + 0.5 * cos(24.0 * (x - y) + 5.0 * radius);

    float3 color = mix(shadow, body, clamp(0.84 + 0.10 * facet, 0.0, 1.0));
    color = mix(color, shadow, clamp(0.34 * edgeShadow + 0.18 * lowerShadow, 0.0, 1.0));
    color = mix(color, hotGold, clamp(0.28 * diagonal + 0.18 * upperLeftGlow + 0.06 * band, 0.0, 1.0));
    color = mix(color, champagne, clamp(0.24 * pow(diagonal, 3.2) * (0.45 + 0.55 * facet), 0.0, 1.0));

    return clamp(color, 0.0, 1.0);
}

static float3 insideColor(uint mode, uint palette) {
    if (mode == 0 || mode == 6) {
        if (palette == 13) {
            return float3(0.560, 0.345, 0.085);
        }

        return float3(0.0, 0.0, 0.0);
    }

    if (mode == 9) {
        return float3(0.018, 0.004, 0.055);
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
        } else if (palette == 6) {
            return float3(0.00, 0.01, 0.08);
        } else if (palette == 7) {
            return float3(0.10, 0.055, 0.020);
        } else if (palette == 8) {
            return float3(0.075, 0.020, 0.010);
        } else if (palette == 9) {
            return float3(0.090, 0.040, 0.018);
        } else if (palette == 10) {
            return float3(0.018, 0.008, 0.065);
        } else if (palette == 11) {
            return float3(0.003, 0.012, 0.060);
        } else if (palette == 13) {
            return float3(0.560, 0.345, 0.085);
        } else {
            return float3(0.004, 0.016, 0.072);
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
        if (uniforms.fractalPalette == 13) {
            return float4(auricInteriorColor(uv), 1.0);
        }

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

static float3 newtonPopRootColor(uint palette, uint rootIndex) {
    uint r = rootIndex % 5;
    
    if (palette == 0) {
        if (r == 0) return float3(0.00, 0.95, 1.00);
        if (r == 1) return float3(0.00, 0.30, 1.00);
        if (r == 2) return float3(0.00, 1.00, 0.58);
        if (r == 3) return float3(0.08, 0.05, 0.55);
        return float3(0.78, 1.00, 0.12);
    } else if (palette == 1) {
        if (r == 0) return float3(0.00, 1.00, 1.00);
        if (r == 1) return float3(1.00, 0.00, 0.95);
        if (r == 2) return float3(0.15, 0.20, 1.00);
        if (r == 3) return float3(0.00, 1.00, 0.35);
        return float3(1.00, 0.95, 0.00);
    } else if (palette == 2) {
        if (r == 0) return float3(1.00, 0.08, 0.00);
        if (r == 1) return float3(1.00, 0.62, 0.00);
        if (r == 2) return float3(1.00, 0.98, 0.08);
        if (r == 3) return float3(0.48, 0.02, 0.00);
        return float3(1.00, 0.25, 0.02);
    } else if (palette == 3) {
        if (r == 0) return float3(0.86, 1.00, 1.00);
        if (r == 1) return float3(0.18, 0.62, 1.00);
        if (r == 2) return float3(0.56, 0.92, 1.00);
        if (r == 3) return float3(0.04, 0.10, 0.45);
        return float3(1.00, 1.00, 0.92);
    } else if (palette == 4) {
        if (r == 0) return float3(1.00, 0.84, 0.05);
        if (r == 1) return float3(1.00, 0.34, 0.02);
        if (r == 2) return float3(0.74, 1.00, 0.05);
        if (r == 3) return float3(0.44, 0.16, 0.02);
        return float3(1.00, 0.96, 0.62);
    } else if (palette == 5) {
        if (r == 0) return float3(0.96, 0.05, 1.00);
        if (r == 1) return float3(0.26, 0.10, 1.00);
        if (r == 2) return float3(1.00, 0.40, 0.76);
        if (r == 3) return float3(0.04, 0.02, 0.25);
        return float3(1.00, 0.92, 0.18);
    } else if (palette == 6) {
        if (r == 0) return float3(0.00, 0.92, 1.00);
        if (r == 1) return float3(0.02, 0.22, 1.00);
        if (r == 2) return float3(0.80, 1.00, 0.08);
        if (r == 3) return float3(0.00, 0.03, 0.22);
        return float3(0.78, 0.92, 1.00);
    } else if (palette == 7) {
        if (r == 0) return float3(1.00, 0.88, 0.12);
        if (r == 1) return float3(1.00, 0.22, 0.06);
        if (r == 2) return float3(1.00, 0.55, 0.05);
        if (r == 3) return float3(0.42, 0.18, 0.04);
        return float3(1.00, 0.94, 0.68);
    } else if (palette == 8) {
        if (r == 0) return float3(1.00, 0.12, 0.02);
        if (r == 1) return float3(1.00, 0.50, 0.02);
        if (r == 2) return float3(1.00, 0.86, 0.08);
        if (r == 3) return float3(0.06, 0.01, 0.00);
        return float3(0.70, 0.16, 0.05);
    } else if (palette == 9) {
        if (r == 0) return float3(1.00, 0.96, 0.02);
        if (r == 1) return float3(1.00, 0.08, 0.02);
        if (r == 2) return float3(1.00, 0.48, 0.02);
        if (r == 3) return float3(0.05, 0.035, 0.025);
        return float3(1.00, 0.94, 0.68);
    } else if (palette == 10) {
        if (r == 0) return float3(1.00, 0.08, 0.16);
        if (r == 1) return float3(1.00, 0.80, 0.05);
        if (r == 2) return float3(0.12, 1.00, 0.38);
        if (r == 3) return float3(0.05, 0.62, 1.00);
        return float3(0.72, 0.12, 1.00);
    } else if (palette == 11) {
        if (r == 0) return float3(0.00, 0.14, 0.42);
        if (r == 1) return float3(0.00, 0.72, 0.98);
        if (r == 2) return float3(0.78, 0.98, 1.00);
        if (r == 3) return float3(0.02, 0.04, 0.16);
        return float3(1.00, 0.62, 0.12);
    } else if (palette == 13) {
        if (r == 0) return float3(0.03, 0.025, 0.020);
        if (r == 1) return float3(0.36, 0.18, 0.045);
        if (r == 2) return float3(0.95, 0.66, 0.14);
        if (r == 3) return float3(1.00, 0.92, 0.68);
        return float3(0.12, 0.16, 0.19);
    } else if (palette == 14) {
        if (r == 0) return float3(0.01, 0.08, 0.30);
        if (r == 1) return float3(0.04, 0.68, 0.96);
        if (r == 2) return float3(0.48, 0.10, 0.82);
        if (r == 3) return float3(0.94, 0.10, 0.62);
        return float3(1.00, 0.68, 0.08);
    } else {
        if (r == 0) return float3(0.01, 0.08, 0.30);
        if (r == 1) return float3(0.02, 0.64, 0.92);
        if (r == 2) return float3(0.88, 0.98, 1.00);
        if (r == 3) return float3(0.92, 0.62, 0.16);
        return float3(1.00, 0.30, 0.04);
    }
}

static float4 renderNewton(
    float2 uv,
    constant Uniforms& uniforms
) {
    float x0 = uniforms.centerX + (uv.x - 0.5) * uniforms.scale * uniforms.aspectRatio;
    float y0 = uniforms.centerY + (0.5 - uv.y) * uniforms.scale;
    
    float2 z = float2(x0, y0);
    
    float2 roots[5] = {
        float2( 1.0000000,  0.0000000),
        float2( 0.3090170,  0.9510565),
        float2(-0.8090170,  0.5877853),
        float2(-0.8090170, -0.5877853),
        float2( 0.3090170, -0.9510565)
    };
    
    uint iteration = 0;
    
    for (uint i = 0; i < uniforms.maxIterations; i++) {
        float2 z2 = complexMul(z, z);
        float2 z4 = complexMul(z2, z2);
        float2 z5 = complexMul(z4, z);
        
        float2 numerator = float2(z5.x - 1.0, z5.y);
        float2 denominator = float2(5.0 * z4.x, 5.0 * z4.y);
        float2 correction = complexDiv(numerator, denominator);
        z -= correction;
        
        iteration = i;
        
        if (length(correction) < 0.000001) {
            break;
        }
    }
    
    uint rootIndex = 0;
    float minD = length(z - roots[0]);
    
    for (uint i = 1; i < 5; i++) {
        float d = length(z - roots[i]);
        if (d < minD) {
            minD = d;
            rootIndex = i;
        }
    }
    
    float t = clamp(float(iteration) / float(uniforms.maxIterations), 0.0, 1.0);
    float boundary = pow(clamp(t * 4.2, 0.0, 1.0), 0.62);
    float convergence = pow(1.0 - t, 0.32);
    float rings = 0.5 + 0.5 * sin(float(iteration) * 2.35 + float(rootIndex) * 1.70);
    float fine = 0.5 + 0.5 * sin(float(iteration) * 6.10 + atan2(y0, x0) * 3.0);
    float angle = 0.5 + 0.5 * sin(7.0 * atan2(y0, x0) + float(rootIndex) * 2.1);
    
    float3 base = newtonPopRootColor(uniforms.fractalPalette, rootIndex);
    float3 next = newtonPopRootColor(uniforms.fractalPalette, rootIndex + 1);
    float mixAmount = 0.12 + 0.28 * pow(angle, 2.0) * boundary;
    float3 color = mix(base, next, mixAmount);
    
    float bright = 0.40 + 0.92 * convergence + 0.35 * pow(rings, 5.0) * boundary;
    color *= bright;
    
    float ink = pow(boundary, 1.85) * (0.42 + 0.30 * (1.0 - fine));
    color *= (1.0 - ink);
    
    float goldEdge = pow(rings, 10.0) * boundary * 0.48;
    float whiteSpark = pow(fine, 18.0) * boundary * 0.25;
    color += float3(0.95, 0.74, 0.18) * goldEdge + float3(1.0) * whiteSpark;
    
    return float4(clamp(color, 0.0, 1.0), 1.0);
}

static float mandelbulbDE(float3 p) {
    float3 z = p;
    float dr = 1.0;
    float r = 0.0;
    float power = 8.0;
    
    for (int i = 0; i < 9; i++) {
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
        if (uniforms.fractalPalette == 13 &&
            (uniforms.fractalMode == 0 || uniforms.fractalMode == 6)) {
            return float4(auricInteriorColor(uv), 1.0);
        }

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
