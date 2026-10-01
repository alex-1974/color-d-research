// R5.2 research probe for color-d #161.
//
// Standalone correctness oracle: no production color-d imports.
// Measures double/float bracketing behavior over a dense L/h grid.

import std.algorithm : max;
import std.math : abs, cos, sin, PI;
import std.stdio : writefln;

struct Rgb(T) { T r; T g; T b; }

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
        -cast(T)0.0041960863 * l - cast(T)0.7034186147 * m + cast(T)1.7076147010 * s);
}

bool inUnitCube(T)(Rgb!T c)
{
    return c.r >= 0 && c.r <= 1 && c.g >= 0 && c.g <= 1 && c.b >= 0 && c.b <= 1;
}

struct Boundary(T) { T inside; T outside; size_t growthSteps; size_t bisections; }

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
        if (mid == low || mid == high) break;
        if (inUnitCube(oklchToLinearSRgb(L, mid, hueDegrees))) low = mid;
        else high = mid;
        ++iterations;
    }
    return Boundary!T(low, high, growth, iterations);
}

void main()
{
    size_t samples;
    size_t maxDoubleBisect, maxFloatBisect, maxGrowth;
    double maxFloatAbsError = 0.0;
    double maxFloatRelError = 0.0;
    double worstL = 0.0, worstH = 0.0, worstDouble = 0.0, worstFloat = 0.0;

    // 99 lightness slices x 360 integer-degree hues = 35,640 samples.
    foreach (li; 1 .. 100)
    {
        const double L = li / 100.0;
        foreach (hi; 0 .. 360)
        {
            const double h = cast(double) hi;
            const bd = boundary!double(L, h);
            const bf = boundary!float(cast(float)L, cast(float)h);

            assert(inUnitCube(oklchToLinearSRgb(L, bd.inside, h)));
            assert(!inUnitCube(oklchToLinearSRgb(L, bd.outside, h)));
            assert(inUnitCube(oklchToLinearSRgb(cast(float)L, bf.inside, cast(float)h)));
            assert(!inUnitCube(oklchToLinearSRgb(cast(float)L, bf.outside, cast(float)h)));

            const double f = cast(double) bf.inside;
            const double absError = abs(f - bd.inside);
            const double relError = absError / bd.inside;

            if (absError > maxFloatAbsError)
            {
                maxFloatAbsError = absError;
                maxFloatRelError = relError;
                worstL = L; worstH = h; worstDouble = bd.inside; worstFloat = f;
            }

            maxDoubleBisect = max(maxDoubleBisect, bd.bisections);
            maxFloatBisect = max(maxFloatBisect, bf.bisections);
            maxGrowth = max(maxGrowth, max(bd.growthSteps, bf.growthSteps));
            ++samples;
        }
    }

    writefln("samples=%s", samples);
    writefln("max double bisections=%s", maxDoubleBisect);
    writefln("max float bisections=%s", maxFloatBisect);
    writefln("max growth steps=%s", maxGrowth);
    writefln("max float-vs-double abs error=%.17g", maxFloatAbsError);
    writefln("relative error at abs-error worst case=%.17g", maxFloatRelError);
    writefln("worst abs-error sample L=%.17g h=%.17g double=%.17g float=%.17g",
        worstL, worstH, worstDouble, worstFloat);

    // Periodicity across representative non-axis hues.
    foreach (h; [0.0, 17.0, 91.0, 179.0, 263.0, 359.0])
    {
        const a = boundary!double(0.5, h);
        const b = boundary!double(0.5, h + 360.0);
        assert(abs(a.inside - b.inside) <= 1e-14);
    }
}
