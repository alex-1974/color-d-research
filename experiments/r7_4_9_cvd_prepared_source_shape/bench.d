module bench;

import color.cvd :
    PreparedVienot1999Dichromat,
    RedGreenCvdDeficiency,
    prepareVienot1999Dichromat;

import color.rgb :
    LinearSRgb;

import replicas :
    Matrix3,
    ReplicaPrepared,
    freeCoefficientsLoop,
    freeRefLoop,
    freeValueLoop,
    prepareReplica,
    prepareReplicaVienot;

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


enum Variant
{
    production,
    freeRef,
    freeValue,
    freeCoefficients,
    memberSnapshot,
    memberBacked
}


enum variantLabels =
[
    "production",
    "free-ref",
    "free-value",
    "free-coefficients",
    "member-snapshot",
    "member-backed"
];


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
    LinearSRgb!T actual,
    LinearSRgb!T expected
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


pragma(inline, false)
private bool runVariant(
    T,
    Variant variant
)(
    const ref PreparedVienot1999Dichromat!T production,
    const ref ReplicaPrepared!T replica,
    const ref Matrix3!T matrix,
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output
)
@safe pure nothrow @nogc
{
    static if (
        variant ==
        Variant.production
    )
    {
        return production.tryApplyInto(
            input,
            output
        );
    }
    else static if (
        variant ==
        Variant.freeRef
    )
    {
        if (input.length != output.length)
            return false;

        freeRefLoop(
            matrix,
            input,
            output
        );

        return true;
    }
    else static if (
        variant ==
        Variant.freeValue
    )
    {
        if (input.length != output.length)
            return false;

        freeValueLoop(
            matrix,
            input,
            output
        );

        return true;
    }
    else static if (
        variant ==
        Variant.freeCoefficients
    )
    {
        if (input.length != output.length)
            return false;

        freeCoefficientsLoop(
            matrix,
            input,
            output
        );

        return true;
    }
    else static if (
        variant ==
        Variant.memberSnapshot
    )
    {
        return replica.memberSnapshot(
            input,
            output
        );
    }
    else
    {
        return replica.memberBacked(
            input,
            output
        );
    }
}


private void validateSpecials(T)(
    uint deficiency
)
{
    LinearSRgb!T[7] input =
    [
        LinearSRgb!T(
            cast(T)0.2,
            cast(T)0.4,
            cast(T)0.7
        ),
        LinearSRgb!T(
            cast(T)-0.25,
            cast(T)1.25,
            cast(T)2.0
        ),
        LinearSRgb!T(
            cast(T)0,
            cast(T)-0.0,
            cast(T)1
        ),
        LinearSRgb!T(
            T.nan,
            cast(T)0.25,
            cast(T)0.75
        ),
        LinearSRgb!T(
            T.infinity,
            cast(T)0.25,
            cast(T)-0.75
        ),
        LinearSRgb!T(
            -T.infinity,
            T.infinity,
            cast(T)0.5
        ),
        LinearSRgb!T(
            cast(T)0.125,
            T.nan,
            -T.infinity
        )
    ];

    const production =
        prepareVienot1999Dichromat!T(
            cast(RedGreenCvdDeficiency)
                deficiency
        );

    const replica =
        prepareReplica!T(
            deficiency
        );

    const matrix =
        prepareReplicaVienot!T(
            deficiency
        );

    LinearSRgb!T[7] reference;

    const referenceOk =
        runVariant!(
            T,
            Variant.production
        )(
            production,
            replica,
            matrix,
            input,
            reference
        );

    assert(referenceOk);

    static foreach (
        variant;
        [
            Variant.freeRef,
            Variant.freeValue,
            Variant.freeCoefficients,
            Variant.memberSnapshot,
            Variant.memberBacked
        ]
    )
    {
        {
            LinearSRgb!T[7] output;

            const ok =
                runVariant!(
                    T,
                    variant
                )(
                    production,
                    replica,
                    matrix,
                    input,
                    output
                );

            assert(ok);

            foreach (i; 0 .. input.length)
            {
                if (!sameColor(
                    output[i],
                    reference[i]
                ))
                {
                    throw new Exception(
                        "source-shape special-value mismatch"
                    );
                }
            }

            auto inPlace = input;

            const inPlaceOk =
                runVariant!(
                    T,
                    variant
                )(
                    production,
                    replica,
                    matrix,
                    inPlace,
                    inPlace
                );

            assert(inPlaceOk);

            foreach (i; 0 .. input.length)
            {
                if (!sameColor(
                    inPlace[i],
                    reference[i]
                ))
                {
                    throw new Exception(
                        "source-shape in-place mismatch"
                    );
                }
            }
        }
    }
}


void runCase(
    T,
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

    const production =
        prepareVienot1999Dichromat!T(
            cast(RedGreenCvdDeficiency)
                deficiency
        );

    const replica =
        prepareReplica!T(
            deficiency
        );

    const matrix =
        prepareReplicaVienot!T(
            deficiency
        );

    const referenceOk =
        runVariant!(
            T,
            Variant.production
        )(
            production,
            replica,
            matrix,
            input,
            reference
        );

    assert(referenceOk);

    const firstOk =
        runVariant!(
            T,
            variant
        )(
            production,
            replica,
            matrix,
            input,
            output
        );

    assert(firstOk);

    foreach (i; 0 .. n)
    {
        if (!sameColor(
            output[i],
            reference[i]
        ))
        {
            throw new Exception(
                "source-shape finite-corpus mismatch"
            );
        }
    }

    foreach (_; 0 .. 4)
    {
        const ok =
            runVariant!(
                T,
                variant
            )(
                production,
                replica,
                matrix,
                input,
                output
            );

        assert(ok);
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

            const ok =
                runVariant!(
                    T,
                    variant
                )(
                    production,
                    replica,
                    matrix,
                    input,
                    output
                );

            assert(ok);

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


void runDeficiency(T)(
    size_t n,
    uint deficiency,
    bool reverse
)
{
    if (reverse)
    {
        runCase!(
            T,
            Variant.memberBacked
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            Variant.memberSnapshot
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            Variant.freeCoefficients
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            Variant.freeValue
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            Variant.freeRef
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            Variant.production
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
            Variant.production
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            Variant.freeRef
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            Variant.freeValue
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            Variant.freeCoefficients
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            Variant.memberSnapshot
        )(
            n,
            deficiency,
            reverse
        );

        runCase!(
            T,
            Variant.memberBacked
        )(
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
    foreach (index; 0u .. 2u)
    {
        const uint deficiency =
            reverse
                ? 1u - index
                : index;

        runDeficiency!T(
            n,
            deficiency,
            reverse
        );
    }
}


void preflight()
{
    foreach (deficiency; 0u .. 2u)
    {
        validateSpecials!float(
            deficiency
        );

        validateSpecials!double(
            deficiency
        );
    }

    writeln(
        "R7.4.9 prepared source-shape semantic/in-place preflight: PASS"
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
        "metadata,D,production=bed36eee31fc35d0a8843ba12e55dfd7b12042e7,n=",
        n,
        ",warmup=4,rounds=11,repeats=24,AoS,bounds=on,model=vienot"
    );

    if (reverse)
    {
        cases!double(
            n,
            reverse
        );

        cases!float(
            n,
            reverse
        );
    }
    else
    {
        cases!float(
            n,
            reverse
        );

        cases!double(
            n,
            reverse
        );
    }
}
