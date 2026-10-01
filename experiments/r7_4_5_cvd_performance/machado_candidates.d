module machado_candidates;
import ma;
import bv;
import candidates : componentMatches;

ma.Matrix3!T fixedLookup(T)(const ref ma.Matrix3!T[11] table, T severity)
@safe pure nothrow @nogc
{
    assert(severity >= 0 && severity <= 1);
    const T scaled = severity * 10;
    const size_t lo = cast(size_t)scaled;
    if (lo >= 10) return table[10];
    const T alpha = scaled - cast(T)lo;
    return ma.lerp(table[lo], table[lo+1], alpha);
}

pragma(inline, true)
void lookupWrite(T)(ref ma.Matrix3!T output, const ref ma.Matrix3!T[11] table, T severity)
@safe pure nothrow @nogc
{
    assert(severity >= 0 && severity <= 1);
    const T scaled = severity * 10;
    const size_t lo = cast(size_t)scaled;
    if (lo >= 10) { output = table[10]; return; }
    const T alpha = scaled - cast(T)lo;
    static foreach (field; ["m00","m01","m02","m10","m11","m12","m20","m21","m22"])
        mixin("output." ~ field ~ " = table[lo]." ~ field ~ " + (table[lo+1]." ~ field ~ " - table[lo]." ~ field ~ ")*alpha;");
}

pragma(inline, false)
void fixedColorBatch(T, bool direct)(const bv.Rgb!T[] input, bv.Rgb!T[] output,
    const ref ma.Matrix3!T[11] table)
@safe pure nothrow @nogc
{
    assert(output.length == input.length);
    foreach (i, p; input)
    {
        ma.Matrix3!T matrix;
        const T severity = cast(T)(i%1001)/cast(T)1000;
        static if (direct) lookupWrite!T(matrix, table, severity);
        else matrix = fixedLookup!T(table, severity);
        const c = ma.apply(matrix, ma.Rgb!T(p.r,p.g,p.b));
        output[i] = bv.Rgb!T(c.r,c.g,c.b);
    }
}

pragma(inline, false)
void fixedLookupBatch(T, bool direct)(ma.Matrix3!T[] output,
    const ref ma.Matrix3!T[11] table, uint shift)
@safe pure nothrow @nogc
{
    foreach (i, ref matrix; output)
    {
        const T severity = cast(T)((i+shift)%1001)/cast(T)1000;
        static if (direct) lookupWrite!T(matrix, table, severity);
        else matrix = fixedLookup!T(table, severity);
    }
}

bool matricesMatch(T)(ma.Matrix3!T actual, ma.Matrix3!T expected)
@safe pure nothrow @nogc
{
    static foreach (field; ["m00","m01","m02","m10","m11","m12","m20","m21","m22"])
        mixin("if (!componentMatches(actual." ~ field ~ ", expected." ~ field ~ ")) return false;");
    return true;
}

bool qualifyCtfe(T)()
@safe pure nothrow @nogc
{
    const ma.Matrix3!T[11] table = ma.precisionTable!T(ma.protanTable);
    ma.Matrix3!T direct;
    const T[4] severities = [cast(T)0,cast(T)0.35,cast(T)0.65,cast(T)1];
    foreach (severity; severities)
    {
        // Explicit fixed array below avoids dynamic manifest-array materialization.
        lookupWrite!T(direct, table, severity);
        if (!matricesMatch!T(direct, ma.matrixAtSeverity(table[], severity))) return false;
        if (!matricesMatch!T(fixedLookup!T(table,severity), direct)) return false;
    }
    return true;
}

void validateMachadoCandidates(T)()
@safe pure nothrow @nogc
{
    static assert(qualifyCtfe!T());
    foreach (deficiency; 0u .. 3u)
    {
        const ma.Matrix3!T[11] table = ma.precisionTable!T(
            deficiency==0 ? ma.protanTable : deficiency==1 ? ma.deutanTable : ma.tritanTable);
        foreach (i; 0 .. 1001)
        {
            const T severity = cast(T)i/cast(T)1000;
            const reference = ma.matrixAtSeverity(table[], severity);
            const fixed = fixedLookup!T(table, severity);
            ma.Matrix3!T direct;
            lookupWrite!T(direct, table, severity);
            assert(matricesMatch!T(fixed, reference));
            assert(matricesMatch!T(direct, reference));
            const bv.Rgb!T[4] inputs = [
                bv.Rgb!T(cast(T)0.2,cast(T)0.4,cast(T)0.7),
                bv.Rgb!T(-cast(T)0.25,cast(T)1.25,cast(T)2),
                bv.Rgb!T(T.nan,cast(T)0.25,cast(T)0.75),
                bv.Rgb!T(T.infinity,cast(T)0.25,cast(T)0.75)];
            foreach (p; inputs)
            {
                const expected = ma.apply(reference,ma.Rgb!T(p.r,p.g,p.b));
                const actual = ma.apply(direct,ma.Rgb!T(p.r,p.g,p.b));
                assert(componentMatches(actual.r,expected.r));
                assert(componentMatches(actual.g,expected.g));
                assert(componentMatches(actual.b,expected.b));
            }
        }
    }
}
