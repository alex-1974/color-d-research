module bench;

import color.cvd :
    CvdDeficiency,
    RedGreenCvdDeficiency,
    brettel1997Dichromat,
    machado2009,
    vienot1999Dichromat;

import color.rgb :
    LinearSRgb;

import replicas :
    Model,
    Variant,
    runReplica;

import std.conv :
    to;
import std.datetime.stopwatch :
    AutoStart,
    StopWatch;
import std.math :
    isInfinity,
    isNaN;
import std.stdio :
    writefln,
    writeln;


enum Workload
{
    fixedConfiguration,
    dynamicParameters
}


enum modelLabels =
[
    "vienot",
    "machado",
    "brettel"
];


enum variantLabels =
[
    "production",
    "carrier-replica",
    "direct-return",
    "out-kernel",
    "inline-chain",
    "typed-table"
];


enum workloadLabels =
[
    "fixed",
    "dynamic"
];


enum size_t variantCount = 6;


private LinearSRgb!T productionScalar(
    T,
    Model model
)(
    LinearSRgb!T color,
    uint deficiency,
    T severity
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
            severity
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


private LinearSRgb!T candidateScalar(
    T,
    Model model,
    size_t variant
)(
    LinearSRgb!T color,
    uint deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    static if (variant == 0)
    {
        return productionScalar!(
            T,
            model
        )(
            color,
            deficiency,
            severity
        );
    }
    else
    {
        return runReplica!(
            T,
            model,
            cast(Variant)(variant - 1)
        )(
            color,
            deficiency,
            severity
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


private uint deficiencyCount(Model model)
@safe pure nothrow @nogc
{
    return
        model == Model.brettel
            ? 3u
            : 2u;
}


private void validateModel(
    T,
    Model model
)()
{
    const LinearSRgb!T[8] colors =
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
        ),
        LinearSRgb!T(
            cast(T)-1.5,
            cast(T)3.0,
            cast(T)-0.0
        )
    ];

    const T[8] severities =
    [
        cast(T)0,
        cast(T)0.05,
        cast(T)0.1,
        cast(T)0.35,
        cast(T)0.65,
        cast(T)0.9,
        cast(T)0.99,
        cast(T)1
    ];

    foreach (
        deficiency;
        0u ..
        deficiencyCount(model)
    )
    {
        foreach (color; colors)
        {
            static if (model == Model.machado)
            {
                foreach (severity; severities)
                {
                    const expected =
                        productionScalar!(
                            T,
                            model
                        )(
                            color,
                            deficiency,
                            severity
                        );

                    static foreach (
                        variant;
                        1 .. variantCount
                    )
                    {
                        const actual =
                            candidateScalar!(
                                T,
                                model,
                                variant
                            )(
                                color,
                                deficiency,
                                severity
                            );

                        if (!sameColor(
                            actual,
                            expected
                        ))
                        {
                            throw new Exception(
                                "Machado scalar replica mismatch"
                            );
                        }
                    }
                }
            }
            else
            {
                const expected =
                    productionScalar!(
                        T,
                        model
                    )(
                        color,
                        deficiency,
                        cast(T)0.65
                    );

                static foreach (
                    variant;
                    1 .. variantCount
                )
                {
                    const actual =
                        candidateScalar!(
                            T,
                            model,
                            variant
                        )(
                            color,
                            deficiency,
                            cast(T)0.65
                        );

                    if (!sameColor(
                        actual,
                        expected
                    ))
                    {
                        throw new Exception(
                            "scalar replica mismatch"
                        );
                    }
                }
            }
        }
    }

    static if (model == Model.machado)
    {
        const color =
            LinearSRgb!T(
                cast(T)0.2,
                cast(T)0.4,
                cast(T)0.7
            );

        const T[3] invalid =
        [
            cast(T)-0.01,
            cast(T)1.01,
            T.nan
        ];

        foreach (severity; invalid)
        {
            const expected =
                productionScalar!(
                    T,
                    model
                )(
                    color,
                    0,
                    severity
                );

            static foreach (
                variant;
                1 .. variantCount
            )
            {
                const actual =
                    candidateScalar!(
                        T,
                        model,
                        variant
                    )(
                        color,
                        0,
                        severity
                    );

                if (!sameColor(
                    actual,
                    expected
                ))
                {
                    throw new Exception(
                        "invalid-severity replica mismatch"
                    );
                }
            }
        }
    }
}


private void validateCtfe(T)()
{
    enum color =
        LinearSRgb!T(
            cast(T)0.2,
            cast(T)0.4,
            cast(T)0.7
        );

    static foreach (
        model;
        [
            Model.vienot,
            Model.machado,
            Model.brettel
        ]
    )
    {
        enum uint deficiency = 0;
        enum T severity = cast(T)0.65;

        enum expected =
            productionScalar!(
                T,
                model
            )(
                color,
                deficiency,
                severity
            );

        static foreach (
            variant;
            1 .. variantCount
        )
        {
            enum actual =
                candidateScalar!(
                    T,
                    model,
                    variant
                )(
                    color,
                    deficiency,
                    severity
                );

            static assert(
                sameColor(
                    actual,
                    expected
                )
            );
        }
    }
}


void preflight()
{
    validateModel!(
        float,
        Model.vienot
    )();

    validateModel!(
        float,
        Model.machado
    )();

    validateModel!(
        float,
        Model.brettel
    )();

    validateModel!(
        double,
        Model.vienot
    )();

    validateModel!(
        double,
        Model.machado
    )();

    validateModel!(
        double,
        Model.brettel
    )();

    validateCtfe!float();
    validateCtfe!double();

    writeln(
        "R7.4.12 scalar CVD semantic/IEEE/invalid/CTFE preflight: PASS"
    );
}


pragma(inline, false)
private void batch(
    T,
    Model model,
    size_t variant,
    Workload workload
)(
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output,
    const(uint)[] deficiencies,
    const(T)[] severities,
    uint fixedDeficiency,
    T fixedSeverity
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);
    assert(input.length == deficiencies.length);
    assert(input.length == severities.length);

    static if (
        workload ==
        Workload.fixedConfiguration
    )
    {
        foreach (i, ref color; input)
        {
            output[i] =
                candidateScalar!(
                    T,
                    model,
                    variant
                )(
                    color,
                    fixedDeficiency,
                    fixedSeverity
                );
        }
    }
    else
    {
        foreach (i, ref color; input)
        {
            output[i] =
                candidateScalar!(
                    T,
                    model,
                    variant
                )(
                    color,
                    deficiencies[i],
                    severities[i]
                );
        }
    }
}


void runCase(
    T,
    Model model,
    size_t variant,
    Workload workload
)(
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

    auto deficiencies =
        new uint[n];

    auto severities =
        new T[n];

    uint state = 0x12345678;

    const uint count =
        deficiencyCount(model);

    foreach (i, ref color; input)
    {
        state =
            state * 1664525u +
            1013904223u;

        color.r =
            cast(T)((state >> 8) & 65535) /
            cast(T)32767 -
            cast(T)0.5;

        state =
            state * 1664525u +
            1013904223u;

        color.g =
            cast(T)((state >> 8) & 65535) /
            cast(T)32767 -
            cast(T)0.5;

        state =
            state * 1664525u +
            1013904223u;

        color.b =
            cast(T)((state >> 8) & 65535) /
            cast(T)32767 -
            cast(T)0.5;

        deficiencies[i] =
            cast(uint)(
                (i * 5 + 1) %
                count
            );

        severities[i] =
            cast(T)(
                (i * 17 + 13) %
                101
            ) /
            cast(T)100;
    }

    enum uint fixedDeficiency = 0;
    enum T fixedSeverity = cast(T)0.65;

    batch!(
        T,
        model,
        0,
        workload
    )(
        input,
        reference,
        deficiencies,
        severities,
        fixedDeficiency,
        fixedSeverity
    );

    batch!(
        T,
        model,
        variant,
        workload
    )(
        input,
        output,
        deficiencies,
        severities,
        fixedDeficiency,
        fixedSeverity
    );

    foreach (i; 0 .. n)
    {
        if (!sameColor(
            output[i],
            reference[i]
        ))
        {
            throw new Exception(
                "scalar source-shape finite-corpus mismatch"
            );
        }
    }

    foreach (_; 0 .. 4)
    {
        batch!(
            T,
            model,
            variant,
            workload
        )(
            input,
            output,
            deficiencies,
            severities,
            fixedDeficiency,
            fixedSeverity
        );
    }

    foreach (round; 0 .. 7)
    {
        double checksum = 0;

        auto timer =
            StopWatch(AutoStart.yes);

        foreach (repeat; 0 .. 4)
        {
            input[0].r =
                cast(T)(repeat + round) /
                cast(T)16;

            batch!(
                T,
                model,
                variant,
                workload
            )(
                input,
                output,
                deficiencies,
                severities,
                fixedDeficiency,
                fixedSeverity
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
            cast(double)(n * 4);

        writefln(
            "sample,D,%s,%s,%s,%s,%s,%s,%s,%.9f,%.17g",
            T.stringof,
            modelLabels[model],
            variantLabels[variant],
            workloadLabels[workload],
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
    Model model,
    Workload workload
)(
    size_t n,
    bool reverse
)
{
    if (reverse)
    {
        static foreach_reverse (
            variant;
            0 .. variantCount
        )
        {
            runCase!(
                T,
                model,
                variant,
                workload
            )(
                n,
                reverse
            );
        }
    }
    else
    {
        static foreach (
            variant;
            0 .. variantCount
        )
        {
            runCase!(
                T,
                model,
                variant,
                workload
            )(
                n,
                reverse
            );
        }
    }
}


void cases(T)(
    size_t n,
    bool reverse
)
{
    static foreach (
        workload;
        [
            Workload.fixedConfiguration,
            Workload.dynamicParameters
        ]
    )
    {
        if (reverse)
        {
            runModel!(
                T,
                Model.brettel,
                workload
            )(n, reverse);

            runModel!(
                T,
                Model.machado,
                workload
            )(n, reverse);

            runModel!(
                T,
                Model.vienot,
                workload
            )(n, reverse);
        }
        else
        {
            runModel!(
                T,
                Model.vienot,
                workload
            )(n, reverse);

            runModel!(
                T,
                Model.machado,
                workload
            )(n, reverse);

            runModel!(
                T,
                Model.brettel,
                workload
            )(n, reverse);
        }
    }
}


void main(
    string[] args
)
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
            : 8_191;

    const bool reverse =
        args.length > 2;

    if (n < 32 || n > 1_048_576)
        throw new Exception(
            "workload must be 32..1048576"
        );

    writeln(
        "metadata,D,n=",
        n,
        ",warmup=4,rounds=7,repeats=4,AoS,bounds=on"
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
