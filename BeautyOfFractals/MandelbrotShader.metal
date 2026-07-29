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
    uint colorNormalizationIterations;
    float aspectRatio;
    uint fractalMode;
    uint fractalPalette;
    float plateauTiltDegrees;
    float doodadsStructure;
    float doodadsComplexity;
    float doodadsCurl;
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
    
    if (mode == 0 || mode == 6 || mode == 9 || mode == 10 || mode == 22 || (mode >= 11 && mode <= 21)) {
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
        if (mode == 0 || mode == 1 || mode == 6 || mode == 22) {
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
        } else if (mode >= 11 && mode <= 21) {
            uint exponent = mode == 21 ? 2 : (mode == 11 ? 4 : (mode == 12 ? 3 : mode - 8));
            float baseX = x;
            float baseY = y;
            float powerX = x;
            float powerY = y;
            for (uint p = 1; p < exponent; ++p) {
                float nextX = powerX * baseX - powerY * baseY;
                powerY = powerX * baseY + powerY * baseX;
                powerX = nextX;
            }
            x = powerX + cx;
            y = powerY + cy;
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
    } else if (palette == 16) {
        float body = pow(relief, 0.58);
        float detail = pow(ridge, 2.40);
        float sheen = 0.5 + 0.5 * sin(8.0 * relief + 11.0 * glow + 17.0 * ridge);
        float gray = clamp(0.04 + 0.72 * body + 0.22 * detail, 0.0, 1.0);
        color = clamp(float3(gray + 0.07 * sheen,
                             gray + 0.045,
                             gray + 0.08 * (1.0 - sheen)), 0.0, 1.0);
    } else if (palette == 15) {
        // Pearl: a cool monochrome counterpart to Auric.
        float body = pow(relief, 0.58);
        float detail = pow(ridge, 2.40);
        float sparkle = pow(ridge, 9.0);
        float light = pow(glow, 1.10);
        float crack = pow(1.0 - clamp(relief * 0.84 + glow * 0.36, 0.0, 1.0), 2.10) * pow(ridge, 1.25);
        float phase = fract(0.05 + 1.10 * relief + 1.35 * glow + 5.80 * ridge);
        float band = smoothstep(0.26, 0.44, phase) * (1.0 - smoothstep(0.72, 0.90, phase));

        float tone = clamp(0.035 + 0.70 * body + 0.18 * light, 0.0, 1.0);
        float3 graphite = float3(0.018, 0.022, 0.028);
        float3 silver = float3(0.48, 0.51, 0.55);
        float3 ivory = float3(0.91, 0.92, 0.90);
        float3 white = float3(1.0, 1.0, 0.985);
        float3 base = mix(graphite, silver, min(tone / 0.58, 1.0));
        base = mix(base, ivory, max((tone - 0.58) / 0.42, 0.0));
        base = mix(base, white, 0.52 * detail + 0.72 * sparkle);
        base = mix(base, ivory, 0.28 * band);
        color = mix(base, graphite, 0.48 * crack);
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

// A compact GPU interpretation of Dennis Magar's Doodads idea. The original
// Ultra Fractal coloring constructs a transformed trap for every orbit sample
// and colors from the closest encounter. This keeps that defining behavior,
// while using a smaller, stable family of folded polar traps suitable for the
// live Metal renderer.
static float4 metallicDoodadsColor(
    float x0,
    float y0,
    uint mode,
    uint maxIterations,
    float structure,
    float complexity,
    float curl
) {
    float2 z = mode == 1 ? float2(x0, y0) : float2(0.0);
    float2 c = mode == 1 ? float2(-0.8, 0.156) : float2(x0, y0);
    uint exponent = mode == 21 ? 2 : (mode == 11 ? 4 : (mode == 12 ? 3 : (mode >= 13 && mode <= 20 ? mode - 8 : 2)));
    float minimumDistance = 1e10;
    float closestIteration = 0.0;
    uint iteration = 0u;

    for (; iteration < maxIterations; iteration++) {
        float2 power = z;
        for (uint p = 1; p < exponent; ++p) {
            power = float2(
                power.x * z.x - power.y * z.y,
                power.x * z.y + power.y * z.x
            );
        }
        z = power + c;

        float radius = max(length(z), 1e-8);
        float angle = atan2(z.y, z.x);
        float2 folded = abs(z);

        float petalCount = 4.0 + floor(clamp(structure, 0.0, 1.0) * 7.0);
        float petals = 0.29
            + (0.045 + 0.060 * structure) * cos(petalCount * angle);
        float petalTrap = abs(radius - petals);
        float latticeTrap = abs(folded.x * folded.y - 0.055)
            * (1.65 - 1.30 * complexity);
        float curlTrap = abs(
            sin(
                (2.0 + 2.0 * structure) * angle
                + (0.70 + 3.40 * curl) * log2(radius + 0.035)
            )
        ) * radius * (0.25 - 0.18 * complexity);
        float trapDistance = min(petalTrap, min(latticeTrap, curlTrap));

        if (trapDistance < minimumDistance) {
            minimumDistance = trapDistance;
            closestIteration = float(iteration);
        }

        if (dot(z, z) > 256.0) {
            break;
        }
    }

    float scale = exp(
        -(23.0 - 8.0 * complexity) * sqrt(max(minimumDistance, 0.0))
    );
    float bands = 0.5 + 0.5 * cos(
        (18.0 + 28.0 * complexity)
            * pow(max(minimumDistance, 1e-8), 0.22)
        - (0.18 + 0.32 * curl) * closestIteration
    );
    float filament = pow(scale, 2.1);
    float highlight = pow(clamp(scale * (0.35 + 0.65 * bands), 0.0, 1.0), 5.0);
    float depth = pow(clamp(1.0 - scale, 0.0, 1.0), 1.55);

    float3 black = float3(0.008, 0.0035, 0.0015);
    float3 bronze = float3(0.30, 0.115, 0.028);
    float3 copper = float3(0.72, 0.30, 0.075);
    float3 silver = float3(0.96, 0.88, 0.72);
    float3 color = mix(black, bronze, 0.78 * depth);
    color = mix(color, copper, filament * (0.48 + 0.52 * bands));
    color = mix(color, silver, highlight);

    if (iteration == maxIterations) {
        color *= 0.50 + 0.50 * filament;
    }

    return float4(clamp(color, 0.0, 1.0), 1.0);
}

static float4 embossedMetalColor(
    float x0,
    float y0,
    constant Uniforms& uniforms
) {
    float stepY = max(uniforms.scale / 900.0, 1e-9);
    float stepX = stepY * uniforms.aspectRatio;
    uint centerIteration = fractalIteration(
        uniforms.fractalMode, x0, y0, uniforms.maxIterations
    );
    uint xIteration = fractalIteration(
        uniforms.fractalMode, x0 + stepX, y0, uniforms.maxIterations
    );
    uint yIteration = fractalIteration(
        uniforms.fractalMode, x0, y0 + stepY, uniforms.maxIterations
    );

    float denominator = float(max(uniforms.maxIterations, 1u));
    float height = sqrt(float(centerIteration) / denominator);
    float reliefScale = 12.0 + 60.0 * clamp(
        uniforms.doodadsStructure,
        0.0,
        1.0
    );
    float dx = (sqrt(float(xIteration) / denominator) - height) * reliefScale;
    float dy = (sqrt(float(yIteration) / denominator) - height) * reliefScale;
    float3 normal = normalize(float3(-dx, -dy, 1.0));
    float diffuse = clamp(
        dot(normal, normalize(float3(-0.48, 0.40, 0.78))),
        0.0,
        1.0
    );
    float rim = pow(clamp(1.0 - normal.z, 0.0, 1.0), 1.35);
    float contour = pow(
        0.5 + 0.5 * cos(52.0 * sqrt(max(height, 0.0))),
        7.0
    );
    float body = 0.10 + 0.48 * pow(height, 0.60);
    float light = 0.18 + 0.82 * diffuse;
    float3 color = float3(
        (0.10 + 0.62 * body) * light + 0.48 * rim + 0.32 * contour,
        (0.105 + 0.47 * body) * light + 0.36 * rim + 0.24 * contour,
        (0.11 + 0.29 * body) * light + 0.22 * rim + 0.15 * contour
    );

    if (centerIteration == uniforms.maxIterations) {
        color *= float3(0.30, 0.28, 0.25);
    }

    return float4(clamp(color, 0.0, 1.0), 1.0);
}

static float4 guillocheColor(
    float x0,
    float y0,
    uint mode,
    uint maxIterations,
    float engraving
) {
    float2 z = mode == 1 ? float2(x0, y0) : float2(0.0);
    float2 c = mode == 1 ? float2(-0.8, 0.156) : float2(x0, y0);
    uint exponent = mode == 21 ? 2 : (mode == 11 ? 4 : (mode == 12 ? 3 : (mode >= 13 && mode <= 20 ? mode - 8 : 2)));
    float density = 5.0 + 10.0 * clamp(engraving, 0.0, 1.0);
    float minimumLine = 1e10;
    float closestIteration = 0.0;
    uint iteration = 0u;

    for (; iteration < maxIterations; ++iteration) {
        float2 power = z;
        for (uint p = 1; p < exponent; ++p) {
            power = float2(
                power.x * z.x - power.y * z.y,
                power.x * z.y + power.y * z.x
            );
        }
        z = power + c;

        float radius = max(length(z), 1e-8);
        float angle = atan2(z.y, z.x);
        float logarithmicRadius = log(radius + 0.04);
        float threadA = abs(sin(density * angle + 2.8 * logarithmicRadius));
        float threadB = abs(sin((density + 3.0) * angle - 3.6 * logarithmicRadius));
        float rosette = abs(
            radius - 0.34 - 0.075 * cos((density - 1.0) * angle)
        );
        float lineDistance = min(
            rosette * 3.0,
            min(threadA, threadB) * radius * 0.16
        );

        if (lineDistance < minimumLine) {
            minimumLine = lineDistance;
            closestIteration = float(iteration);
        }

        if (dot(z, z) > 256.0) {
            break;
        }
    }

    float ink = exp(
        -(34.0 + 30.0 * engraving) * sqrt(max(minimumLine, 0.0))
    );
    float weave = 0.5 + 0.5 * cos(
        0.44 * closestIteration
        + 30.0 * pow(max(minimumLine, 1e-8), 0.24)
    );
    float fineLine = pow(clamp(ink, 0.0, 1.0), 2.5);
    float paper = pow(clamp(1.0 - ink, 0.0, 1.0), 1.4);
    float3 color = float3(
        0.022 + 0.12 * paper + fineLine * (0.68 + 0.48 * weave),
        0.032 + 0.14 * paper + fineLine * (0.46 + 0.44 * weave),
        0.044 + 0.16 * paper + fineLine * (0.20 + 0.30 * weave)
    );

    if (iteration == maxIterations) {
        color *= float3(0.50, 0.56, 0.64);
    }

    return float4(clamp(color, 0.0, 1.0), 1.0);
}

static float4 spheroidGlassColor(
    float x0,
    float y0,
    uint mode,
    uint maxIterations,
    float glass
) {
    float2 z = mode == 1 ? float2(x0, y0) : float2(0.0);
    float2 c = mode == 1 ? float2(-0.8, 0.156) : float2(x0, y0);
    uint exponent = mode == 21 ? 2 : (mode == 11 ? 4 : (mode == 12 ? 3 : (mode >= 13 && mode <= 20 ? mode - 8 : 2)));
    float sphereRadius = 0.24 + 0.18 * clamp(glass, 0.0, 1.0);
    float closestShell = 1e10;
    float2 closestPoint = float2(0.0);
    float closestIteration = 0.0;
    uint iteration = 0u;

    for (; iteration < maxIterations; ++iteration) {
        float2 power = z;
        for (uint p = 1; p < exponent; ++p) {
            power = float2(
                power.x * z.x - power.y * z.y,
                power.x * z.y + power.y * z.x
            );
        }
        z = power + c;

        float shell = abs(length(z) - sphereRadius);
        if (shell < closestShell) {
            closestShell = shell;
            closestPoint = z;
            closestIteration = float(iteration);
        }

        if (dot(z, z) > 256.0) {
            break;
        }
    }

    float radialLength = max(length(closestPoint), 1e-8);
    float2 normalXY = closestPoint / radialLength;
    float shellRatio = clamp(closestShell / max(sphereRadius, 1e-8), 0.0, 1.0);
    float normalZ = sqrt(max(1.0 - shellRatio * shellRatio, 0.0));
    float diffuse = clamp(
        dot(float3(normalXY, normalZ), normalize(float3(-0.42, 0.36, 0.82))),
        0.0,
        1.0
    );
    float rim = pow(clamp(1.0 - normalZ, 0.0, 1.0), 1.7);
    float lens = exp(-(18.0 + 24.0 * glass) * closestShell);
    float caustic = pow(
        0.5 + 0.5 * cos(0.38 * closestIteration - 13.0 * normalZ),
        8.0
    ) * lens;
    float body = 0.025 + 0.14 * lens;
    float3 color = float3(
        body * (0.40 + 0.60 * diffuse) + 0.46 * rim + 0.76 * caustic,
        (body + 0.10 * lens) * (0.42 + 0.58 * diffuse) + 0.58 * rim + 0.84 * caustic,
        (body + 0.16 * lens) * (0.45 + 0.55 * diffuse) + 0.62 * rim + 0.76 * caustic
    );

    if (iteration == maxIterations) {
        color *= float3(0.42, 0.56, 0.64);
    }

    return float4(clamp(color, 0.0, 1.0), 1.0);
}

static float4 quantumGlassColor(
    float x0,
    float y0,
    uint mode,
    uint maxIterations,
    float glass
) {
    float2 z = mode == 1 ? float2(x0, y0) : float2(0.0);
    float2 c = mode == 1 ? float2(-0.8, 0.156) : float2(x0, y0);
    uint exponent = mode == 21 ? 2 : (mode == 11 ? 4 : (mode == 12 ? 3 : (mode >= 13 && mode <= 20 ? mode - 8 : 2)));
    float sphereRadius = 0.24 + 0.18 * clamp(glass, 0.0, 1.0);
    float closestShell = 1e10;
    float2 closestPoint = float2(0.0);
    float closestIteration = 0.0;
    uint iteration = 0u;

    for (; iteration < maxIterations; ++iteration) {
        float2 power = z;
        for (uint p = 1; p < exponent; ++p) {
            power = float2(
                power.x * z.x - power.y * z.y,
                power.x * z.y + power.y * z.x
            );
        }
        z = power + c;

        float shell = abs(length(z) - sphereRadius);
        if (shell < closestShell) {
            closestShell = shell;
            closestPoint = z;
            closestIteration = float(iteration);
        }

        if (dot(z, z) > 256.0) {
            break;
        }
    }

    float radialLength = max(length(closestPoint), 1e-8);
    float2 normalXY = closestPoint / radialLength;
    float shellRatio = clamp(closestShell / max(sphereRadius, 1e-8), 0.0, 1.0);
    float normalZ = sqrt(max(1.0 - shellRatio * shellRatio, 0.0));
    float diffuse = clamp(
        dot(float3(normalXY, normalZ), normalize(float3(-0.46, 0.30, 0.84))),
        0.0,
        1.0
    );
    float lens = exp(-(18.0 + 24.0 * glass) * closestShell);
    float rim = pow(clamp(1.0 - normalZ, 0.0, 1.0), 1.45);
    float phase = 0.5 + 0.5 * cos(
        0.52 * closestIteration + 18.0 * closestShell
    );
    float hotEdge = pow(lens * phase, 2.4);
    float coldEdge = pow(lens * (1.0 - phase), 2.0);
    float3 color = float3(
        0.008 + 0.10 * lens * diffuse + 0.34 * rim + 1.00 * hotEdge + 0.18 * coldEdge,
        0.014 + 0.28 * lens * diffuse + 0.48 * rim + 0.58 * hotEdge + 0.62 * coldEdge,
        0.032 + 0.48 * lens * diffuse + 0.70 * rim + 0.20 * hotEdge + 0.92 * coldEdge
    );

    if (iteration == maxIterations) {
        color *= float3(0.42, 0.50, 0.64);
    }

    return float4(clamp(color, 0.0, 1.0), 1.0);
}

static float4 orbitalWavesColor(
    float x0,
    float y0,
    uint mode,
    uint maxIterations,
    float waves
) {
    float2 z = mode == 1 ? float2(x0, y0) : float2(0.0);
    float2 c = mode == 1 ? float2(-0.8, 0.156) : float2(x0, y0);
    uint exponent = mode == 21 ? 2 : (mode == 11 ? 4 : (mode == 12 ? 3 : (mode >= 13 && mode <= 20 ? mode - 8 : 2)));
    float frequency = 8.0 + 20.0 * clamp(waves, 0.0, 1.0);
    float closest = 1e10;
    float closestPhase = 0.0;
    uint closestIteration = 0;
    uint iteration = 0;

    while (iteration < maxIterations) {
        float2 powered = z;
        for (uint power = 1; power < exponent; power++) {
            powered = float2(
                powered.x * z.x - powered.y * z.y,
                powered.x * z.y + powered.y * z.x
            );
        }
        z = powered + c;
        float radius = max(length(z), 1e-8);
        float angle = atan2(z.y, z.x);
        float phase = frequency * log(radius + 0.06)
            + (3.0 + 5.0 * waves) * angle
            - 0.24 * float(iteration);
        float distance = abs(sin(phase)) * min(radius, 1.0);
        if (distance < closest) {
            closest = distance;
            closestPhase = phase;
            closestIteration = iteration;
        }
        iteration++;
        if (dot(z, z) > 256.0) break;
    }

    float wave = exp(-(30.0 + 34.0 * waves) * sqrt(max(closest, 0.0)));
    float crest = pow(wave, 2.2);
    float interference = 0.5 + 0.5 * cos(0.38 * float(closestIteration) + 2.0 * closestPhase);
    float hot = pow(crest * interference, 2.2);
    float cold = pow(crest * (1.0 - interference), 1.7);
    float3 color = float3(
        0.018 + 0.26 * wave + 1.05 * hot + 0.20 * cold,
        0.034 + 0.62 * wave + 0.72 * hot + 0.88 * cold,
        0.072 + 0.95 * wave + 0.30 * hot + 1.12 * cold
    );
    if (iteration == maxIterations) color *= float3(0.72);
    return float4(clamp(color, 0.0, 1.0), 1.0);
}

static float4 quantumTrapsColor(
    float x0,
    float y0,
    uint mode,
    uint maxIterations,
    float interference
) {
    float2 z = mode == 1 ? float2(x0, y0) : float2(0.0);
    float2 c = mode == 1 ? float2(-0.8, 0.156) : float2(x0, y0);
    uint exponent = mode == 21 ? 2 : (mode == 11 ? 4 : (mode == 12 ? 3 : (mode >= 13 && mode <= 20 ? mode - 8 : 2)));
    float separation = 0.08 + 0.24 * clamp(interference, 0.0, 1.0);
    float closest = 1e10;
    float secondClosest = 1e10;
    float2 closestPoint = float2(0.0);
    float closestRadius = 0.28;
    float closestIteration = 0.0;
    uint iteration = 0u;

    for (; iteration < maxIterations; ++iteration) {
        float2 power = z;
        for (uint p = 1; p < exponent; ++p) {
            power = float2(
                power.x * z.x - power.y * z.y,
                power.x * z.y + power.y * z.x
            );
        }
        z = power + c;

        for (uint trapIndex = 0; trapIndex < 3; ++trapIndex) {
            float2 center = trapIndex == 0
                ? float2(-separation, 0.0)
                : trapIndex == 1
                    ? float2(separation, 0.0)
                    : float2(0.0, separation * 0.86);
            float radius = trapIndex == 0 ? 0.28 : (trapIndex == 1 ? 0.22 : 0.18);
            float2 localPoint = z - center;
            float distance = abs(length(localPoint) - radius);

            if (distance < closest) {
                secondClosest = closest;
                closest = distance;
                closestPoint = localPoint;
                closestRadius = radius;
                closestIteration = float(iteration);
            } else if (distance < secondClosest) {
                secondClosest = distance;
            }
        }

        if (dot(z, z) > 256.0) {
            break;
        }
    }

    float radialLength = max(length(closestPoint), 1e-8);
    float2 normalXY = closestPoint / radialLength;
    float shellRatio = clamp(closest / closestRadius, 0.0, 1.0);
    float normalZ = sqrt(max(1.0 - shellRatio * shellRatio, 0.0));
    float diffuse = clamp(
        dot(float3(normalXY, normalZ), normalize(float3(-0.46, 0.30, 0.84))),
        0.0,
        1.0
    );
    float lens = exp(-(20.0 + 22.0 * interference) * closest);
    float overlap = exp(
        -(34.0 - 16.0 * interference) * abs(secondClosest - closest)
    ) * lens;
    float rim = pow(clamp(1.0 - normalZ, 0.0, 1.0), 1.45);
    float phase = 0.5 + 0.5 * cos(
        0.52 * closestIteration + 18.0 * closest
    );
    float hotEdge = pow(overlap * phase, 2.4);
    float coldEdge = pow(lens * (1.0 - phase), 2.0);
    float3 color = float3(
        0.008 + 0.10 * lens * diffuse + 0.34 * rim + 1.00 * hotEdge + 0.18 * coldEdge,
        0.014 + 0.28 * lens * diffuse + 0.48 * rim + 0.58 * hotEdge + 0.62 * coldEdge,
        0.032 + 0.48 * lens * diffuse + 0.70 * rim + 0.20 * hotEdge + 0.92 * coldEdge
    );

    if (iteration == maxIterations) {
        color *= float3(0.42, 0.50, 0.64);
    }

    return float4(clamp(color, 0.0, 1.0), 1.0);
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

static float marbleHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float marbleNoise(float2 p) {
    float2 cell = floor(p);
    float2 local = fract(p);
    float2 smoothLocal = local * local * (3.0 - 2.0 * local);
    float a = marbleHash(cell);
    float b = marbleHash(cell + float2(1.0, 0.0));
    float c = marbleHash(cell + float2(0.0, 1.0));
    float d = marbleHash(cell + float2(1.0, 1.0));
    return mix(mix(a, b, smoothLocal.x), mix(c, d, smoothLocal.x), smoothLocal.y);
}

static float marbleFBM(float2 p) {
    float value = 0.0;
    float amplitude = 0.55;
    for (uint octave = 0; octave < 4; ++octave) {
        value += amplitude * marbleNoise(p);
        p = float2(1.63 * p.x - 1.17 * p.y, 1.17 * p.x + 1.63 * p.y) + 4.31;
        amplitude *= 0.5;
    }
    return value;
}

static float3 pearlInteriorColor(float2 uv) {
    float x = uv.x * 2.0 - 1.0;
    float y = uv.y * 2.0 - 1.0;
    float radius = min(length(float2(x, y)), 1.35);
    float2 p = float2(x, y) * 2.8 + float2(7.3, 11.9);
    float2 warp = float2(marbleFBM(p + 3.7), marbleFBM(p - 5.1)) - 0.5;
    float stone = marbleFBM(p + 2.2 * warp);
    float detail = marbleFBM(p * 2.7 - 1.4 * warp);
    float vein = pow(1.0 - smoothstep(0.035, 0.18, abs(stone - 0.53)), 1.45);
    float fineVein = pow(1.0 - smoothstep(0.018, 0.095, abs(detail - 0.49)), 1.8);
    float facet = 0.5 + 0.5 * cos(13.0 * x - 9.0 * y + 6.0 * radius);
    float highlight = exp(-18.0 * (x - y + 0.28) * (x - y + 0.28));
    float edge = smoothstep(0.48, 1.18, radius);
    float cloudy = (stone - 0.5) * 0.09;
    float tone = 0.88 + cloudy + 0.060 * facet + 0.12 * highlight
               - 0.20 * vein - 0.065 * fineVein - 0.10 * edge;
    float3 color = float3(tone * 1.015, tone * 1.020, tone * 1.010);
    return clamp(color, 0.0, 1.0);
}

static float3 motherOfPearlInteriorColor(float2 uv) {
    float x = uv.x * 2.0 - 1.0;
    float y = uv.y * 2.0 - 1.0;
    float radius = min(length(float2(x, y)), 1.35);
    float2 p = float2(x, y) * 2.8 + float2(7.3, 11.9);
    float2 warp = float2(marbleFBM(p + 3.7), marbleFBM(p - 5.1)) - 0.5;
    float stone = marbleFBM(p + 2.2 * warp);
    float detail = marbleFBM(p * 2.7 - 1.4 * warp);
    float vein = pow(1.0 - smoothstep(0.012, 0.055, abs(detail - 0.49)), 2.2);
    float highlight = exp(-16.0 * (x - y + 0.28) * (x - y + 0.28));
    float edge = smoothstep(0.50, 1.18, radius);
    float3 ivory = float3(0.91, 0.90, 0.87) + (stone - 0.5) * 0.08;
    float3 rose = float3(1.0, 0.78, 0.84);
    float3 ice = float3(0.72, 0.88, 1.0);
    float3 champagne = float3(1.0, 0.86, 0.55);
    float roseSheen = 0.5 + 0.5 * sin(5.2 * stone + 3.3 * x - 1.7 * y);
    float iceSheen = 0.5 + 0.5 * sin(6.1 * detail - 2.1 * x + 4.2 * y);
    float3 color = mix(ivory, rose, 0.13 * roseSheen);
    color = mix(color, ice, 0.12 * iceSheen);
    color = mix(color, champagne, 0.10 * highlight + 0.18 * vein);
    color -= 0.055 * edge;
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

static float4 renderMandelbrotPlateau(
    float2 uv,
    constant Uniforms& uniforms
) {
    float tiltRadians = clamp(uniforms.plateauTiltDegrees, 80.0, 90.0) * (M_PI_F / 180.0);
    float inclination = cos(tiltRadians);
    float verticalProjection = sin(tiltRadians);
    float2 groundUV = float2(
        uv.x,
        0.5 + (uv.y - 0.5) / verticalProjection
    );
    float lift = 0.30 * inclination;
    float2 topUV = groundUV - float2(0.0, lift);

    float sampleX = uniforms.centerX
                  + (topUV.x - 0.5) * uniforms.scale * uniforms.aspectRatio;
    float sampleY = uniforms.centerY
                  + (0.5 - topUV.y) * uniforms.scale;
    uint topIteration = mandelbrotIterationOnly(
        sampleX,
        sampleY,
        uniforms.maxIterations
    );
    bool topHit = topIteration == uniforms.maxIterations;

    float groundX = uniforms.centerX
                  + (groundUV.x - 0.5) * uniforms.scale * uniforms.aspectRatio;
    float groundY = uniforms.centerY
                  + (0.5 - groundUV.y) * uniforms.scale;
    uint groundIteration = mandelbrotIterationOnly(
        groundX,
        groundY,
        uniforms.maxIterations
    );
    bool groundHit = groundIteration == uniforms.maxIterations;
    bool middleHit = false;
    for (uint middleStep = 1; middleStep <= 2; middleStep += 1) {
        float middlePosition = float(middleStep) / 3.0;
        float2 middleUV = mix(groundUV, topUV, middlePosition);
        float middleX = uniforms.centerX
                      + (middleUV.x - 0.5) * uniforms.scale * uniforms.aspectRatio;
        float middleY = uniforms.centerY
                      + (0.5 - middleUV.y) * uniforms.scale;
        middleHit = middleHit
            || mandelbrotIterationOnly(
                middleX,
                middleY,
                uniforms.maxIterations
            ) == uniforms.maxIterations;
    }

    if (topHit) {
        float3 topColor = auricInteriorColor(topUV);
        float sheen = smoothstep(-0.75, 0.65, topUV.x - topUV.y);
        topColor *= 0.96 + sheen * inclination * 0.13;
        return float4(clamp(topColor, 0.0, 1.0), 1.0);
    }

    // The part of the original silhouette not covered by the lifted copy is
    // the visible side. This endpoint construction needs only two fractal
    // evaluations per pixel and stays practical at deep zoom levels.
    if (groundHit || middleHit) {
        float wallLight = 0.72 + 0.22 * smoothstep(0.0, 1.0, uv.x);
        float3 wallColor = float3(0.58, 0.31, 0.065) * wallLight;
        return float4(wallColor, 1.0);
    }

    float t = float(groundIteration) / float(max(uniforms.maxIterations, 1u));
    float k = sqrt(t);
    float ridge = 0.5 + 0.5 * sin(38.0 * k);
    float glow = exp(-7.0 * abs(k - 0.45));
    return float4(paletteColor(t, ridge, glow, 13), 1.0);
}

fragment float4 plateau_source_fragment(
    VertexOut in [[stage_in]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    float2 uv = in.uv;
    float x0 = uniforms.centerX
             + (uv.x - 0.5) * uniforms.scale * uniforms.aspectRatio;
    float y0 = uniforms.centerY
             + (0.5 - uv.y) * uniforms.scale;
    uint iteration = mandelbrotIterationOnly(x0, y0, uniforms.maxIterations);
    bool inside = iteration == uniforms.maxIterations;

    if (inside) {
        return float4(auricInteriorColor(uv), 1.0);
    }

    float t = float(iteration) / float(max(uniforms.maxIterations, 1u));
    float k = sqrt(t);
    float ridge = 0.5 + 0.5 * sin(38.0 * k);
    float glow = exp(-7.0 * abs(k - 0.45));
    return float4(paletteColor(t, ridge, glow, 13), 0.0);
}

fragment float4 plateau_composite_fragment(
    VertexOut in [[stage_in]],
    constant Uniforms& uniforms [[buffer(0)]],
    texture2d<float> sourceTexture [[texture(0)]]
) {
    constexpr sampler imageSampler(
        coord::normalized,
        address::clamp_to_edge,
        filter::linear
    );

    float tiltRadians = clamp(
        uniforms.plateauTiltDegrees,
        80.0,
        90.0
    ) * (M_PI_F / 180.0);
    float inclination = cos(tiltRadians);
    float verticalProjection = sin(tiltRadians);
    float2 groundUV = float2(
        in.uv.x,
        0.5 + (in.uv.y - 0.5) / verticalProjection
    );
    float2 topUV = groundUV - float2(0.0, 0.30 * inclination);
    float4 topSample = sourceTexture.sample(imageSampler, topUV);

    if (topSample.a > 0.5) {
        float sheen = smoothstep(-0.75, 0.65, topUV.x - topUV.y);
        return float4(
            clamp(topSample.rgb * (0.96 + sheen * inclination * 0.13), 0.0, 1.0),
            1.0
        );
    }

    float wallMask = 0.0;
    for (uint wallStep = 0; wallStep <= 32; wallStep += 1) {
        float wallPosition = float(wallStep) / 32.0;
        float2 wallUV = mix(groundUV, topUV, wallPosition);
        wallMask = max(
            wallMask,
            sourceTexture.sample(imageSampler, wallUV).a
        );
    }

    if (wallMask > 0.08) {
        float wallLight = 0.72 + 0.22 * smoothstep(0.0, 1.0, in.uv.x);
        return float4(float3(0.58, 0.31, 0.065) * wallLight, 1.0);
    }

    float3 groundColor = sourceTexture.sample(imageSampler, groundUV).rgb;
    return float4(groundColor, 1.0);
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

    if (uniforms.fractalMode == 22) {
        return renderMandelbrotPlateau(in.uv, uniforms);
    }
    
    if (uniforms.fractalMode == 8) {
        return renderNewton(in.uv, uniforms);
    }
    
    float2 uv = in.uv;
    
    float x0 = uniforms.centerX + (uv.x - 0.5) * uniforms.scale * uniforms.aspectRatio;
    float y0 = uniforms.centerY + (0.5 - uv.y) * uniforms.scale;

    if (uniforms.fractalPalette == 23 &&
        (uniforms.fractalMode == 0 ||
         uniforms.fractalMode == 1 ||
         (uniforms.fractalMode >= 11 && uniforms.fractalMode <= 21))) {
        return quantumGlassColor(
            x0,
            y0,
            uniforms.fractalMode,
            uniforms.maxIterations,
            uniforms.doodadsStructure
        );
    }

    if (uniforms.fractalPalette == 22 &&
        (uniforms.fractalMode == 0 ||
         uniforms.fractalMode == 1 ||
         (uniforms.fractalMode >= 11 && uniforms.fractalMode <= 21))) {
        return orbitalWavesColor(
            x0,
            y0,
            uniforms.fractalMode,
            uniforms.maxIterations,
            uniforms.doodadsStructure
        );
    }

    if (uniforms.fractalPalette == 21 &&
        (uniforms.fractalMode == 0 ||
         uniforms.fractalMode == 1 ||
         (uniforms.fractalMode >= 11 && uniforms.fractalMode <= 21))) {
        return quantumTrapsColor(
            x0,
            y0,
            uniforms.fractalMode,
            uniforms.maxIterations,
            uniforms.doodadsStructure
        );
    }

    if (uniforms.fractalPalette == 20 &&
        (uniforms.fractalMode == 0 ||
         uniforms.fractalMode == 1 ||
         (uniforms.fractalMode >= 11 && uniforms.fractalMode <= 21))) {
        return spheroidGlassColor(
            x0,
            y0,
            uniforms.fractalMode,
            uniforms.maxIterations,
            uniforms.doodadsStructure
        );
    }

    if (uniforms.fractalPalette == 19 &&
        (uniforms.fractalMode == 0 ||
         uniforms.fractalMode == 1 ||
         (uniforms.fractalMode >= 11 && uniforms.fractalMode <= 21))) {
        return guillocheColor(
            x0,
            y0,
            uniforms.fractalMode,
            uniforms.maxIterations,
            uniforms.doodadsStructure
        );
    }

    if (uniforms.fractalPalette == 18 &&
        (uniforms.fractalMode == 0 ||
         uniforms.fractalMode == 1 ||
         (uniforms.fractalMode >= 11 && uniforms.fractalMode <= 21))) {
        return embossedMetalColor(x0, y0, uniforms);
    }

    if (uniforms.fractalPalette == 17 &&
        (uniforms.fractalMode == 0 ||
         uniforms.fractalMode == 1 ||
         (uniforms.fractalMode >= 11 && uniforms.fractalMode <= 21))) {
        return metallicDoodadsColor(
            x0,
            y0,
            uniforms.fractalMode,
            uniforms.maxIterations,
            uniforms.doodadsStructure,
            uniforms.doodadsComplexity,
            uniforms.doodadsCurl
        );
    }
    
    uint iteration = fractalIteration(
        uniforms.fractalMode,
        x0,
        y0,
        uniforms.maxIterations
    );
    
    if (iteration == uniforms.maxIterations) {
        if (uniforms.fractalPalette == 16 &&
            (uniforms.fractalMode == 0 || uniforms.fractalMode == 6 ||
             (uniforms.fractalMode >= 11 && uniforms.fractalMode <= 21))) {
            return float4(motherOfPearlInteriorColor(uv), 1.0);
        }

        if (uniforms.fractalPalette == 15 &&
            (uniforms.fractalMode == 0 || uniforms.fractalMode == 6 ||
             (uniforms.fractalMode >= 11 && uniforms.fractalMode <= 21))) {
            return float4(pearlInteriorColor(uv), 1.0);
        }

        if (uniforms.fractalPalette == 13 &&
            (uniforms.fractalMode == 0 || uniforms.fractalMode == 6 ||
             (uniforms.fractalMode >= 11 && uniforms.fractalMode <= 21))) {
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
    
    bool usesStableColorScale = uniforms.colorNormalizationIterations > 0u;
    uint normalizationIterations = usesStableColorScale
        ? uniforms.colorNormalizationIterations
        : uniforms.maxIterations;
    float rawT = float(iteration) / float(max(normalizationIterations, 1u));
    // Preserve the complete starting palette, then repeat its fixed phase for
    // escape times beyond that range instead of saturating relief above 1.0.
    float t = usesStableColorScale && rawT > 1.0 ? fract(rawT) : rawT;
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
