module bench;

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

enum modelLabels =
[
    "vienot",
    "machado"
];

enum double machadoSeverity = 0.65;


pragma(inline, false)
bool preparedBatch(P, T)(
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


private bool close(T)(
    T actual,
    T expected
)
@safe pure nothrow @nogc
{
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
                "vectorization attribution semantic mismatch"
            );
        }
    }
}


void runCase(
    T,
    Model model,
    P
)(
    const ref P prepared,
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

    const bool referenceOk =
        preparedBatch(
            prepared,
            input,
            reference
        );

    assert(referenceOk);

    const bool firstOk =
        preparedBatch(
            prepared,
            input,
            output
        );

    assert(firstOk);

    validateSame(
        output,
        reference
    );

    foreach (_; 0 .. 4)
    {
        const bool ok =
            preparedBatch(
                prepared,
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

            const bool ok =
                preparedBatch(
                    prepared,
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
            modelLabels[model],
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
    static if (model == Model.vienot)
    {
        const prepared =
            prepareVienot1999Dichromat!T(
                cast(RedGreenCvdDeficiency)
                    deficiency
            );

        runCase!(T, model)(
            prepared,
            n,
            deficiency,
            reverse
        );
    }
    else
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

        runCase!(T, model)(
            prepared,
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
        "metadata,D,production=bed36eee31fc35d0a8843ba12e55dfd7b12042e7,n=",
        n,
        ",warmup=4,rounds=11,repeats=24,AoS,bounds=on,severity=0.65"
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
