module production_callshape_bench;

import color.cvd :
    PreparedMachado2009,
    PreparedVienot1999Dichromat,
    RedGreenCvdDeficiency,
    prepareVienot1999Dichromat,
    tryPrepareMachado2009;

import color.rgb :
    LinearSRgb;

import std.conv : to;
import std.datetime.stopwatch :
    AutoStart,
    StopWatch;
import std.math :
    fabs;
import std.stdio :
    writefln,
    writeln;

enum Model
{
    vienot,
    machado
}

enum Shape
{
    refWrapper,
    valueWrapper,
    localCopyWrapper,
    direct
}

enum modelLabels =
[
    "vienot",
    "machado"
];

enum shapeLabels =
[
    "ref-wrapper",
    "value-wrapper",
    "local-copy-wrapper",
    "direct"
];

enum double machadoSeverity = 0.65;


pragma(inline, false)
bool applyRefWrapper(P, T)(
    const ref P prepared,
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output
)
@safe pure nothrow @nogc
{
    return prepared.tryApplyInto(
        input,
        output
    );
}


pragma(inline, false)
bool applyValueWrapper(P, T)(
    P prepared,
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output
)
@safe pure nothrow @nogc
{
    return prepared.tryApplyInto(
        input,
        output
    );
}


pragma(inline, false)
bool applyLocalCopyWrapper(P, T)(
    const ref P prepared,
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output
)
@safe pure nothrow @nogc
{
    const local = prepared;

    return local.tryApplyInto(
        input,
        output
    );
}


private bool close(T)(
    T lhs,
    T rhs
)
@safe pure nothrow @nogc
{
    const T diff =
        lhs > rhs
            ? lhs - rhs
            : rhs - lhs;

    return diff <= (
        is(T == float)
            ? cast(T)2e-6
            : cast(T)1e-12
    );
}


private void validateSame(T)(
    const(LinearSRgb!T)[] lhs,
    const(LinearSRgb!T)[] rhs
)
{
    assert(lhs.length == rhs.length);

    foreach (i; 0 .. lhs.length)
    {
        if (
            !close(lhs[i].r, rhs[i].r) ||
            !close(lhs[i].g, rhs[i].g) ||
            !close(lhs[i].b, rhs[i].b)
        )
        {
            throw new Exception(
                "call-shape semantic mismatch"
            );
        }
    }
}


private void runPrepared(
    T,
    Model model,
    Shape shape,
    P
)(
    const ref P prepared,
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output
)
@safe pure nothrow @nogc
{
    bool ok;

    static if (shape == Shape.refWrapper)
    {
        ok =
            applyRefWrapper(
                prepared,
                input,
                output
            );
    }
    else static if (shape == Shape.valueWrapper)
    {
        ok =
            applyValueWrapper(
                prepared,
                input,
                output
            );
    }
    else static if (
        shape == Shape.localCopyWrapper
    )
    {
        ok =
            applyLocalCopyWrapper(
                prepared,
                input,
                output
            );
    }
    else
    {
        ok =
            prepared.tryApplyInto(
                input,
                output
            );
    }

    assert(ok);
}


void runCase(
    T,
    Model model,
    Shape shape,
    P
)(
    const ref P prepared,
    size_t n,
    bool reverse
)
{
    auto input =
        new LinearSRgb!T[n];

    auto output =
        new LinearSRgb!T[n];

    auto reference =
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

    runPrepared!(
        T,
        model,
        Shape.direct
    )(
        prepared,
        input,
        reference
    );

    runPrepared!(
        T,
        model,
        shape
    )(
        prepared,
        input,
        output
    );

    validateSame(
        output,
        reference
    );

    foreach (_; 0 .. 4)
    {
        runPrepared!(
            T,
            model,
            shape
        )(
            prepared,
            input,
            output
        );
    }

    foreach (round; 0 .. 11)
    {
        double checksum = 0;
        auto timer =
            StopWatch(AutoStart.yes);

        foreach (repeat; 0 .. 24)
        {
            input[0].r =
                cast(T)(repeat + round) /
                cast(T)48;

            runPrepared!(
                T,
                model,
                shape
            )(
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
            cast(double)(n * 24);

        writefln(
            "sample,%s,%s,%s,%s,%s,%s,%.9f,%.17g",
            T.stringof,
            modelLabels[model],
            shapeLabels[shape],
            n,
            reverse,
            round,
            ns,
            checksum
        );
    }
}


void runModel(
    T,
    Model model
)(
    size_t n,
    bool reverse
)
{
    static if (model == Model.vienot)
    {
        const prepared =
            prepareVienot1999Dichromat!T(
                RedGreenCvdDeficiency.protan
            );

        if (reverse)
        {
            runCase!(
                T,
                model,
                Shape.direct
            )(prepared, n, reverse);

            runCase!(
                T,
                model,
                Shape.localCopyWrapper
            )(prepared, n, reverse);

            runCase!(
                T,
                model,
                Shape.valueWrapper
            )(prepared, n, reverse);

            runCase!(
                T,
                model,
                Shape.refWrapper
            )(prepared, n, reverse);
        }
        else
        {
            runCase!(
                T,
                model,
                Shape.refWrapper
            )(prepared, n, reverse);

            runCase!(
                T,
                model,
                Shape.valueWrapper
            )(prepared, n, reverse);

            runCase!(
                T,
                model,
                Shape.localCopyWrapper
            )(prepared, n, reverse);

            runCase!(
                T,
                model,
                Shape.direct
            )(prepared, n, reverse);
        }
    }
    else
    {
        PreparedMachado2009!T prepared;

        const bool valid =
            tryPrepareMachado2009(
                RedGreenCvdDeficiency.protan,
                cast(T)machadoSeverity,
                prepared
            );

        assert(valid);

        if (reverse)
        {
            runCase!(
                T,
                model,
                Shape.direct
            )(prepared, n, reverse);

            runCase!(
                T,
                model,
                Shape.localCopyWrapper
            )(prepared, n, reverse);

            runCase!(
                T,
                model,
                Shape.valueWrapper
            )(prepared, n, reverse);

            runCase!(
                T,
                model,
                Shape.refWrapper
            )(prepared, n, reverse);
        }
        else
        {
            runCase!(
                T,
                model,
                Shape.refWrapper
            )(prepared, n, reverse);

            runCase!(
                T,
                model,
                Shape.valueWrapper
            )(prepared, n, reverse);

            runCase!(
                T,
                model,
                Shape.localCopyWrapper
            )(prepared, n, reverse);

            runCase!(
                T,
                model,
                Shape.direct
            )(prepared, n, reverse);
        }
    }
}


void cases(T)(
    size_t n,
    bool reverse
)
{
    if (reverse)
    {
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
        "metadata,production=7a7550d44b3133b1145562c6ca8483fe6b0f668c,n=",
        n,
        ",warmup=4,rounds=11,repeats=24,bounds=on,severity=0.65"
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
