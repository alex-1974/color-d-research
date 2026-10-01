// R5.1 research probe for color-d #161.
//
// Standalone by design: this file carries its own Oklab -> linear-sRGB
// reference equations and does not import the production color-d library.

import std.math : cos, sin, PI;
import std.stdio : writefln;

struct Rgb(T)
{
    T r;
    T g;
    T b;
}

Rgb!T oklchToLinearSRgb(T)(T L, T C, T hueDegrees)
{
    const T radians = hueDegrees * cast(T)(PI / 180.0L);
    const T a = C * cos(radians);
    const T b = C * sin(radians);

    const T l_ = L + cast(T)0.3963377774 * a + cast(T)0.2158037573 * b;
    const T m_ = L - cast(T)0.1055613458 * a - cast(T)0.0638541728 * b;
    const T s_ = L - cast(T)0.0894841775 * a - cast(T)1.2914855480 * b;

    const T l = l_ * l_ * l_;
    const T m = m_ * m_ * m_;
    const T s = s_ * s_ * s_;

    return Rgb!T(
         cast(T)4.0767416621 * l - cast(T)3.3077115913 * m + cast(T)0.2309699292 * s,
        -cast(T)1.2684380046 * l + cast(T)2.6097574011 * m - cast(T)0.3413193965 * s,
        -cast(T)0.0041960863 * l - cast(T)0.7034186147 * m + cast(T)1.7076147010 * s
    );
}

bool inUnitCube(T)(Rgb!T c)
{
    return c.r >= 0 && c.r <= 1 &&
           c.g >= 0 && c.g <= 1 &&
           c.b >= 0 && c.b <= 1;
}

struct Boundary(T)
{
    T inside;
    T outside;
    size_t growthSteps;
    size_t bisections;
}

Boundary!T boundary(T)(T L, T hueDegrees)
{
    assert(L > 0 && L < 1);

    T low = 0;
    T high = cast(T)0.125;
    size_t growth;

    while (inUnitCube(oklchToLinearSRgb(L, high, hueDegrees)))
    {
        low = high;
        high *= 2;
        ++growth;
        assert(high == high && high < T.infinity);
    }

    size_t iterations;
    enum maxIterations = is(T == float) ? 64 : 128;

    foreach (_; 0 .. maxIterations)
    {
        const T mid = low + (high - low) / 2;
        if (mid == low || mid == high)
            break;

        if (inUnitCube(oklchToLinearSRgb(L, mid, hueDegrees)))
            low = mid;
        else
            high = mid;

        ++iterations;
    }

    return Boundary!T(low, high, growth, iterations);
}

void main()
{
    immutable double[] lightnesses = [0.01, 0.10, 0.25, 0.50, 0.75, 0.90, 0.99];
    immutable double[] hues = [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330];

    foreach (L; lightnesses)
    foreach (h; hues)
    {
        const b = boundary!double(L, h);
        assert(inUnitCube(oklchToLinearSRgb(L, b.inside, h)));
        assert(!inUnitCube(oklchToLinearSRgb(L, b.outside, h)));

        writefln("L=%5.2f h=%6.1f C=[%.17g, %.17g] width=%.3g grow=%s bisect=%s",
            L, h, b.inside, b.outside, b.outside - b.inside,
            b.growthSteps, b.bisections);
    }

    // Periodicity sanity checks use the same independent baseline.
    foreach (h; hues)
    {
        const a = boundary!double(0.5, h);
        const b = boundary!double(0.5, h + 360);
        assert(a.inside == b.inside || (a.inside - b.inside < 1e-14 && b.inside - a.inside < 1e-14));
    }
}
