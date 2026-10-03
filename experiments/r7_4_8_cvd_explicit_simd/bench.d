module bench;

import kernels :
    Matrix3,
    Rgb,
    prepareMachado,
    prepareVienot,
    preparedMachadoBatch,
    preparedVienotBatch;

import simd_kernels :
    blockSimdMatrixBatch,
    gatherSimdMatrixBatch;

import std.conv : to;
import std.datetime.stopwatch :
    AutoStart,
    StopWatch;
import std.math :
    isInfinity,
    isNaN;
import std.stdio :
    writefln,
    writeln;

enum Model
{
    vienot,
    machado
}

enum Variant
{
    productionShape,
    gatherSimd,
    blockSimd
}

enum modelLabels =
[
    "vienot",
    "machado"
];

enum variantLabels =
[
    "prepared",
    "gather-simd",
    "block-simd"
];

enum double machadoSeverity = 0.65;


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


private bool sameColor(T)(
    Rgb!T actual,
    Rgb!T expected
)
@safe pure nothrow @nogc
{
    return
        closeComponent(
            actual.r,
            expected.r
        ) &&
        closeComponent(
            actual.g,
            expected.g
        ) &&
        closeComponent(
            actual.b,
            expected.b
        );
}


private Matrix3!T matrixFor(
    T,
    Model model
)(
    uint deficiency
)
@safe pure nothrow @nogc
{
    static if (model == Model.vienot)
    {
        return prepareVienot!T(
            deficiency
        );
    }
    else
    {
        return prepareMachado!T(
            deficiency,
            cast(T)machadoSeverity
        );
    }
}


private void referenceBatch(
    T,
    Model model
)(
    const Rgb!T[] input,
    Rgb!T[] output,
    uint deficiency
)
@safe pure nothrow @nogc
{
    static if (model == Model.vienot)
    {
        preparedVienotBatch(
            input,
            output,
            deficiency
        );
    }
    else
    {
        preparedMachadoBatch(
            input,
            output,
            deficiency,
            cast(T)machadoSeverity
        );
    }
}


pragma(inline, false)
private void runBatch(
    T,
    Model model,
    Variant variant
)(
    const Rgb!T[] input,
    Rgb!T[] output,
    uint deficiency,
    const ref Matrix3!T matrix
)
@safe pure nothrow @nogc
{
    static if (
        variant ==
        Variant.productionShape
    )
    {
        referenceBatch!(T, model)(
            input,
            output,
            deficiency
        );
    }
    else static if (
        variant ==
        Variant.gatherSimd
    )
    {
        gatherSimdMatrixBatch(
            input,
            output,
            matrix
        );
    }
    else
    {
        blockSimdMatrixBatch(
            input,
            output,
            matrix
        );
    }
}


private void validateSpecials(T, Model model)(
    uint deficiency
)
{
    Rgb!T[7] input =
    [
        Rgb!T(
            cast(T)0.2,
            cast(T)0.4,
            cast(T)0.7
        ),
        Rgb!T(
            cast(T)-0.25,
            cast(T)1.25,
            cast(T)2.0
        ),
        Rgb!T(
            cast(T)0,
            cast(T)-0.0,
            cast(T)1
        ),
        Rgb!T(
            T.nan,
            cast(T)0.25,
            cast(T)0.75
        ),
        Rgb!T(
            T.infinity,
            cast(T)0.25,
            cast(T)-0.75
        ),
        Rgb!T(
            -T.infinity,
            T.infinity,
            cast(T)0.5
        ),
        Rgb!T(
            cast(T)0.125,
            T.nan,
            -T.infinity
        )
    ];

    Rgb!T[7] reference;
    Rgb!T[7] gather;
    Rgb!T[7] block;

    const matrix =
        matrixFor!(T, model)(
            deficiency
        );

    referenceBatch!(T, model)(
        input,
        reference,
        deficiency
    );

    gatherSimdMatrixBatch(
        input,
        gather,
        matrix
    );

    blockSimdMatrixBatch(
        input,
        block,
        matrix
    );

    foreach (i; 0 .. input.length)
    {
        if (
            !sameColor(
                gather[i],
                reference[i]
            ) ||
            !sameColor(
                block[i],
                reference[i]
            )
        )
        {
            throw new Exception(
                "SIMD special-value mismatch"
            );
        }
    }

    auto gatherInPlace = input;

    gatherSimdMatrixBatch(
        gatherInPlace,
        gatherInPlace,
        matrix
    );

    auto blockInPlace = input;

    blockSimdMatrixBatch(
        blockInPlace,
        blockInPlace,
        matrix
    );

    foreach (i; 0 .. input.length)
    {
        if (
            !sameColor(
                gatherInPlace[i],
                reference[i]
            ) ||
            !sameColor(
                blockInPlace[i],
                reference[i]
            )
        )
        {
            throw new Exception(
                "SIMD in-place mismatch"
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
        new Rgb!T[n];

    auto output =
        new Rgb!T[n];

    auto reference =
        new Rgb!T[n];

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

    const matrix =
        matrixFor!(T, model)(
            deficiency
        );

    referenceBatch!(T, model)(
        input,
        reference,
        deficiency
    );

    runBatch!(
        T,
        model,
        variant
    )(
        input,
        output,
        deficiency,
        matrix
    );

    foreach (i; 0 .. n)
    {
        if (!sameColor(
            output[i],
            reference[i]
        ))
        {
            throw new Exception(
                "SIMD finite-corpus mismatch"
            );
        }
    }

    foreach (_; 0 .. 4)
    {
        runBatch!(
            T,
            model,
            variant
        )(
            input,
            output,
            deficiency,
            matrix
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

            runBatch!(
                T,
                model,
                variant
            )(
                input,
                output,
                deficiency,
                matrix
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
            "sample,D,%s,%s,%s,%s,%s,%s,%.9f,%.17g",
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
            Variant.blockSimd
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            model,
            Variant.gatherSimd
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            model,
            Variant.productionShape
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
            Variant.productionShape
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            model,
            Variant.gatherSimd
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            model,
            Variant.blockSimd
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
    foreach (index; 0u .. 2u)
    {
        const uint deficiency =
            reverse
                ? 1u - index
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


void preflight()
{
    foreach (deficiency; 0u .. 2u)
    {
        validateSpecials!(
            float,
            Model.vienot
        )(
            deficiency
        );

        validateSpecials!(
            float,
            Model.machado
        )(
            deficiency
        );

        validateSpecials!(
            double,
            Model.vienot
        )(
            deficiency
        );

        validateSpecials!(
            double,
            Model.machado
        )(
            deficiency
        );
    }

    static assert(
        __traits(compiles,
        {
            Rgb!float[4] input;
            Rgb!float[4] output;
            Matrix3!float matrix;

            gatherSimdMatrixBatch(
                input,
                output,
                matrix
            );

            blockSimdMatrixBatch(
                input,
                output,
                matrix
            );
        })
    );

    writeln(
        "R7.4.8 explicit SIMD semantic/in-place/attribute preflight: PASS"
    );
}


void main(string[] args)
{
    if (
        args.length > 1 &&
        args[1] == "preflight"
    )
    {
        preflight();
        return;
    }

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
        "metadata,D,n=",
        n,
        ",warmup=4,rounds=11,repeats=24,AoS,explicit-simd=128"
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
