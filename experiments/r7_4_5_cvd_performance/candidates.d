module candidates;
import bv;
import std.math : abs, isNaN, isInfinity;

struct BrettelPlan(T)
{
    bv.Matrix3!T first, second;
    T nr, ng, nb;
}

BrettelPlan!T prepareBrettel(T)(uint deficiency)
@safe pure nothrow @nogc
{
    switch (deficiency)
    {
    case 0:
        return BrettelPlan!T(bv.precisionMatrix!T(bv.brettelProtan1),
            bv.precisionMatrix!T(bv.brettelProtan2), cast(T)0.00048, cast(T)0.00393, cast(T)-0.00441);
    case 1:
        return BrettelPlan!T(bv.precisionMatrix!T(bv.brettelDeutan1),
            bv.precisionMatrix!T(bv.brettelDeutan2), cast(T)-0.00281, cast(T)-0.00611, cast(T)0.00892);
    case 2:
        return BrettelPlan!T(bv.precisionMatrix!T(bv.brettelTritan1),
            bv.precisionMatrix!T(bv.brettelTritan2), cast(T)0.03901, cast(T)-0.02788, cast(T)-0.01113);
    default:
        assert(0, "unsupported research deficiency");
    }
}

bv.Matrix3!T prepareVienot(T)(uint deficiency)
@safe pure nothrow @nogc
{
    assert(deficiency < 2);
    return bv.precisionMatrix!T(deficiency == 1 ? bv.vienotDeutan : bv.vienotProtan);
}

// The explicit source-form candidate preserves component precision and operation order.
pragma(inline, true)
bv.Rgb!T inlineApply(T)(bv.Matrix3!T matrix, bv.Rgb!T p)
@safe pure nothrow @nogc
{
    return bv.Rgb!T(
        matrix.m00*p.r + matrix.m01*p.g + matrix.m02*p.b,
        matrix.m10*p.r + matrix.m11*p.g + matrix.m12*p.b,
        matrix.m20*p.r + matrix.m21*p.g + matrix.m22*p.b);
}

bv.Rgb!T applyBrettel(T, bool explicitArithmetic)(BrettelPlan!T plan, bv.Rgb!T p)
@safe pure nothrow @nogc
{
    const matrix = p.r*plan.nr + p.g*plan.ng + p.b*plan.nb >= 0
        ? plan.first : plan.second;
    static if (explicitArithmetic)
        return inlineApply(matrix, p);
    else
        return matrix.apply(p);
}

bool componentMatches(T)(T actual, T expected)
@safe pure nothrow @nogc
{
    if (isNaN(expected)) return isNaN(actual);
    if (isInfinity(expected)) return actual == expected;
    return !isNaN(actual) && !isInfinity(actual)
        && abs(actual-expected) <= (is(T == float) ? cast(T)2e-6 : cast(T)1e-12);
}

void compareColor(T)(bv.Rgb!T actual, bv.Rgb!T expected)
@safe pure nothrow @nogc
{
    assert(componentMatches(actual.r, expected.r));
    assert(componentMatches(actual.g, expected.g));
    assert(componentMatches(actual.b, expected.b));
}

void compareInput(T)(bv.Rgb!T input)
@safe pure nothrow @nogc
{
    foreach (deficiency; 0u .. 3u)
    {
        const plan = prepareBrettel!T(deficiency);
        const reference = bv.brettelProbe(input, deficiency);
        compareColor(applyBrettel!(T, false)(plan, input), reference);
        compareColor(applyBrettel!(T, true)(plan, input), reference);
        if (deficiency < 2)
        {
            const matrix = prepareVienot!T(deficiency);
            const vienotReference = bv.vienotProbe(input, deficiency == 1);
            compareColor(matrix.apply(input), vienotReference);
            compareColor(inlineApply(matrix, input), vienotReference);
        }
    }
}

void validateCandidates(T)()
@safe pure nothrow @nogc
{
    uint state = 0x12345678;
    foreach (i; 0 .. 65536)
    {
        bv.Rgb!T p;
        state=state*1664525u+1013904223u; p.r=cast(T)((state>>8)&65535)/cast(T)65535;
        state=state*1664525u+1013904223u; p.g=cast(T)((state>>8)&65535)/cast(T)65535;
        state=state*1664525u+1013904223u; p.b=cast(T)((state>>8)&65535)/cast(T)65535;
        compareInput(p);
    }
    const bv.Rgb!T[10] edges = [
        bv.Rgb!T(0,0,0), bv.Rgb!T(1,1,1), bv.Rgb!T(1,0,0),
        bv.Rgb!T(0,1,0), bv.Rgb!T(0,0,1), bv.Rgb!T(-0.25,1.25,2),
        bv.Rgb!T(T.nan,0.25,0.75), bv.Rgb!T(T.infinity,0.25,0.75),
        bv.Rgb!T(-T.infinity,T.infinity,0), bv.Rgb!T(-cast(T)0,cast(T)0,-cast(T)0)];
    foreach (p; edges) compareInput(p);
    // Construct inputs near each stored separation plane, including its equality case.
    foreach (deficiency; 0u .. 3u)
    {
        const plan = prepareBrettel!T(deficiency);
        const T r=0.2, g=0.4;
        const T b=-(r*plan.nr+g*plan.ng)/plan.nb;
        const T[3] offsets = [-cast(T)1e-6, cast(T)0, cast(T)1e-6];
        foreach (offset; offsets)
            compareInput(bv.Rgb!T(r,g,b+offset));
    }
    static foreach (deficiency; 0u .. 3u)
    {{
        enum plan = prepareBrettel!T(deficiency);
        enum p = bv.Rgb!T(cast(T)0.2,cast(T)0.4,cast(T)0.7);
        enum refColor = bv.brettelProbe(p,deficiency);
        enum first = applyBrettel!(T,false)(plan,p);
        enum second = applyBrettel!(T,true)(plan,p);
        static assert(componentMatches(first.r,refColor.r) && componentMatches(first.g,refColor.g) && componentMatches(first.b,refColor.b));
        static assert(componentMatches(second.r,refColor.r) && componentMatches(second.g,refColor.g) && componentMatches(second.b,refColor.b));
    }}
}
