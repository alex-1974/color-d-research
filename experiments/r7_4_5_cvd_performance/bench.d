module bench;
import bv;
import ma;
import candidates;
import bv_policy;
import machado_candidates;
version (FixedMachado) enum machadoMode = 1;
else version (DirectMachado) enum machadoMode = 2;
else version (BoundedMachado) enum machadoMode = 3;
else enum machadoMode = 0;

version (ReferenceVienot) enum candidateMode = 9;
else version (IndexedVienot) enum candidateMode = 7;
else version (StaticVienot) enum candidateMode = 8;
else version (PortableBvPolicy) enum candidateMode = 5;
else version (CompilerBvPolicy) enum candidateMode = 6;
else version (PreparedCvd) enum candidateMode = 1;
else version (InlineCvd) enum candidateMode = 2;
else version (DirectCvd) enum candidateMode = 3;
else version (SplitCvd) enum candidateMode = 4;
else enum candidateMode = 0;
import std.stdio : writeln, writefln;
import std.datetime.stopwatch : StopWatch, AutoStart;
import std.math : abs, isNaN, isInfinity;
import std.conv : to;

version (FpStateDiagnostic)
{
    extern(C) uint colorDReadMxcsr() @nogc nothrow;
    extern(C) ushort colorDReadX87Control() @nogc nothrow;

    void emitFpState(string phase, string scalar, string mode, uint deficiency, size_t n, bool reverse)
    {
        writefln("fpstate,%s,%s,%s,%s,%s,%s,0x%08x,0x%04x",
            phase, scalar, mode, deficiency, n, reverse,
            colorDReadMxcsr(), colorDReadX87Control());
    }
}

enum Mode { brettel, vienot, prepared, lookupApply }

pragma(inline, false)
void batch(T, Mode mode)(const bv.Rgb!T[] input, bv.Rgb!T[] output,
    const ma.Matrix3!T[] table, ma.Matrix3!T prepared, uint deficiency)
@safe pure nothrow @nogc
{
    assert(output.length == input.length);
    static if (candidateMode >= 5 && mode == Mode.brettel)
    {
        policyBrettelBatch!T(input,output,deficiency);
        return;
    }
    else static if (candidateMode >= 7 && mode == Mode.vienot)
    {
        static if (candidateMode == 7) indexedVienotBatch!T(input,output,deficiency);
        else static if (candidateMode == 8) staticVienotBatch!T(input,output,deficiency);
        else referenceVienotBatch!T(input,output,deficiency);
        return;
    }
    else static if (candidateMode >= 5 && mode == Mode.vienot)
    {
        enum policy = candidateMode == 5 ? BvPolicy.portable : BvPolicy.compilerSelected;
        policyVienotBatch!(T,policy)(input,output,deficiency);
        return;
    }
    else static if (candidateMode != 0 && mode == Mode.brettel)
    {
        const plan = prepareBrettel!T(deficiency);
        foreach (i, p; input)
        {
            static if (candidateMode >= 3)
                directBrettel!(T, candidateMode == 4)(output[i], plan, p.r, p.g, p.b);
            else
                output[i] = applyBrettel!(T, candidateMode == 2)(plan, p);
        }
        return;
    }
    else static if (candidateMode != 0 && mode == Mode.vienot)
    {
        const matrix = prepareVienot!T(deficiency);
        foreach (i, p; input)
        {
            static if (candidateMode >= 3) directWrite!T(output[i], matrix, p.r, p.g, p.b);
            else static if (candidateMode == 2) output[i] = inlineApply!T(matrix,p);
            else output[i] = matrix.apply(p);
        }
        return;
    }
    foreach (i, p; input)
    {
        static if (mode == Mode.brettel)
            output[i] = bv.brettelProbe(p, deficiency);
        else static if (mode == Mode.vienot)
            output[i] = bv.vienotProbe(p, deficiency == 1);
        else
        {
            static if (mode == Mode.prepared)
                const matrix = prepared;
            else
                const matrix = ma.matrixAtSeverity(table, cast(T)(i % 1001) / cast(T)1000);
            const c = ma.apply(matrix, ma.Rgb!T(p.r, p.g, p.b));
            output[i] = bv.Rgb!T(c.r, c.g, c.b);
        }
    }
}

pragma(inline, false)
void lookupBatch(T)(ma.Matrix3!T[] output, const ma.Matrix3!T[] table, uint shift)
@safe pure nothrow @nogc
{
    foreach (i, ref matrix; output)
        matrix = ma.matrixAtSeverity(table, cast(T)((i + shift) % 1001) / cast(T)1000);
}

void runCase(T, Mode mode)(size_t n, uint deficiency, bool reverse)
{
    enum labels = ["brettel", "vienot", "prepared", "lookupApply"];
    version (FpStateDiagnostic) emitFpState("before", T.stringof, labels[mode], deficiency, n, reverse);
    auto input = new bv.Rgb!T[n];
    auto output = new bv.Rgb!T[n];
    uint state = 0x12345678;
    foreach (ref p; input)
    {
        state = state*1664525u + 1013904223u; p.r = cast(T)((state >> 8) & 65535) / cast(T)65535;
        state = state*1664525u + 1013904223u; p.g = cast(T)((state >> 8) & 65535) / cast(T)65535;
        state = state*1664525u + 1013904223u; p.b = cast(T)((state >> 8) & 65535) / cast(T)65535;
    }
    const ma.Matrix3!T[11] table = ma.precisionTable!T(
        deficiency == 0 ? ma.protanTable : deficiency == 1 ? ma.deutanTable : ma.tritanTable);
    const prepared = ma.matrixAtSeverity(table[], cast(T)0.65);
    foreach (warm; 0 .. 3)
        static if (machadoMode != 0 && mode == Mode.lookupApply)
            fixedColorBatch!(T, machadoMode == 2, machadoMode == 3)(input, output, table);
        else batch!(T, mode)(input, output, table[], prepared, deficiency);
    // Call with runtime slices and parameters; original fixed-vector tests run
    // separately in Debug. Check the batched representation before timing.
    foreach (i; 0 .. n)
    {
        assert(!isNaN(output[i].r) && !isInfinity(output[i].r));
        assert(!isNaN(output[i].g) && !isInfinity(output[i].g));
        assert(!isNaN(output[i].b) && !isInfinity(output[i].b));
        {
            bv.Rgb!T reference;
            static if (mode == Mode.brettel) reference = bv.brettelProbe(input[i], deficiency);
            else static if (mode == Mode.vienot) reference = bv.vienotProbe(input[i], deficiency == 1);
            else
            {
                static if (mode == Mode.prepared) const matrix = prepared;
                else const matrix = ma.matrixAtSeverity(table[],cast(T)(i%1001)/cast(T)1000);
                const expected = ma.apply(matrix,ma.Rgb!T(input[i].r,input[i].g,input[i].b));
                reference = bv.Rgb!T(expected.r,expected.g,expected.b);
            }
            // Explicit check remains active in optimized -release builds.
            if (!componentMatches(output[i].r, reference.r) ||
                !componentMatches(output[i].g, reference.g) ||
                !componentMatches(output[i].b, reference.b))
                throw new Exception("optimized CVD batch component mismatch");
        }
    }
    foreach (round; 0 .. 9)
    {
        double checksum = 0;
        auto timer = StopWatch(AutoStart.yes);
        foreach (repeat; 0 .. 16)
        {
            // A changing runtime input prevents collapsing identical batches.
            input[0].r = cast(T)(repeat + round) / cast(T)32;
            static if (machadoMode != 0 && mode == Mode.lookupApply)
                fixedColorBatch!(T, machadoMode == 2, machadoMode == 3)(input, output, table);
            else batch!(T, mode)(input, output, table[], prepared, deficiency);
            const p = output[(repeat*997 + round*37) % n];
            checksum += cast(double)p.r + cast(double)p.g + cast(double)p.b;
        }
        timer.stop();
        const ns = cast(double)timer.peek.total!"nsecs" / (n*16);
        writefln("sample,D,%s,%s,%s,%s,%s,%s,%.9f,%.17g", T.stringof, labels[mode], deficiency, n, reverse, round, ns, checksum);
    }
    version (FpStateDiagnostic) emitFpState("after", T.stringof, labels[mode], deficiency, n, reverse);
}

void runLookup(T)(size_t n, uint deficiency, bool reverse)
{
    version (FpStateDiagnostic) emitFpState("before", T.stringof, "lookup", deficiency, n, reverse);
    auto output = new ma.Matrix3!T[n];
    const ma.Matrix3!T[11] table = ma.precisionTable!T(
        deficiency == 0 ? ma.protanTable : deficiency == 1 ? ma.deutanTable : ma.tritanTable);
    foreach (warm; 0 .. 3)
    {
        static if (machadoMode != 0) fixedLookupBatch!(T,machadoMode==2,machadoMode==3)(output,table,0);
        else lookupBatch!T(output, table[], 0);
    }
    foreach (i; 0 .. n)
        if (!matricesMatch!T(output[i],ma.matrixAtSeverity(table[],cast(T)(i%1001)/cast(T)1000)))
            throw new Exception("optimized Machado matrix component mismatch");
    foreach (round; 0 .. 9)
    {
        double checksum = 0;
        auto timer = StopWatch(AutoStart.yes);
        foreach (repeat; 0 .. 16)
        {
            static if (machadoMode != 0) fixedLookupBatch!(T,machadoMode==2,machadoMode==3)(output,table,cast(uint)(repeat+round));
            else lookupBatch!T(output, table[], cast(uint)(repeat + round));
            const p = output[(repeat*997 + round*37) % n];
            checksum += cast(double)p.m00 + cast(double)p.m11 + cast(double)p.m22;
        }
        timer.stop();
        const ns = cast(double)timer.peek.total!"nsecs" / (n*16);
        writefln("sample,D,%s,lookup,%s,%s,%s,%s,%.9f,%.17g", T.stringof, deficiency, n, reverse, round, ns, checksum);
    }
    version (FpStateDiagnostic) emitFpState("after", T.stringof, "lookup", deficiency, n, reverse);
}

void cases(T)(size_t n, bool reverse)
{
    foreach (index; 0u .. 3u)
    {
        const deficiency = reverse ? 2u-index : index;
        version (IsolateLookup) runLookup!T(n, deficiency, reverse);
        else version (IsolatePrepared) runCase!(T, Mode.prepared)(n, deficiency, reverse);
        else
        {
        if (reverse) { runLookup!T(n, deficiency, reverse); runCase!(T, Mode.lookupApply)(n, deficiency, reverse); runCase!(T, Mode.prepared)(n, deficiency, reverse); }
        runCase!(T, Mode.brettel)(n, deficiency, reverse);
        if (deficiency < 2) runCase!(T, Mode.vienot)(n, deficiency, reverse);
        if (!reverse) { runCase!(T, Mode.prepared)(n, deficiency, reverse); runCase!(T, Mode.lookupApply)(n, deficiency, reverse); runLookup!T(n, deficiency, reverse); }
        }
    }
}

void main(string[] args)
{
    const n = args.length > 1 ? args[1].to!size_t : 65536;
    const reverse = args.length > 2;
    enforceWorkload(n);
    version (Preflight)
    {
        bv.referenceMain(); ma.referenceMain();
        validateCandidates!float(); validateCandidates!double();
        validateMachadoCandidates!float(); validateMachadoCandidates!double();
        writeln("R7.4.5 fixed-table Machado 1001 severities, components, IEEE, CTFE and attributes: PASS");
        writeln("R7.4.5 prepared/inline/direct/split candidate component, IEEE, CTFE and attribute preflight: PASS");
        cases!float(32, false); cases!double(32, false);
    }
    else
    {
        writeln("metadata,D,frontend=", __VERSION__, ",n=", n, ",warmup=3,rounds=9,repeats=16,AoS,bounds=on");
        if (reverse) { cases!double(n, reverse); cases!float(n, reverse); }
        else { cases!float(n, reverse); cases!double(n, reverse); }
    }
}

void enforceWorkload(size_t n)
{
    if (n < 32 || n > 1048576) throw new Exception("workload must be 32..1048576");
}
