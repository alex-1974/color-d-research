module replicas;

import color.rgb :
    LinearSRgb;


enum Model
{
    vienot,
    machado,
    brettel
}


enum Variant
{
    carrierReplica,
    directReturn,
    outKernel,
    inlineChain,
    typedTable,
    typedStatic
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


private struct MatrixCarrier(T)
{
    Matrix3!T matrix;

    LinearSRgb!T apply(
        LinearSRgb!T color
    ) const
    @safe pure nothrow @nogc
    {
        return applyMatrix(
            matrix,
            color
        );
    }
}


private struct BrettelCarrier(T)
{
    BrettelPlan!T plan;

    LinearSRgb!T apply(
        LinearSRgb!T color
    ) const
    @safe pure nothrow @nogc
    {
        return applyBrettelPlan(
            plan,
            color
        );
    }
}


private LinearSRgb!T applyMatrix(T)(
    const Matrix3!T matrix,
    LinearSRgb!T color
)
@safe pure nothrow @nogc
{
    return LinearSRgb!T(
        matrix.m00 * color.r +
        matrix.m01 * color.g +
        matrix.m02 * color.b,

        matrix.m10 * color.r +
        matrix.m11 * color.g +
        matrix.m12 * color.b,

        matrix.m20 * color.r +
        matrix.m21 * color.g +
        matrix.m22 * color.b
    );
}


private LinearSRgb!T applyBrettelPlan(T)(
    const BrettelPlan!T plan,
    LinearSRgb!T color
)
@safe pure nothrow @nogc
{
    const matrix =
        color.r * plan.nr +
        color.g * plan.ng +
        color.b * plan.nb >= cast(T)0
            ? plan.first
            : plan.second;

    return applyMatrix(
        matrix,
        color
    );
}


pragma(inline, true)
private LinearSRgb!T inlineApplyMatrix(T)(
    const Matrix3!T matrix,
    LinearSRgb!T color
)
@safe pure nothrow @nogc
{
    return LinearSRgb!T(
        matrix.m00 * color.r +
        matrix.m01 * color.g +
        matrix.m02 * color.b,

        matrix.m10 * color.r +
        matrix.m11 * color.g +
        matrix.m12 * color.b,

        matrix.m20 * color.r +
        matrix.m21 * color.g +
        matrix.m22 * color.b
    );
}


private Matrix3!T castMatrix(T)(
    Matrix3!double matrix
)
@safe pure nothrow @nogc
{
    return Matrix3!T(
        cast(T)matrix.m00,
        cast(T)matrix.m01,
        cast(T)matrix.m02,
        cast(T)matrix.m10,
        cast(T)matrix.m11,
        cast(T)matrix.m12,
        cast(T)matrix.m20,
        cast(T)matrix.m21,
        cast(T)matrix.m22
    );
}


pragma(inline, true)
private Matrix3!T inlineCastMatrix(T)(
    Matrix3!double matrix
)
@safe pure nothrow @nogc
{
    return Matrix3!T(
        cast(T)matrix.m00,
        cast(T)matrix.m01,
        cast(T)matrix.m02,
        cast(T)matrix.m10,
        cast(T)matrix.m11,
        cast(T)matrix.m12,
        cast(T)matrix.m20,
        cast(T)matrix.m21,
        cast(T)matrix.m22
    );
}


private Matrix3!T interpolateMatrix(T)(
    Matrix3!T first,
    Matrix3!T second,
    T alpha
)
@safe pure nothrow @nogc
{
    return Matrix3!T(
        first.m00 + (second.m00 - first.m00) * alpha,
        first.m01 + (second.m01 - first.m01) * alpha,
        first.m02 + (second.m02 - first.m02) * alpha,

        first.m10 + (second.m10 - first.m10) * alpha,
        first.m11 + (second.m11 - first.m11) * alpha,
        first.m12 + (second.m12 - first.m12) * alpha,

        first.m20 + (second.m20 - first.m20) * alpha,
        first.m21 + (second.m21 - first.m21) * alpha,
        first.m22 + (second.m22 - first.m22) * alpha
    );
}


pragma(inline, true)
private Matrix3!T inlineInterpolateMatrix(T)(
    Matrix3!T first,
    Matrix3!T second,
    T alpha
)
@safe pure nothrow @nogc
{
    return Matrix3!T(
        first.m00 + (second.m00 - first.m00) * alpha,
        first.m01 + (second.m01 - first.m01) * alpha,
        first.m02 + (second.m02 - first.m02) * alpha,

        first.m10 + (second.m10 - first.m10) * alpha,
        first.m11 + (second.m11 - first.m11) * alpha,
        first.m12 + (second.m12 - first.m12) * alpha,

        first.m20 + (second.m20 - first.m20) * alpha,
        first.m21 + (second.m21 - first.m21) * alpha,
        first.m22 + (second.m22 - first.m22) * alpha
    );
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


private enum Matrix3!double[11] machadoProtanTable =
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

private enum Matrix3!double[11] machadoDeutanTable =
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


private bool validSeverity(T)(
    T severity
)
@safe pure nothrow @nogc
{
    return
        severity >= cast(T)0 &&
        severity <= cast(T)1;
}


private Matrix3!T matrixAtSeverity(T, alias table)(
    T severity
)
@safe pure nothrow @nogc
{
    const T scaled =
        severity * cast(T)10;

    const size_t lower =
        cast(size_t)scaled;

    if (lower >= 10)
        return castMatrix!T(
            table[10]
        );

    const T alpha =
        scaled - cast(T)lower;

    return interpolateMatrix(
        castMatrix!T(table[lower]),
        castMatrix!T(table[lower + 1]),
        alpha
    );
}


pragma(inline, true)
private Matrix3!T inlineMatrixAtSeverity(T, alias table)(
    T severity
)
@safe pure nothrow @nogc
{
    const T scaled =
        severity * cast(T)10;

    const size_t lower =
        cast(size_t)scaled;

    if (lower >= 10)
        return inlineCastMatrix!T(
            table[10]
        );

    const T alpha =
        scaled - cast(T)lower;

    return inlineInterpolateMatrix(
        inlineCastMatrix!T(table[lower]),
        inlineCastMatrix!T(table[lower + 1]),
        alpha
    );
}


private Matrix3!T prepareVienotMatrix(T)(
    uint deficiency
)
@safe pure nothrow @nogc
{
    assert(deficiency < 2);

    return castMatrix!T(
        deficiency == 0
            ? vienotProtan
            : vienotDeutan
    );
}


private BrettelPlan!T prepareBrettelPlan(T)(
    uint deficiency
)
@safe pure nothrow @nogc
{
    final switch (deficiency)
    {
        case 0:
            return BrettelPlan!T(
                castMatrix!T(brettelProtan1),
                castMatrix!T(brettelProtan2),
                cast(T)0.00048,
                cast(T)0.00393,
                cast(T)-0.00441
            );

        case 1:
            return BrettelPlan!T(
                castMatrix!T(brettelDeutan1),
                castMatrix!T(brettelDeutan2),
                cast(T)-0.00281,
                cast(T)-0.00611,
                cast(T)0.00892
            );

        case 2:
            return BrettelPlan!T(
                castMatrix!T(brettelTritan1),
                castMatrix!T(brettelTritan2),
                cast(T)0.03901,
                cast(T)-0.02788,
                cast(T)-0.01113
            );
    }
}


private MatrixCarrier!T prepareVienotCarrier(T)(
    uint deficiency
)
@safe pure nothrow @nogc
{
    return MatrixCarrier!T(
        prepareVienotMatrix!T(
            deficiency
        )
    );
}


private BrettelCarrier!T prepareBrettelCarrier(T)(
    uint deficiency
)
@safe pure nothrow @nogc
{
    return BrettelCarrier!T(
        prepareBrettelPlan!T(
            deficiency
        )
    );
}


private bool tryPrepareMachadoCarrier(T)(
    uint deficiency,
    T severity,
    out MatrixCarrier!T prepared
)
@safe pure nothrow @nogc
{
    if (!validSeverity(severity))
        return false;

    if (deficiency == 0)
    {
        prepared =
            MatrixCarrier!T(
                matrixAtSeverity!(
                    T,
                    machadoProtanTable
                )(
                    severity
                )
            );
    }
    else
    {
        assert(deficiency == 1);

        prepared =
            MatrixCarrier!T(
                matrixAtSeverity!(
                    T,
                    machadoDeutanTable
                )(
                    severity
                )
            );
    }

    return true;
}


LinearSRgb!T carrierReplicaVienot(T)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    return
        prepareVienotCarrier!T(
            deficiency
        )
        .apply(color);
}


LinearSRgb!T carrierReplicaBrettel(T)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    return
        prepareBrettelCarrier!T(
            deficiency
        )
        .apply(color);
}


LinearSRgb!T carrierReplicaMachado(T)(
    LinearSRgb!T color,
    uint deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    MatrixCarrier!T prepared;

    if (!tryPrepareMachadoCarrier(
        deficiency,
        severity,
        prepared
    ))
    {
        return LinearSRgb!T.init;
    }

    return prepared.apply(
        color
    );
}


LinearSRgb!T directReturnVienot(T)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    return applyMatrix(
        prepareVienotMatrix!T(
            deficiency
        ),
        color
    );
}


LinearSRgb!T directReturnBrettel(T)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    return applyBrettelPlan(
        prepareBrettelPlan!T(
            deficiency
        ),
        color
    );
}


LinearSRgb!T directReturnMachado(T)(
    LinearSRgb!T color,
    uint deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    if (!validSeverity(severity))
        return LinearSRgb!T.init;

    const matrix =
        deficiency == 0
            ? matrixAtSeverity!(
                T,
                machadoProtanTable
            )(
                severity
            )
            : matrixAtSeverity!(
                T,
                machadoDeutanTable
            )(
                severity
            );

    return applyMatrix(
        matrix,
        color
    );
}


private void prepareVienotOut(T)(
    uint deficiency,
    out Matrix3!T matrix
)
@safe pure nothrow @nogc
{
    matrix =
        prepareVienotMatrix!T(
            deficiency
        );
}


private void prepareBrettelOut(T)(
    uint deficiency,
    out BrettelPlan!T plan
)
@safe pure nothrow @nogc
{
    plan =
        prepareBrettelPlan!T(
            deficiency
        );
}


private bool prepareMachadoOut(T)(
    uint deficiency,
    T severity,
    out Matrix3!T matrix
)
@safe pure nothrow @nogc
{
    if (!validSeverity(severity))
        return false;

    matrix =
        deficiency == 0
            ? matrixAtSeverity!(
                T,
                machadoProtanTable
            )(
                severity
            )
            : matrixAtSeverity!(
                T,
                machadoDeutanTable
            )(
                severity
            );

    return true;
}


LinearSRgb!T outKernelVienot(T)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    Matrix3!T matrix;

    prepareVienotOut(
        deficiency,
        matrix
    );

    return applyMatrix(
        matrix,
        color
    );
}


LinearSRgb!T outKernelBrettel(T)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    BrettelPlan!T plan;

    prepareBrettelOut(
        deficiency,
        plan
    );

    return applyBrettelPlan(
        plan,
        color
    );
}


LinearSRgb!T outKernelMachado(T)(
    LinearSRgb!T color,
    uint deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    Matrix3!T matrix;

    if (!prepareMachadoOut(
        deficiency,
        severity,
        matrix
    ))
    {
        return LinearSRgb!T.init;
    }

    return applyMatrix(
        matrix,
        color
    );
}


pragma(inline, true)
private Matrix3!T inlinePrepareVienot(T)(
    uint deficiency
)
@safe pure nothrow @nogc
{
    return inlineCastMatrix!T(
        deficiency == 0
            ? vienotProtan
            : vienotDeutan
    );
}


pragma(inline, true)
private BrettelPlan!T inlinePrepareBrettel(T)(
    uint deficiency
)
@safe pure nothrow @nogc
{
    final switch (deficiency)
    {
        case 0:
            return BrettelPlan!T(
                inlineCastMatrix!T(brettelProtan1),
                inlineCastMatrix!T(brettelProtan2),
                cast(T)0.00048,
                cast(T)0.00393,
                cast(T)-0.00441
            );

        case 1:
            return BrettelPlan!T(
                inlineCastMatrix!T(brettelDeutan1),
                inlineCastMatrix!T(brettelDeutan2),
                cast(T)-0.00281,
                cast(T)-0.00611,
                cast(T)0.00892
            );

        case 2:
            return BrettelPlan!T(
                inlineCastMatrix!T(brettelTritan1),
                inlineCastMatrix!T(brettelTritan2),
                cast(T)0.03901,
                cast(T)-0.02788,
                cast(T)-0.01113
            );
    }
}


pragma(inline, true)
LinearSRgb!T inlineChainVienot(T)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    return inlineApplyMatrix(
        inlinePrepareVienot!T(
            deficiency
        ),
        color
    );
}


pragma(inline, true)
LinearSRgb!T inlineChainBrettel(T)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    const plan =
        inlinePrepareBrettel!T(
            deficiency
        );

    const matrix =
        color.r * plan.nr +
        color.g * plan.ng +
        color.b * plan.nb >= cast(T)0
            ? plan.first
            : plan.second;

    return inlineApplyMatrix(
        matrix,
        color
    );
}


pragma(inline, true)
LinearSRgb!T inlineChainMachado(T)(
    LinearSRgb!T color,
    uint deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    if (!validSeverity(severity))
        return LinearSRgb!T.init;

    const matrix =
        deficiency == 0
            ? inlineMatrixAtSeverity!(
                T,
                machadoProtanTable
            )(
                severity
            )
            : inlineMatrixAtSeverity!(
                T,
                machadoDeutanTable
            )(
                severity
            );

    return inlineApplyMatrix(
        matrix,
        color
    );
}


private Matrix3!T[11] castTable(T)(
    Matrix3!double[11] source
)
@safe pure nothrow @nogc
{
    Matrix3!T[11] result;

    foreach (i; 0 .. source.length)
        result[i] =
            castMatrix!T(
                source[i]
            );

    return result;
}


private template TypedConstants(T)
{
    enum Matrix3!T vienotP =
        castMatrix!T(
            vienotProtan
        );

    enum Matrix3!T vienotD =
        castMatrix!T(
            vienotDeutan
        );

    enum BrettelPlan!T brettelP =
        BrettelPlan!T(
            castMatrix!T(brettelProtan1),
            castMatrix!T(brettelProtan2),
            cast(T)0.00048,
            cast(T)0.00393,
            cast(T)-0.00441
        );

    enum BrettelPlan!T brettelD =
        BrettelPlan!T(
            castMatrix!T(brettelDeutan1),
            castMatrix!T(brettelDeutan2),
            cast(T)-0.00281,
            cast(T)-0.00611,
            cast(T)0.00892
        );

    enum BrettelPlan!T brettelT =
        BrettelPlan!T(
            castMatrix!T(brettelTritan1),
            castMatrix!T(brettelTritan2),
            cast(T)0.03901,
            cast(T)-0.02788,
            cast(T)-0.01113
        );

    enum Matrix3!T[11] machadoP =
        castTable!T(
            machadoProtanTable
        );

    enum Matrix3!T[11] machadoD =
        castTable!T(
            machadoDeutanTable
        );
}


private immutable Matrix3!float staticVienotProtanFloat =
    castMatrix!float(
        vienotProtan
    );

private immutable Matrix3!float staticVienotDeutanFloat =
    castMatrix!float(
        vienotDeutan
    );

private immutable Matrix3!double staticVienotProtanDouble =
    vienotProtan;

private immutable Matrix3!double staticVienotDeutanDouble =
    vienotDeutan;


private immutable BrettelPlan!float staticBrettelProtanFloat =
    BrettelPlan!float(
        castMatrix!float(brettelProtan1),
        castMatrix!float(brettelProtan2),
        cast(float)0.00048,
        cast(float)0.00393,
        cast(float)-0.00441
    );

private immutable BrettelPlan!float staticBrettelDeutanFloat =
    BrettelPlan!float(
        castMatrix!float(brettelDeutan1),
        castMatrix!float(brettelDeutan2),
        cast(float)-0.00281,
        cast(float)-0.00611,
        cast(float)0.00892
    );

private immutable BrettelPlan!float staticBrettelTritanFloat =
    BrettelPlan!float(
        castMatrix!float(brettelTritan1),
        castMatrix!float(brettelTritan2),
        cast(float)0.03901,
        cast(float)-0.02788,
        cast(float)-0.01113
    );

private immutable BrettelPlan!double staticBrettelProtanDouble =
    BrettelPlan!double(
        brettelProtan1,
        brettelProtan2,
        0.00048,
        0.00393,
        -0.00441
    );

private immutable BrettelPlan!double staticBrettelDeutanDouble =
    BrettelPlan!double(
        brettelDeutan1,
        brettelDeutan2,
        -0.00281,
        -0.00611,
        0.00892
    );

private immutable BrettelPlan!double staticBrettelTritanDouble =
    BrettelPlan!double(
        brettelTritan1,
        brettelTritan2,
        0.03901,
        -0.02788,
        -0.01113
    );


private immutable Matrix3!float[11] staticMachadoProtanFloat =
    castTable!float(
        machadoProtanTable
    );

private immutable Matrix3!float[11] staticMachadoDeutanFloat =
    castTable!float(
        machadoDeutanTable
    );

private immutable Matrix3!double[11] staticMachadoProtanDouble =
    machadoProtanTable;

private immutable Matrix3!double[11] staticMachadoDeutanDouble =
    machadoDeutanTable;


private LinearSRgb!T applyMatrixRef(T)(
    const ref Matrix3!T matrix,
    LinearSRgb!T color
)
@safe pure nothrow @nogc
{
    return LinearSRgb!T(
        matrix.m00 * color.r +
        matrix.m01 * color.g +
        matrix.m02 * color.b,

        matrix.m10 * color.r +
        matrix.m11 * color.g +
        matrix.m12 * color.b,

        matrix.m20 * color.r +
        matrix.m21 * color.g +
        matrix.m22 * color.b
    );
}


private LinearSRgb!T applyBrettelPlanRef(T)(
    const ref BrettelPlan!T plan,
    LinearSRgb!T color
)
@safe pure nothrow @nogc
{
    const ref matrix =
        color.r * plan.nr +
        color.g * plan.ng +
        color.b * plan.nb >= cast(T)0
            ? plan.first
            : plan.second;

    return applyMatrixRef(
        matrix,
        color
    );
}


private LinearSRgb!T typedStaticVienotRuntime(T)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    static if (is(T == float))
    {
        return
            deficiency == 0
                ? applyMatrixRef(
                    staticVienotProtanFloat,
                    color
                )
                : applyMatrixRef(
                    staticVienotDeutanFloat,
                    color
                );
    }
    else
    {
        return
            deficiency == 0
                ? applyMatrixRef(
                    staticVienotProtanDouble,
                    color
                )
                : applyMatrixRef(
                    staticVienotDeutanDouble,
                    color
                );
    }
}


private LinearSRgb!T typedStaticBrettelRuntime(T)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    static if (is(T == float))
    {
        final switch (deficiency)
        {
            case 0:
                return applyBrettelPlanRef(
                    staticBrettelProtanFloat,
                    color
                );

            case 1:
                return applyBrettelPlanRef(
                    staticBrettelDeutanFloat,
                    color
                );

            case 2:
                return applyBrettelPlanRef(
                    staticBrettelTritanFloat,
                    color
                );
        }
    }
    else
    {
        final switch (deficiency)
        {
            case 0:
                return applyBrettelPlanRef(
                    staticBrettelProtanDouble,
                    color
                );

            case 1:
                return applyBrettelPlanRef(
                    staticBrettelDeutanDouble,
                    color
                );

            case 2:
                return applyBrettelPlanRef(
                    staticBrettelTritanDouble,
                    color
                );
        }
    }
}


private Matrix3!T typedStaticMachadoMatrixRuntime(T)(
    uint deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    const T scaled =
        severity * cast(T)10;

    const size_t lower =
        cast(size_t)scaled;

    const T alpha =
        lower >= 10
            ? cast(T)0
            : scaled - cast(T)lower;

    static if (is(T == float))
    {
        if (deficiency == 0)
        {
            if (lower >= 10)
                return staticMachadoProtanFloat[10];

            return interpolateMatrix(
                staticMachadoProtanFloat[lower],
                staticMachadoProtanFloat[lower + 1],
                alpha
            );
        }

        assert(deficiency == 1);

        if (lower >= 10)
            return staticMachadoDeutanFloat[10];

        return interpolateMatrix(
            staticMachadoDeutanFloat[lower],
            staticMachadoDeutanFloat[lower + 1],
            alpha
        );
    }
    else
    {
        if (deficiency == 0)
        {
            if (lower >= 10)
                return staticMachadoProtanDouble[10];

            return interpolateMatrix(
                staticMachadoProtanDouble[lower],
                staticMachadoProtanDouble[lower + 1],
                alpha
            );
        }

        assert(deficiency == 1);

        if (lower >= 10)
            return staticMachadoDeutanDouble[10];

        return interpolateMatrix(
            staticMachadoDeutanDouble[lower],
            staticMachadoDeutanDouble[lower + 1],
            alpha
        );
    }
}


LinearSRgb!T typedStaticVienot(T)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    if (__ctfe)
        return typedTableVienot!T(
            color,
            deficiency
        );

    return typedStaticVienotRuntime!T(
        color,
        deficiency
    );
}


LinearSRgb!T typedStaticBrettel(T)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    if (__ctfe)
        return typedTableBrettel!T(
            color,
            deficiency
        );

    return typedStaticBrettelRuntime!T(
        color,
        deficiency
    );
}


LinearSRgb!T typedStaticMachado(T)(
    LinearSRgb!T color,
    uint deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    if (!validSeverity(severity))
        return LinearSRgb!T.init;

    if (__ctfe)
        return typedTableMachado!T(
            color,
            deficiency,
            severity
        );

    return applyMatrix(
        typedStaticMachadoMatrixRuntime!(
            T
        )(
            deficiency,
            severity
        ),
        color
    );
}


private Matrix3!T typedMachadoMatrix(T)(
    uint deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    const T scaled =
        severity * cast(T)10;

    const size_t lower =
        cast(size_t)scaled;

    if (deficiency == 0)
    {
        if (lower >= 10)
            return TypedConstants!T.machadoP[10];

        const T alpha =
            scaled - cast(T)lower;

        return interpolateMatrix(
            TypedConstants!T.machadoP[lower],
            TypedConstants!T.machadoP[lower + 1],
            alpha
        );
    }

    assert(deficiency == 1);

    if (lower >= 10)
        return TypedConstants!T.machadoD[10];

    const T alpha =
        scaled - cast(T)lower;

    return interpolateMatrix(
        TypedConstants!T.machadoD[lower],
        TypedConstants!T.machadoD[lower + 1],
        alpha
    );
}


LinearSRgb!T typedTableVienot(T)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    return applyMatrix(
        deficiency == 0
            ? TypedConstants!T.vienotP
            : TypedConstants!T.vienotD,
        color
    );
}


LinearSRgb!T typedTableBrettel(T)(
    LinearSRgb!T color,
    uint deficiency
)
@safe pure nothrow @nogc
{
    final switch (deficiency)
    {
        case 0:
            return applyBrettelPlan(
                TypedConstants!T.brettelP,
                color
            );

        case 1:
            return applyBrettelPlan(
                TypedConstants!T.brettelD,
                color
            );

        case 2:
            return applyBrettelPlan(
                TypedConstants!T.brettelT,
                color
            );
    }
}


LinearSRgb!T typedTableMachado(T)(
    LinearSRgb!T color,
    uint deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    if (!validSeverity(severity))
        return LinearSRgb!T.init;

    return applyMatrix(
        typedMachadoMatrix!(
            T
        )(
            deficiency,
            severity
        ),
        color
    );
}


LinearSRgb!T runReplica(
    T,
    Model model,
    Variant variant
)(
    LinearSRgb!T color,
    uint deficiency,
    T severity
)
@safe pure nothrow @nogc
{
    static if (model == Model.vienot)
    {
        static if (variant == Variant.carrierReplica)
            return carrierReplicaVienot!T(color, deficiency);
        else static if (variant == Variant.directReturn)
            return directReturnVienot!T(color, deficiency);
        else static if (variant == Variant.outKernel)
            return outKernelVienot!T(color, deficiency);
        else static if (variant == Variant.inlineChain)
            return inlineChainVienot!T(color, deficiency);
        else static if (variant == Variant.typedTable)
            return typedTableVienot!T(color, deficiency);
        else
            return typedStaticVienot!T(color, deficiency);
    }
    else static if (model == Model.machado)
    {
        static if (variant == Variant.carrierReplica)
            return carrierReplicaMachado!T(color, deficiency, severity);
        else static if (variant == Variant.directReturn)
            return directReturnMachado!T(color, deficiency, severity);
        else static if (variant == Variant.outKernel)
            return outKernelMachado!T(color, deficiency, severity);
        else static if (variant == Variant.inlineChain)
            return inlineChainMachado!T(color, deficiency, severity);
        else static if (variant == Variant.typedTable)
            return typedTableMachado!T(color, deficiency, severity);
        else
            return typedStaticMachado!T(color, deficiency, severity);
    }
    else
    {
        static if (variant == Variant.carrierReplica)
            return carrierReplicaBrettel!T(color, deficiency);
        else static if (variant == Variant.directReturn)
            return directReturnBrettel!T(color, deficiency);
        else static if (variant == Variant.outKernel)
            return outKernelBrettel!T(color, deficiency);
        else static if (variant == Variant.inlineChain)
            return inlineChainBrettel!T(color, deficiency);
        else static if (variant == Variant.typedTable)
            return typedTableBrettel!T(color, deficiency);
        else
            return typedStaticBrettel!T(color, deficiency);
    }
}
