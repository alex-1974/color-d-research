// R5.9 research probe for color-d #161.
//
// Final contract probe: independent sRGB boundary oracle, fixed-iteration
// candidate, scalar matrix, domain/failure semantics, periodicity and CTFE.
// Standalone by design: no production color-d imports.

import std.math : abs, cos, isFinite, sin, PI;
import std.stdio : writefln;

struct Rgb(T)
{
    T r;
    T g;
    T b;
}

struct Boundary(T)
{
    T inside;
    T outside;
}

struct Limit(T)
{
    T value;
    bool valid;
}

Rgb!T oklchToLinearSrgb(T)(T L, T C, T hueDegrees)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
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
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return c.r >= 0 && c.r <= 1 &&
           c.g >= 0 && c.g <= 1 &&
           c.b >= 0 && c.b <= 1;
}

Boundary!T ulpOracle(T)(T L, T hueDegrees)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    T low = 0;
    T high = cast(T)0.125;

    while (inUnitCube(oklchToLinearSrgb(L, high, hueDegrees)))
        high *= 2;

    foreach (_; 0 .. (is(T == float) ? 64 : 128))
    {
        const T mid = low + (high - low) / cast(T)2;
        if (mid == low || mid == high)
            break;

        if (inUnitCube(oklchToLinearSrgb(L, mid, hueDegrees)))
            low = mid;
        else
            high = mid;
    }

    return Boundary!T(low, high);
}

Boundary!T fixedBoundary(T)(T L, T hueDegrees, size_t iterations)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    T low = 0;
    T high = cast(T)0.125;

    while (inUnitCube(oklchToLinearSrgb(L, high, hueDegrees)))
        high *= 2;

    foreach (_; 0 .. iterations)
    {
        const T mid = low + (high - low) / cast(T)2;
        if (mid == low || mid == high)
            break;

        if (inUnitCube(oklchToLinearSrgb(L, mid, hueDegrees)))
            low = mid;
        else
            high = mid;
    }

    return Boundary!T(low, high);
}

Limit!T contractLimit(T)(T L, T hueDegrees)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    if (!isFinite(L) || !isFinite(hueDegrees) || L < 0 || L > 1)
        return Limit!T(T.nan, false);

    if (L == 0 || L == 1)
        return Limit!T(cast(T)0, true);

    return Limit!T(
        fixedBoundary(L, hueDegrees, is(T == float) ? 24 : 32).inside,
        true
    );
}

void checkScalar(T)(size_t iterations)
@safe
if (is(T == float) || is(T == double))
{
    size_t samples;
    size_t outsideFailures;
    size_t bracketFailures;
    size_t endpointFailures;
    double maxAbsError;
    double maxRelError;
    double maxBracketWidth;

    foreach (li; 1 .. 100)
    foreach (hi; 0 .. 360)
    {
        const T L = cast(T)li / cast(T)100;
        const T h = cast(T)hi;

        const auto oracle = ulpOracle(L, h);
        const auto fixed = fixedBoundary(L, h, iterations);

        if (!inUnitCube(oklchToLinearSrgb(L, fixed.inside, h)))
            ++outsideFailures;

        if (!inUnitCube(oklchToLinearSrgb(L, fixed.outside, h)))
            {} // expected

        if (fixed.inside > oracle.outside ||
            fixed.outside < oracle.inside)
            ++bracketFailures;

        const double error =
            abs(cast(double)fixed.inside - cast(double)oracle.inside);
        const double relative =
            error / cast(double)oracle.inside;
        const double width =
            cast(double)fixed.outside - cast(double)fixed.inside;

        if (error > maxAbsError)
        {
            maxAbsError = error;
            maxRelError = relative;
        }

        if (width > maxBracketWidth)
            maxBracketWidth = width;

        ++samples;
    }

    // Hue periodicity, including negative and multiple-turn values.
    foreach (h; [-720.0, -360.0, 0.0, 360.0, 720.0])
    {
        const T a = cast(T)contractLimit(cast(T)0.5, cast(T)h).value;
        const T b = cast(T)contractLimit(cast(T)0.5, cast(T)0.0).value;

        if (abs(a - b) > (is(T == float) ? 1e-5 : 1e-14))
            ++endpointFailures;
    }

    // Domain endpoints and invalid values.
    if (!contractLimit(cast(T)0, cast(T)42).valid ||
        contractLimit(cast(T)0, cast(T)42).value != 0)
        ++endpointFailures;

    if (!contractLimit(cast(T)1, cast(T)42).valid ||
        contractLimit(cast(T)1, cast(T)42).value != 0)
        ++endpointFailures;

    if (contractLimit(cast(T)-0.01, cast(T)42).valid)
        ++endpointFailures;

    if (contractLimit(cast(T)1.01, cast(T)42).valid)
        ++endpointFailures;

    if (contractLimit(T.nan, cast(T)42).valid)
        ++endpointFailures;

    if (contractLimit(cast(T)0.5, T.infinity).valid)
        ++endpointFailures;

    writefln(
        "scalar=%s iterations=%s samples=%s outside=%s bracket=%s domain=%s maxAbs=%.17g maxRel=%.17g maxWidth=%.17g",
        T.stringof, iterations, samples, outsideFailures,
        bracketFailures, endpointFailures,
        maxAbsError, maxRelError, maxBracketWidth
    );

    assert(outsideFailures == 0);
    assert(bracketFailures == 0);
    assert(endpointFailures == 0);
}

enum ctfeDouble =
    contractLimit!double(0.5, 17.0);

enum ctfeFloat =
    contractLimit!float(0.5f, 17.0f);

static assert(ctfeDouble.valid && ctfeDouble.value > 0);
static assert(ctfeFloat.valid && ctfeFloat.value > 0);
static assert(contractLimit!double(0.5, 0.0).value ==
              contractLimit!double(0.5, 360.0).value);
static assert(contractLimit!double(0.0, 42.0).valid);
static assert(contractLimit!double(1.0, 42.0).valid);
static assert(!contractLimit!double(-0.01, 42.0).valid);
static assert(!contractLimit!double(1.01, 42.0).valid);
static assert(!contractLimit!double(double.nan, 42.0).valid);
static assert(!contractLimit!double(0.5, double.infinity).valid);

@safe pure nothrow @nogc unittest
{
    const x = contractLimit!double(0.5, 17.0);
    assert(x.valid);
    assert(x.value > 0);
}

void main()
@safe
{
    checkScalar!float(12);
    checkScalar!float(16);
    checkScalar!float(20);
    checkScalar!float(24);

    checkScalar!double(16);
    checkScalar!double(20);
    checkScalar!double(24);
    checkScalar!double(32);

    writeln("R5.9 PASS");
    writefln("CTFE double boundary=%.17g", ctfeDouble.value);
    writefln("CTFE float boundary=%.17g", ctfeFloat.value);
}
