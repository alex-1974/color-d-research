module production_bench;

import color.cvd :
    CvdDeficiency,
    PreparedBrettel1997Dichromat,
    PreparedMachado2009,
    PreparedVienot1999Dichromat,
    RedGreenCvdDeficiency,
    brettel1997Dichromat,
    machado2009,
    prepareBrettel1997Dichromat,
    prepareVienot1999Dichromat,
    tryPrepareMachado2009,
    vienot1999Dichromat;

import color.rgb :
    LinearSRgb;

import std.conv : to;
import std.datetime.stopwatch :
    AutoStart,
    StopWatch;
import std.math :
    fabs,
    isInfinity,
    isNaN;
import std.stdio :
    writefln,
    writeln;

enum Model
{
    vienot,
    machado,
    brettel
}

enum Variant
{
    scalar,
    prepared
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
    "prepared"
];

enum double machadoSeverity = 0.65;


pragma(inline, false)
void scalarBatch(T, Model model)(
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output,
    uint deficiency
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);

    foreach (i, ref color; input)
    {
        static if (model == Model.vienot)
        {
            output[i] =
                vienot1999Dichromat(
                    color,
                    cast(RedGreenCvdDeficiency)
                        deficiency
                );
        }
        else static if (model == Model.machado)
        {
            output[i] =
                machado2009(
                    color,
                    cast(RedGreenCvdDeficiency)
                        deficiency,
                    cast(T)machadoSeverity
                );
        }
        else
        {
            output[i] =
                brettel1997Dichromat(
                    color,
                    cast(CvdDeficiency)
                        deficiency
                );
        }
    }
}


pragma(inline, false)
void preparedBatch(P, T)(
    const ref P prepared,
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output
)
@safe pure nothrow @nogc
{
    const bool ok =
        prepared.tryApplyInto(
            input,
            output
        );

    assert(ok);
}


private LinearSRgb!T scalarReference(
    T,
    Model model
)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    static if (model == Model.vienot)
    {
        return vienot1999Dichromat(
            color,
            cast(RedGreenCvdDeficiency)
                deficiency
        );
    }
    else static if (model == Model.machado)
    {
        return machado2009(
            color,
            cast(RedGreenCvdDeficiency)
                deficiency,
            cast(T)machadoSeverity
        );
    }
    else
    {
        return brettel1997Dichromat(
            color,
            cast(CvdDeficiency)
                deficiency
        );
    }
}


private bool closeComponent(T)(
    T actual,
    T expected
)
@safe pure nothrow @nogc
{
    if (isNaN(expected))
        return isNaN(actual);

    if (isInfinity(expected))
        return actual == expected;

    if (isNaN(actual) || isInfinity(actual))
        return false;

    const T tolerance =
        is(T == float)
            ? cast(T)2e-6
            : cast(T)1e-12;

    return
        fabs(actual - expected) <=
        tolerance;
}


private void validateOutput(
    T,
    Model model
)(
    const(LinearSRgb!T)[] input,
    const(LinearSRgb!T)[] output,
    uint deficiency
)
{
    assert(input.length == output.length);

    foreach (i; 0 .. input.length)
    {
        const expected =
            scalarReference!(T, model)(
                input[i],
                deficiency
            );

        const actual = output[i];

        if (
            !closeComponent(
                actual.r,
                expected.r
            ) ||
            !closeComponent(
                actual.g,
                expected.g
            ) ||
            !closeComponent(
                actual.b,
                expected.b
            )
        )
        {
            throw new Exception(
                "production CVD semantic mismatch"
            );
        }
    }
}


void runCase(
    T,
    Model model,
    Variant variant
)(
    size_t n,
    uint deficiency,
    bool reverse
)
{
    auto input =
        new LinearSRgb!T[n];

    auto output =
        new LinearSRgb!T[n];

    uint state = 0x12345678;

    foreach (ref color; input)
    {
        state =
            state * 1664525u +
            1013904223u;

        color.r =
            cast(T)((state >> 8) & 65535) /
            cast(T)65535;

        state =
            state * 1664525u +
            1013904223u;

        color.g =
            cast(T)((state >> 8) & 65535) /
            cast(T)65535;

        state =
            state * 1664525u +
            1013904223u;

        color.b =
            cast(T)((state >> 8) & 65535) /
            cast(T)65535;
    }

    static if (
        variant == Variant.prepared &&
        model == Model.vienot
    )
    {
        const prepared =
            prepareVienot1999Dichromat!T(
                cast(RedGreenCvdDeficiency)
                    deficiency
            );

        foreach (_; 0 .. 4)
            preparedBatch(
                prepared,
                input,
                output
            );

        validateOutput!(T, model)(
            input,
            output,
            deficiency
        );

        foreach (round; 0 .. 9)
        {
            double checksum = 0;
            auto timer =
                StopWatch(AutoStart.yes);

            foreach (repeat; 0 .. 16)
            {
                input[0].r =
                    cast(T)(repeat + round) /
                    cast(T)32;

                preparedBatch(
                    prepared,
                    input,
                    output
                );

                const color =
                    output[
                        (
                            repeat * 997 +
                            round * 37
                        ) %
                        n
                    ];

                checksum +=
                    cast(double)color.r +
                    cast(double)color.g +
                    cast(double)color.b;
            }

            timer.stop();

            const double ns =
                cast(double)
                    timer.peek.total!"nsecs" /
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
    else static if (
        variant == Variant.prepared &&
        model == Model.machado
    )
    {
        PreparedMachado2009!T prepared;

        const bool valid =
            tryPrepareMachado2009(
                cast(RedGreenCvdDeficiency)
                    deficiency,
                cast(T)machadoSeverity,
                prepared
            );

        assert(valid);

        foreach (_; 0 .. 4)
            preparedBatch(
                prepared,
                input,
                output
            );

        validateOutput!(T, model)(
            input,
            output,
            deficiency
        );

        foreach (round; 0 .. 9)
        {
            double checksum = 0;
            auto timer =
                StopWatch(AutoStart.yes);

            foreach (repeat; 0 .. 16)
            {
                input[0].r =
                    cast(T)(repeat + round) /
                    cast(T)32;

                preparedBatch(
                    prepared,
                    input,
                    output
                );

                const color =
                    output[
                        (
                            repeat * 997 +
                            round * 37
                        ) %
                        n
                    ];

                checksum +=
                    cast(double)color.r +
                    cast(double)color.g +
                    cast(double)color.b;
            }

            timer.stop();

            const double ns =
                cast(double)
                    timer.peek.total!"nsecs" /
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
    else static if (
        variant == Variant.prepared &&
        model == Model.brettel
    )
    {
        const prepared =
            prepareBrettel1997Dichromat!T(
                cast(CvdDeficiency)
                    deficiency
            );

        foreach (_; 0 .. 4)
            preparedBatch(
                prepared,
                input,
                output
            );

        validateOutput!(T, model)(
            input,
            output,
            deficiency
        );

        foreach (round; 0 .. 9)
        {
            double checksum = 0;
            auto timer =
                StopWatch(AutoStart.yes);

            foreach (repeat; 0 .. 16)
            {
                input[0].r =
                    cast(T)(repeat + round) /
                    cast(T)32;

                preparedBatch(
                    prepared,
                    input,
                    output
                );

                const color =
                    output[
                        (
                            repeat * 997 +
                            round * 37
                        ) %
                        n
                    ];

                checksum +=
                    cast(double)color.r +
                    cast(double)color.g +
                    cast(double)color.b;
            }

            timer.stop();

            const double ns =
                cast(double)
                    timer.peek.total!"nsecs" /
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
    else
    {
        foreach (_; 0 .. 4)
            scalarBatch!(T, model)(
                input,
                output,
                deficiency
            );

        validateOutput!(T, model)(
            input,
            output,
            deficiency
        );

        foreach (round; 0 .. 9)
        {
            double checksum = 0;
            auto timer =
                StopWatch(AutoStart.yes);

            foreach (repeat; 0 .. 16)
            {
                input[0].r =
                    cast(T)(repeat + round) /
                    cast(T)32;

                scalarBatch!(T, model)(
                    input,
                    output,
                    deficiency
                );

                const color =
                    output[
                        (
                            repeat * 997 +
                            round * 37
                        ) %
                        n
                    ];

                checksum +=
                    cast(double)color.r +
                    cast(double)color.g +
                    cast(double)color.b;
            }

            timer.stop();

            const double ns =
                cast(double)
                    timer.peek.total!"nsecs" /
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
            Variant.prepared
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            model,
            Variant.scalar
        )(
            n,
            deficiency,
            reverse
        );
    }
    else
    {
        runCase!(
            T,
            model,
            Variant.scalar
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            model,
            Variant.prepared
        )(
            n,
            deficiency,
            reverse
        );
    }
}


void runModel(T, Model model)(
    size_t n,
    bool reverse
)
{
    enum uint count =
        model == Model.brettel
            ? 3u
            : 2u;

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
        runModel!(T, Model.brettel)(
            n,
            reverse
        );

        runModel!(T, Model.machado)(
            n,
            reverse
        );

        runModel!(T, Model.vienot)(
            n,
            reverse
        );
    }
    else
    {
        runModel!(T, Model.vienot)(
            n,
            reverse
        );

        runModel!(T, Model.machado)(
            n,
            reverse
        );

        runModel!(T, Model.brettel)(
            n,
            reverse
        );
    }
}


void main(string[] args)
{
    const size_t n =
        args.length > 1
            ? args[1].to!size_t
            : 65_536;

    const bool reverse =
        args.length > 2;

    if (n < 32 || n > 1_048_576)
        throw new Exception(
            "workload must be 32..1048576"
        );

    writeln(
        "metadata,D,production=snapshotted-by-replay,n=",
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
