#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// Dots hero shaders — a small family of GPU brand backdrops sharing the same
// value-noise field, switchable at runtime. Dots is white light; work is the
// spectrum.
//
//   dotsHalftone — dot-matrix halftone (circles — the brand metaphor);
//                   Conway life breathes the dots and the finger stirs
//                   white dye through them (the yuga.com hero, made of dots).
//   dotsMosaic   — circle lattice; cells flip filled <-> outline on a slow
//                   flowing field.
//
// Shared noise helpers (hash21 / valueNoise / fbm) back every field below.

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

static float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm(float2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 5; i++) {
        v += amp * valueNoise(p);
        p *= 2.02;
        amp *= 0.5;
    }
    return v;
}

// MARK: - Halftone

// The ambient field is Conway's Game of Life, simulated CPU-side on the
// white-capable lattice (see HalftoneLifeModel) and passed in as a board
// of smoothed per-cell energies — births swell in, deaths fade away.

// Polynomial smooth-min: unions SDFs with a `k`-wide liquid bridge, so
// nearby shapes melt into each other instead of just overlapping.
static float smin(float a, float b, float k) {
    float h = saturate(0.5 + 0.5 * (b - a) / k);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// The yuga.com hero as a pond: a fixed checkerboard lattice — ONLY every
// other tile can ever become white; the rest stay ink. One wave system
// drives everything. Ambient: Conway's Game of Life (`board` holds the
// smoothed cell energies, row-major with stride `boardCols`). Taps: drop
// a ripple AND plant an R-pentomino into the simulation. Drags: the
// comet — and the path kills cells, a finger wiped through the dish. `trail` is a flat
// [x, y, age, vx, vy, …] buffer of drag samples (pixels, seconds,
// pixels/second); `taps` is a flat [x, y, age, …] buffer of tap points;
// the counts are float counts.
[[ stitchable ]] half4 dotsHalftone(
    float2 position,
    half4 color,
    float2 size,
    float time,
    half4 bg,
    half4 dot,
    float gridRows,
    float2 touch,
    float touchStrength,
    device const float *trail,
    int trailCount,
    device const float *taps,
    int tapCount,
    float boardCols,
    device const float *board,
    int boardCount
) {
    float cell = size.y / gridRows;
    float2 grid = position / cell;
    float2 cellId = floor(grid);
    float aa = 1.6 / cell;

    // Gel factor: how gooey the tile union is at this pixel. It rises
    // with nearby drag energy (and rises faster the faster the drag), so
    // tiles around the finger morph into one another like a liquid and
    // the union hardens back to crisp tiles as the energy decays.
    float gel = 0.0;
    for (int i = 0; i + 4 < trailCount; i += 5) {
        float2 vel = float2(trail[i + 3], trail[i + 4]);
        float speed = length(vel);
        if (speed < 40.0) { continue; }
        float2 tp = float2(trail[i], trail[i + 1]);
        float prox = smoothstep(cell * 3.5, cell * 0.3, length(position - tp));
        gel = max(gel, prox * min(speed / 1200.0, 1.1) * exp(-trail[i + 2] * 2.6));
    }

    // Smooth-min union over the 3x3 cell neighbourhood. The blend is
    // always on: growing dots fuse corner-to-corner with their diagonal
    // (checkerboard) neighbours through smooth concave fillets, and at
    // high fill the leftover black gaps read as inverse dots (the
    // reference's figure/ground flip). Drag energy widens the bridge
    // further so tiles under the finger melt together like liquid.
    float dMin = 1e5;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            float2 nId = cellId + float2(dx, dy);

            // The white-capable lattice: every other tile, fixed forever.
            if (fract((nId.x + nId.y) * 0.5) < 0.25) { continue; }

            float2 nCenter = (nId + 0.5) * cell;

            // This tile's Life energy: alive colonies sit near full size
            // and fuse; dead space rests as tiny dots.
            float f = 0.0;
            int ix = int(nId.x);
            int iy = int(nId.y);
            if (ix >= 0 && iy >= 0 && ix < int(boardCols)) {
                int bi = iy * int(boardCols) + ix;
                if (bi >= 0 && bi < boardCount) {
                    f = board[bi] * 0.85;
                }
            }

            // Tap ripples: expanding circular crests that ADD into the
            // field, so crossing rings (and ring-meets-ambient-crest)
            // interfere constructively and bloom.
            float ripple = 0.0;
            for (int i = 0; i + 2 < tapCount; i += 3) {
                float age = taps[i + 2];
                if (age > 2.6) { continue; }
                float front = length(nCenter - float2(taps[i], taps[i + 1]))
                            - age * size.y * 0.55;
                float crest = exp(-front * front / (cell * cell * 5.0));
                ripple += crest * exp(-age * 1.5);
            }
            f = saturate(f + ripple * 0.85);

            float h = hash21(nId);

            // Comet response: a slow drag affects roughly one line of
            // tiles; speed widens the swath. Behind the head the radius
            // tightens and the energy decays — tiles shrink back with one
            // brief, small settling jiggle. A resting finger does nothing.
            float2 bend = float2(0.0);
            float grow = 0.0;
            for (int i = 0; i + 4 < trailCount; i += 5) {
                float2 vel = float2(trail[i + 3], trail[i + 4]);
                float speed = length(vel);
                if (speed < 40.0) { continue; }

                float age = trail[i + 2];
                float life = exp(-age * 3.0);

                float2 tp = float2(trail[i], trail[i + 1]);
                float dist = length(nCenter - tp);
                // Narrow lance when slow, wider when fast; the radius also
                // tapers as the sample ages — the comet's tail.
                float radius = cell * (1.3 + 2.4 * min(speed / 1500.0, 2.0))
                             * mix(0.55, 1.0, life);
                float prox = smoothstep(radius, radius * 0.15, dist);
                if (prox <= 0.0) { continue; }

                // Quiet at the head; a small jiggle only while settling.
                float wobble = 1.0 + 0.22 * sin(age * 13.0 + h * 6.2832)
                                    * smoothstep(0.04, 0.18, age);

                // Growth saturates fast, so even a slow drag clearly
                // swells the line it touches.
                grow = max(grow, min(speed / 700.0, 1.3) * prox * life * wobble);
                bend += (vel / speed) * (prox * exp(-age * 3.5)
                                         * cos(age * 12.0 + h * 1.2)
                                         * min(speed / 1500.0, 1.0) * 0.3);
            }
            float bendLen = length(bend);
            if (bendLen > 0.4) { bend *= 0.4 / bendLen; }

            // Drag swells tiles while it's over them; the tail relaxes.
            float halfExtent = min(mix(0.08, 0.92, f) + grow * 0.5, 1.15);
            float2 local = grid - (nId + 0.5) - bend;

            dMin = smin(dMin, length(local) - halfExtent, 0.22 + 0.35 * gel);
        }
    }
    float cov = saturate(0.5 - dMin / aa);

    half3 col = mix(bg.rgb, dot.rgb, half(cov));

    // Faint grain, matched to the other hero surfaces.
    float g = hash21(position + floor(time * 1.2));
    col += half3(half((g - 0.5) * 0.02));

    return half4(col, 1.0h);
}

// MARK: - Mosaic (glyph grid)

// Signed distance to a circle centered at the origin in cell units; `r` is
// the glyph half-size.
static float sdCircle(float2 p, float r) { return length(p) - r; }

// A lattice of dots. Cells flip between a filled disc and an outline ring as
// a slow flowing field sweeps through, with size breathing and a diagonal
// wave of white light passing over the forms.
[[ stitchable ]] half4 dotsMosaic(
    float2 position,
    half4 color,
    float2 size,
    float time,
    half4 deep,        // deep brand blue
    half4 brandBlue,   // system blue
    half4 glyphColor,  // paper white
    float rows,
    float2 touch,
    float touchStrength
) {
    float2 uv = position / size;
    float cell = size.y / rows;
    float2 grid = position / cell;
    float2 cellId = floor(grid);
    float2 local = fract(grid) - 0.5;            // cell-local, [-0.5, 0.5]
    float2 fp = (cellId + 0.5) * cell / size.y;  // normalized cell center

    float t = time * 0.10;

    // Life field: a slow domain-warped fBm — coherent in space (neighbours bloom
    // together, so clusters appear to spread) and moving in time (clusters
    // travel, grow, recede). The threshold turns it into birth -> growth -> death.
    float2 warp = float2(fbm(fp * 2.2 + t), fbm(fp * 2.2 - t + 9.0));
    float field = fbm(fp * 2.2 + warp * 1.3 + t * 0.7);
    // Spread the field for contrast. It can vary fully (so sizes breathe and
    // grow across regions), because the size floor below keeps even the troughs
    // clearly visible — no invisible voids.
    field = saturate((field - 0.45) * 1.9 + 0.5);
    float life = smoothstep(0.10, 0.70, field);

    // Touch stirs the grid: nearby cells bloom and churn faster.
    float2 touchN = touch / size.y;
    float near = touchStrength * smoothstep(0.32, 0.0, length(fp - touchN));
    life = saturate(life + near * 0.7);

    // Glyph size grows with life, but floored so a shape is ALWAYS clearly
    // visible — it ranges from a solid medium glyph up to full, never minuscule.
    float r = mix(0.17, 0.42, life);

    // Fill mode re-rolls per cell on a staggered slow cycle (fast near
    // touch): cells flip between a filled disc and an outline ring over
    // time — the random re-pick on rebirth, reduced to one glyph, two states.
    float cyc = floor(time * 0.32 + hash21(cellId) * 4.0 + near * 9.0);
    float fillRand = hash21(cellId + cyc * 13.0 + 0.5);

    float d = sdCircle(local, r);
    float sdf;
    if (fillRand < 0.5) {
        sdf = d;                                     // filled disc
    } else {
        float halfStroke = max(0.035, r * 0.18);     // outline ring, outer edge at r
        sdf = abs(d + halfStroke) - halfStroke;
    }
    // Crisp edge from the screen-space derivative (~1px), so glyphs are sharp,
    // not fuzzy.
    float aa = fwidth(sdf);
    float fill = smoothstep(aa, -aa, sdf);

    // Brand-blue field; white glyphs (kept bright even at the floor size so they
    // always read); a slow diagonal wave of light sweeping across the lattice.
    half3 bg = mix(deep.rgb, brandBlue.rgb, half(mix(0.55, 1.0, uv.y)));
    float wave = smoothstep(0.3, 1.0, sin((uv.x + uv.y) * 3.0 - time * 0.5));
    half3 glyph = glyphColor.rgb;
    half3 col = mix(bg, glyph, half(fill * (0.80 + 0.20 * life)));
    col += glyph * half(fill * wave * 0.35);

    return half4(col, 1.0h);
}
