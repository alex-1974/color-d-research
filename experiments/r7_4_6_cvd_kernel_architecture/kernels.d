module kernels;

import std.math : abs, isInfinity, isNaN;

struct Rgb(T)
if (is(T == float) || is(T == double))
{
    T r;
    T g;
    T b;
}

struct Matrix3(T)
if (is(T == float) || is(T == double))
{
    T m00; T m01; T m02;
    T m10; T m11; T m12;
    T m20; T m21; T m22;
}

struct BrettelPlan(T)
if (is(T == float) || is(T == double))
{
    Matrix3!T first;
    Matrix3!T second;
    T nr;
    T ng;
    T nb;
}

private Matrix3!T precisionMatrix(T)(Matrix3!double matrix)
@safe pure nothrow @nogc
{
    return Matrix3!T(
        cast(T)matrix.m00, cast(T)matrix.m01, cast(T)matrix.m02,
        cast(T)matrix.m10, cast(T)matrix.m11, cast(T)matrix.m12,
        cast(T)matrix.m20, cast(T)matrix.m21, cast(T)matrix.m22
    );
}

pragma(inline, true)
private void directWrite(T)(
    ref Rgb!T output,
    const ref Matrix3!T matrix,
    T r,
    T g,
    T b
)
@safe pure nothrow @nogc
{
    output.r = matrix.m00 * r + matrix.m01 * g + matrix.m02 * b;
    output.g = matrix.m10 * r + matrix.m11 * g + matrix.m12 * b;
    output.b = matrix.m20 * r + matrix.m21 * g + matrix.m22 * b;
}

private enum Matrix3!double vienotProtan =
    Matrix3!double(
        0.11238,  0.88762, 0.0,
        0.11238,  0.88762, 0.0,
        0.00401, -0.00401, 1.0
    );

private enum Matrix3!double vienotDeutan =
    Matrix3!double(
         0.29275, 0.70725, 0.0,
         0.29275, 0.70725, 0.0,
        -0.02234, 0.02234, 1.0
    );

private enum Matrix3!double brettelProtan1 =
    Matrix3!double(
         0.14980,  1.19548, -0.34528,
         0.10764,  0.84864,  0.04372,
         0.00384, -0.00540,  1.00156
    );

private enum Matrix3!double brettelProtan2 =
    Matrix3!double(
         0.14570,  1.16172, -0.30742,
         0.10816,  0.85291,  0.03892,
         0.00386, -0.00524,  1.00139
    );

private enum Matrix3!double brettelDeutan1 =
    Matrix3!double(
         0.36477,  0.86381, -0.22858,
         0.26294,  0.64245,  0.09462,
        -0.02006,  0.02728,  0.99278
    );

private enum Matrix3!double brettelDeutan2 =
    Matrix3!double(
         0.37298,  0.88166, -0.25464,
         0.25954,  0.63506,  0.10540,
        -0.01980,  0.02784,  0.99196
    );

private enum Matrix3!double brettelTritan1 =
    Matrix3!double(
         1.01277,  0.13548, -0.14826,
        -0.01243,  0.86812,  0.14431,
         0.07589,  0.80500,  0.11911
    );

private enum Matrix3!double brettelTritan2 =
    Matrix3!double(
         0.93678,  0.18979, -0.12657,
         0.06154,  0.81526,  0.12320,
        -0.37562,  1.12767,  0.24796
    );

private enum Matrix3!double identityMatrix =
    Matrix3!double(
        1, 0, 0,
        0, 1, 0,
        0, 0, 1
    );

private immutable Matrix3!double[11] machadoProtanTable =
[
    identityMatrix,
    Matrix3!double(.856167,.182038,-.038205,.029342,.955115,.015544,-.002880,-.001563,1.004443),
    Matrix3!double(.734766,.334872,-.069637,.051840,.919198,.028963,-.004928,-.004209,1.009137),
    Matrix3!double(.630323,.465641,-.095964,.069181,.890046,.040773,-.006308,-.007724,1.014032),
    Matrix3!double(.539009,.579343,-.118352,.082546,.866121,.051332,-.007136,-.011959,1.019095),
    Matrix3!double(.458064,.679578,-.137642,.092785,.846313,.060902,-.007494,-.016807,1.024301),
    Matrix3!double(.385450,.769005,-.154455,.100526,.829802,.069673,-.007442,-.022190,1.029632),
    Matrix3!double(.319627,.849633,-.169261,.106241,.815969,.077790,-.007025,-.028051,1.035076),
    Matrix3!double(.259411,.923008,-.182420,.110296,.804340,.085364,-.006276,-.034346,1.040622),
    Matrix3!double(.203876,.990338,-.194214,.112975,.794542,.092483,-.005222,-.041043,1.046265),
    Matrix3!double(.152286,1.052583,-.204868,.114503,.786281,.099216,-.003882,-.048116,1.051998)
];

private immutable Matrix3!double[11] machadoDeutanTable =
[
    identityMatrix,
    Matrix3!double(.866435,.177704,-.044139,.049567,.939063,.011370,-.003453,.007233,.996220),
    Matrix3!double(.760729,.319078,-.079807,.090568,.889315,.020117,-.006027,.013325,.992702),
    Matrix3!double(.675425,.433850,-.109275,.125303,.847755,.026942,-.007950,.018572,.989378),
    Matrix3!double(.605511,.528560,-.134071,.155318,.812366,.032316,-.009376,.023176,.986200),
    Matrix3!double(.547494,.607765,-.155259,.181692,.781742,.036566,-.010410,.027275,.983136),
    Matrix3!double(.498864,.674741,-.173604,.205199,.754872,.039929,-.011131,.030969,.980162),
    Matrix3!double(.457771,.731899,-.189670,.226409,.731012,.042579,-.011595,.034333,.977261),
    Matrix3!double(.422823,.781057,-.203881,.245752,.709602,.044646,-.011843,.037423,.974421),
    Matrix3!double(.392952,.823610,-.216562,.263559,.690210,.046232,-.011910,.040281,.971630),
    Matrix3!double(.367322,.860646,-.227968,.280085,.672501,.047413,-.011820,.042940,.968881)
];

private const(Matrix3!double[]) machadoTable(uint deficiency)
@safe pure nothrow @nogc
{
    assert(deficiency < 2);
    return deficiency == 0
        ? machadoProtanTable[]
        : machadoDeutanTable[];
}

Matrix3!T prepareVienot(T)(uint deficiency)
@safe pure nothrow @nogc
{
    assert(deficiency < 2);
    return precisionMatrix!T(
        deficiency == 0 ? vienotProtan : vienotDeutan
    );
}

BrettelPlan!T prepareBrettel(T)(uint deficiency)
@safe pure nothrow @nogc
{
    switch (deficiency)
    {
        case 0:
            return BrettelPlan!T(
                precisionMatrix!T(brettelProtan1),
                precisionMatrix!T(brettelProtan2),
                cast(T)0.00048,
                cast(T)0.00393,
                cast(T)-0.00441
            );

        case 1:
            return BrettelPlan!T(
                precisionMatrix!T(brettelDeutan1),
                precisionMatrix!T(brettelDeutan2),
                cast(T)-0.00281,
                cast(T)-0.00611,
                cast(T)0.00892
            );

        case 2:
            return BrettelPlan!T(
                precisionMatrix!T(brettelTritan1),
                precisionMatrix!T(brettelTritan2),
                cast(T)0.03901,
                cast(T)-0.02788,
                cast(T)-0.01113
            );

        default:
            assert(0, "unsupported Brettel deficiency");
    }
}

Matrix3!T prepareMachado(T)(uint deficiency, T severity)
@safe pure nothrow @nogc
{
    assert(deficiency < 2);
    assert(severity >= cast(T)0 && severity <= cast(T)1);

    const table = machadoTable(deficiency);
    const T scaled = severity * cast(T)10;
    const size_t lower = cast(size_t)scaled;

    if (lower >= 10)
        return precisionMatrix!T(table[10]);

    const T alpha = scaled - cast(T)lower;
    const x = precisionMatrix!T(table[lower]);
    const y = precisionMatrix!T(table[lower + 1]);

    return Matrix3!T(
        x.m00 + (y.m00 - x.m00) * alpha,
        x.m01 + (y.m01 - x.m01) * alpha,
        x.m02 + (y.m02 - x.m02) * alpha,
        x.m10 + (y.m10 - x.m10) * alpha,
        x.m11 + (y.m11 - x.m11) * alpha,
        x.m12 + (y.m12 - x.m12) * alpha,
        x.m20 + (y.m20 - x.m20) * alpha,
        x.m21 + (y.m21 - x.m21) * alpha,
        x.m22 + (y.m22 - x.m22) * alpha
    );
}

Rgb!T scalarVienot(T)(Rgb!T color, uint deficiency)
@safe pure nothrow @nogc
{
    const matrix = prepareVienot!T(deficiency);
    Rgb!T output;
    directWrite(output, matrix, color.r, color.g, color.b);
    return output;
}

Rgb!T scalarMachado(T)(Rgb!T color, uint deficiency, T severity)
@safe pure nothrow @nogc
{
    const matrix = prepareMachado!T(deficiency, severity);
    Rgb!T output;
    directWrite(output, matrix, color.r, color.g, color.b);
    return output;
}

Rgb!T scalarBrettel(T)(Rgb!T color, uint deficiency)
@safe pure nothrow @nogc
{
    const plan = prepareBrettel!T(deficiency);
    const matrix =
        color.r * plan.nr +
        color.g * plan.ng +
        color.b * plan.nb >= cast(T)0
            ? plan.first
            : plan.second;

    Rgb!T output;
    directWrite(output, matrix, color.r, color.g, color.b);
    return output;
}

void scalarVienotBatch(T)(
    const Rgb!T[] input,
    Rgb!T[] output,
    uint deficiency
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);
    foreach (i, ref color; input)
        output[i] = scalarVienot!T(color, deficiency);
}

void preparedVienotBatch(T)(
    const Rgb!T[] input,
    Rgb!T[] output,
    uint deficiency
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);
    const matrix = prepareVienot!T(deficiency);

    foreach (i, ref color; input)
    {
        const T r = color.r;
        const T g = color.g;
        const T b = color.b;
        directWrite(output[i], matrix, r, g, b);
    }
}

private void specializedVienotLoop(T, uint deficiency)(
    const Rgb!T[] input,
    Rgb!T[] output
)
@safe pure nothrow @nogc
{
    static assert(deficiency < 2);
    assert(input.length == output.length);

    enum source =
        deficiency == 0
            ? vienotProtan
            : vienotDeutan;

    enum matrix = precisionMatrix!T(source);

    foreach (i, ref color; input)
    {
        const T r = color.r;
        const T g = color.g;
        const T b = color.b;

        /*
         * The first two Viénot rows are identical. Compute that row once and
         * assign it twice. The third row retains the generic operation order,
         * including explicit zero/one coefficients, so IEEE-special behavior
         * remains observable instead of being optimized away in source.
         */
        const T rg =
            matrix.m00 * r +
            matrix.m01 * g +
            matrix.m02 * b;

        output[i].r = rg;
        output[i].g = rg;
        output[i].b =
            matrix.m20 * r +
            matrix.m21 * g +
            matrix.m22 * b;
    }
}

void specializedVienotBatch(T)(
    const Rgb!T[] input,
    Rgb!T[] output,
    uint deficiency
)
@safe pure nothrow @nogc
{
    assert(deficiency < 2);

    if (deficiency == 0)
        specializedVienotLoop!(T, 0)(input, output);
    else
        specializedVienotLoop!(T, 1)(input, output);
}

void scalarMachadoBatch(T)(
    const Rgb!T[] input,
    Rgb!T[] output,
    uint deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);
    foreach (i, ref color; input)
        output[i] = scalarMachado!T(color, deficiency, severity);
}

void preparedMachadoBatch(T)(
    const Rgb!T[] input,
    Rgb!T[] output,
    uint deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);
    const matrix = prepareMachado!T(deficiency, severity);

    foreach (i, ref color; input)
    {
        const T r = color.r;
        const T g = color.g;
        const T b = color.b;
        directWrite(output[i], matrix, r, g, b);
    }
}

void specializedMachadoBatch(T)(
    const Rgb!T[] input,
    Rgb!T[] output,
    uint deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);
    const matrix = prepareMachado!T(deficiency, severity);

    const T m00 = matrix.m00;
    const T m01 = matrix.m01;
    const T m02 = matrix.m02;
    const T m10 = matrix.m10;
    const T m11 = matrix.m11;
    const T m12 = matrix.m12;
    const T m20 = matrix.m20;
    const T m21 = matrix.m21;
    const T m22 = matrix.m22;

    foreach (i, ref color; input)
    {
        const T r = color.r;
        const T g = color.g;
        const T b = color.b;

        output[i].r = m00 * r + m01 * g + m02 * b;
        output[i].g = m10 * r + m11 * g + m12 * b;
        output[i].b = m20 * r + m21 * g + m22 * b;
    }
}

void scalarBrettelBatch(T)(
    const Rgb!T[] input,
    Rgb!T[] output,
    uint deficiency
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);
    foreach (i, ref color; input)
        output[i] = scalarBrettel!T(color, deficiency);
}

void preparedBrettelBatch(T)(
    const Rgb!T[] input,
    Rgb!T[] output,
    uint deficiency
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);
    const plan = prepareBrettel!T(deficiency);

    foreach (i, ref color; input)
    {
        const T r = color.r;
        const T g = color.g;
        const T b = color.b;

        const matrix =
            r * plan.nr +
            g * plan.ng +
            b * plan.nb >= cast(T)0
                ? plan.first
                : plan.second;

        directWrite(output[i], matrix, r, g, b);
    }
}

pragma(inline, true)
private void writeSelectedBrettel(T)(
    ref Rgb!T output,
    const ref BrettelPlan!T plan,
    T r,
    T g,
    T b
)
@safe pure nothrow @nogc
{
    const bool first =
        r * plan.nr +
        g * plan.ng +
        b * plan.nb >= cast(T)0;

    if (first)
        directWrite(output, plan.first, r, g, b);
    else
        directWrite(output, plan.second, r, g, b);
}

void specializedBrettelBatch(T)(
    const Rgb!T[] input,
    Rgb!T[] output,
    uint deficiency
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);
    const plan = prepareBrettel!T(deficiency);

    foreach (i, ref color; input)
    {
        const T r = color.r;
        const T g = color.g;
        const T b = color.b;
        writeSelectedBrettel(output[i], plan, r, g, b);
    }
}

private bool componentMatches(T)(T actual, T expected)
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

    return abs(actual - expected) <= tolerance;
}

private void compareColor(T)(Rgb!T actual, Rgb!T expected)
@safe pure nothrow @nogc
{
    assert(componentMatches(actual.r, expected.r));
    assert(componentMatches(actual.g, expected.g));
    assert(componentMatches(actual.b, expected.b));
}

void validateKernels(T)()
@safe pure nothrow @nogc
{
    enum severity = cast(T)0.65;

    Rgb!T[1] input;
    Rgb!T[1] output;

    uint state = 0x12345678;

    foreach (_; 0 .. 65536)
    {
        state = state * 1664525u + 1013904223u;
        input[0].r =
            cast(T)((state >> 8) & 65535) /
            cast(T)32767 -
            cast(T)0.5;

        state = state * 1664525u + 1013904223u;
        input[0].g =
            cast(T)((state >> 8) & 65535) /
            cast(T)32767 -
            cast(T)0.5;

        state = state * 1664525u + 1013904223u;
        input[0].b =
            cast(T)((state >> 8) & 65535) /
            cast(T)32767 -
            cast(T)0.5;

        foreach (deficiency; 0u .. 2u)
        {
            const vienotReference =
                scalarVienot!T(input[0], deficiency);

            preparedVienotBatch!T(input[], output[], deficiency);
            compareColor(output[0], vienotReference);

            specializedVienotBatch!T(input[], output[], deficiency);
            compareColor(output[0], vienotReference);

            const machadoReference =
                scalarMachado!T(input[0], deficiency, severity);

            preparedMachadoBatch!T(
                input[],
                output[],
                deficiency,
                severity
            );
            compareColor(output[0], machadoReference);

            specializedMachadoBatch!T(
                input[],
                output[],
                deficiency,
                severity
            );
            compareColor(output[0], machadoReference);
        }

        foreach (deficiency; 0u .. 3u)
        {
            const brettelReference =
                scalarBrettel!T(input[0], deficiency);

            preparedBrettelBatch!T(
                input[],
                output[],
                deficiency
            );
            compareColor(output[0], brettelReference);

            specializedBrettelBatch!T(
                input[],
                output[],
                deficiency
            );
            compareColor(output[0], brettelReference);
        }
    }

    const Rgb!T[7] edges =
    [
        Rgb!T(cast(T)0, cast(T)0, cast(T)0),
        Rgb!T(cast(T)1, cast(T)1, cast(T)1),
        Rgb!T(cast(T)-0.25, cast(T)1.25, cast(T)2),
        Rgb!T(T.nan, cast(T)0.25, cast(T)0.75),
        Rgb!T(T.infinity, cast(T)0.25, cast(T)0.75),
        Rgb!T(-T.infinity, T.infinity, cast(T)0),
        Rgb!T(-cast(T)0, cast(T)0, -cast(T)0)
    ];

    foreach (color; edges)
    {
        input[0] = color;

        foreach (deficiency; 0u .. 2u)
        {
            const reference =
                scalarVienot!T(color, deficiency);

            preparedVienotBatch!T(input[], output[], deficiency);
            compareColor(output[0], reference);

            specializedVienotBatch!T(input[], output[], deficiency);
            compareColor(output[0], reference);
        }
    }

    enum ctfeInput =
        Rgb!T(
            cast(T)0.2,
            cast(T)0.4,
            cast(T)0.7
        );

    enum ctfeVienot =
        scalarVienot!T(ctfeInput, 0);

    enum ctfeMachado =
        scalarMachado!T(
            ctfeInput,
            1,
            cast(T)0.65
        );

    enum ctfeBrettel =
        scalarBrettel!T(ctfeInput, 2);

    static assert(
        ctfeVienot.r == ctfeVienot.r &&
        ctfeMachado.g == ctfeMachado.g &&
        ctfeBrettel.b == ctfeBrettel.b
    );
}
