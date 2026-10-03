module bench;

import kernels;

import std.conv : to;
import std.datetime.stopwatch : AutoStart, StopWatch;
import std.math : isInfinity, isNaN;
import std.stdio : writefln, writeln;

enum Model
{
    vienot,
    machado,
    brettel
}

enum Variant
{
    scalar,
    prepared,
    specialized
}

enum modelLabels =
[
    "vienot",
    "machado",
    "brettel"
];

enum variantLabels =
[
    "scalar",
    "prepared",
    "specialized"
];

enum double machadoSeverity = 0.65;

pragma(inline, false)
void batch(T, Model model, Variant variant)(
    const Rgb!T[] input,
    Rgb!T[] output,
    uint deficiency
)
@safe pure nothrow @nogc
{
    static if (model == Model.vienot)
    {
        static if (variant == Variant.scalar)
            scalarVienotBatch!T(input, output, deficiency);
        else static if (variant == Variant.prepared)
            preparedVienotBatch!T(input, output, deficiency);
        else
            specializedVienotBatch!T(input, output, deficiency);
    }
    else static if (model == Model.machado)
    {
        enum T severity = cast(T)machadoSeverity;

        static if (variant == Variant.scalar)
            scalarMachadoBatch!T(
                input,
                output,
                deficiency,
                severity
            );
        else static if (variant == Variant.prepared)
            preparedMachadoBatch!T(
                input,
                output,
                deficiency,
                severity
            );
        else
            specializedMachadoBatch!T(
                input,
                output,
                deficiency,
                severity
            );
    }
    else
    {
        static if (variant == Variant.scalar)
            scalarBrettelBatch!T(input, output, deficiency);
        else static if (variant == Variant.prepared)
            preparedBrettelBatch!T(input, output, deficiency);
        else
            specializedBrettelBatch!T(input, output, deficiency);
    }
}

private Rgb!T scalarReference(T, Model model)(
    Rgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    static if (model == Model.vienot)
    {
        return scalarVienot!T(color, deficiency);
    }
    else static if (model == Model.machado)
    {
        return scalarMachado!T(
            color,
            deficiency,
            cast(T)machadoSeverity
        );
    }
    else
    {
        return scalarBrettel!T(color, deficiency);
    }
}

private bool closeComponent(T)(T actual, T expected)
@safe pure nothrow @nogc
{
    if (isNaN(expected))
        return isNaN(actual);

    if (isInfinity(expected))
        return actual == expected;

    if (isNaN(actual) || isInfinity(actual))
        return false;

    const T diff =
        actual > expected
            ? actual - expected
            : expected - actual;

    return diff <= (
        is(T == float)
            ? cast(T)2e-6
            : cast(T)1e-12
    );
}

void runCase(T, Model model, Variant variant)(
    size_t n,
    uint deficiency,
    bool reverse
)
{
    auto input = new Rgb!T[n];
    auto output = new Rgb!T[n];

    uint state = 0x12345678;

    foreach (ref color; input)
    {
        state = state * 1664525u + 1013904223u;
        color.r =
            cast(T)((state >> 8) & 65535) /
            cast(T)65535;

        state = state * 1664525u + 1013904223u;
        color.g =
            cast(T)((state >> 8) & 65535) /
            cast(T)65535;

        state = state * 1664525u + 1013904223u;
        color.b =
            cast(T)((state >> 8) & 65535) /
            cast(T)65535;
    }

    foreach (_; 0 .. 4)
        batch!(T, model, variant)(
            input,
            output,
            deficiency
        );

    foreach (i; 0 .. n)
    {
        const expected =
            scalarReference!(T, model)(
                input[i],
                deficiency
            );

        const actual = output[i];

        if (
            !closeComponent(actual.r, expected.r) ||
            !closeComponent(actual.g, expected.g) ||
            !closeComponent(actual.b, expected.b)
        )
        {
            throw new Exception(
                "CVD architecture semantic mismatch"
            );
        }
    }

    foreach (round; 0 .. 9)
    {
        double checksum = 0;
        auto timer = StopWatch(AutoStart.yes);

        foreach (repeat; 0 .. 16)
        {
            input[0].r =
                cast(T)(repeat + round) /
                cast(T)32;

            batch!(T, model, variant)(
                input,
                output,
                deficiency
            );

            const color =
                output[
                    (repeat * 997 + round * 37) %
                    n
                ];

            checksum +=
                cast(double)color.r +
                cast(double)color.g +
                cast(double)color.b;
        }

        timer.stop();

        const double ns =
            cast(double)timer.peek.total!"nsecs" /
            cast(double)(n * 16);

        writefln(
            "sample,D,%s,%s,%s,%s,%s,%s,%s,%.9f,%.17g",
            T.stringof,
            modelLabels[model],
            variantLabels[variant],
            deficiency,
            n,
            reverse,
            round,
            ns,
            checksum
        );
    }
}

void runDeficiency(T, Model model)(
    size_t n,
    uint deficiency,
    bool reverse
)
{
    if (reverse)
    {
        runCase!(
            T,
            model,
            Variant.specialized
        )(n, deficiency, reverse);

        runCase!(
            T,
            model,
            Variant.prepared
        )(n, deficiency, reverse);

        runCase!(
            T,
            model,
            Variant.scalar
        )(n, deficiency, reverse);
    }
    else
    {
        runCase!(
            T,
            model,
            Variant.scalar
        )(n, deficiency, reverse);

        runCase!(
            T,
            model,
            Variant.prepared
        )(n, deficiency, reverse);

        runCase!(
            T,
            model,
            Variant.specialized
        )(n, deficiency, reverse);
    }
}

void runModel(T, Model model)(
    size_t n,
    bool reverse
)
{
    enum uint count =
        model == Model.brettel ? 3u : 2u;

    foreach (index; 0u .. count)
    {
        const uint deficiency =
            reverse
                ? count - 1 - index
                : index;

        runDeficiency!(T, model)(
            n,
            deficiency,
            reverse
        );
    }
}

void cases(T)(
    size_t n,
    bool reverse
)
{
    if (reverse)
    {
        runModel!(T, Model.brettel)(n, reverse);
        runModel!(T, Model.machado)(n, reverse);
        runModel!(T, Model.vienot)(n, reverse);
    }
    else
    {
        runModel!(T, Model.vienot)(n, reverse);
        runModel!(T, Model.machado)(n, reverse);
        runModel!(T, Model.brettel)(n, reverse);
    }
}

void enforceWorkload(size_t n)
{
    if (n < 32 || n > 1_048_576)
        throw new Exception(
            "workload must be 32..1048576"
        );
}

void main(string[] args)
{
    const size_t n =
        args.length > 1
            ? args[1].to!size_t
            : 65_536;

    const bool reverse =
        args.length > 2;

    enforceWorkload(n);

    version (Preflight)
    {
        validateKernels!float();
        validateKernels!double();

        writeln(
            "R7.4.6 CVD scalar/prepared/specialized semantics, " ~
            "IEEE edges, CTFE and attributes: PASS"
        );
    }
    else
    {
        writeln(
            "metadata,D,frontend=",
            __VERSION__,
            ",n=",
            n,
            ",warmup=4,rounds=9,repeats=16,AoS,bounds=on,severity=0.65"
        );

        if (reverse)
        {
            cases!double(n, reverse);
            cases!float(n, reverse);
        }
        else
        {
            cases!float(n, reverse);
            cases!double(n, reverse);
        }
    }
}
