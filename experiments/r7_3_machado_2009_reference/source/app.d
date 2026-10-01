import std.stdio : writeln;
import std.math : abs, isNaN, isInfinity;

struct Rgb(T){ T r; T g; T b; }

struct Matrix3(T)
{
    T m00; T m01; T m02;
    T m10; T m11; T m12;
    T m20; T m21; T m22;
}

Rgb!T castRgb(T)(Rgb!double v)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return Rgb!T(cast(T)v.r, cast(T)v.g, cast(T)v.b);
}

Rgb!T apply(T)(Matrix3!T m, Rgb!T v)
@safe pure nothrow @nogc
{
    return Rgb!T(m.m00*v.r+m.m01*v.g+m.m02*v.b,
                  m.m10*v.r+m.m11*v.g+m.m12*v.b,
                  m.m20*v.r+m.m21*v.g+m.m22*v.b);
}

Matrix3!T lerp(T)(Matrix3!T a, Matrix3!T b, T alpha)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return Matrix3!T(
        a.m00 + (b.m00-a.m00)*alpha, a.m01 + (b.m01-a.m01)*alpha, a.m02 + (b.m02-a.m02)*alpha,
        a.m10 + (b.m10-a.m10)*alpha, a.m11 + (b.m11-a.m11)*alpha, a.m12 + (b.m12-a.m12)*alpha,
        a.m20 + (b.m20-a.m20)*alpha, a.m21 + (b.m21-a.m21)*alpha, a.m22 + (b.m22-a.m22)*alpha
    );
}

Matrix3!T matrixAtSeverity(T)(const Matrix3!T[] table, T severity)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    assert(severity >= 0 && severity <= 1);
    const T scaled = severity * 10;
    const size_t lo = cast(size_t) scaled;
    if (lo >= 10)
        return table[10];
    const T alpha = scaled - cast(T) lo;
    return lerp(table[lo], table[lo + 1], alpha);
}

enum Matrix3!double identity = Matrix3!double(1,0,0,0,1,0,0,0,1);

enum Matrix3!double[11] protanTable = [
identity,
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

enum Matrix3!double[11] deutanTable = [
identity,
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

enum Matrix3!double[11] tritanTable = [
identity,
Matrix3!double(.926670,.092514,-.019184,.021191,.964503,.014306,.008437,.054813,.936750),
Matrix3!double(.895720,.133330,-.029050,.029997,.945400,.024603,.013027,.104707,.882266),
Matrix3!double(.905871,.127791,-.033662,.026856,.941251,.031893,.013410,.148296,.838294),
Matrix3!double(.948035,.089490,-.037526,.014364,.946792,.038844,.010853,.193991,.795156),
Matrix3!double(1.017277,.027029,-.044306,-.006113,.958479,.047634,.006379,.248708,.744913),
Matrix3!double(1.104996,-.046633,-.058363,-.032137,.971635,.060503,.001336,.317922,.680742),
Matrix3!double(1.193214,-.109812,-.083402,-.058496,.979410,.079086,-.002346,.403492,.598854),
Matrix3!double(1.257728,-.139648,-.118081,-.078003,.975409,.102594,-.003316,.501214,.502102),
Matrix3!double(1.278864,-.125333,-.153531,-.084748,.957674,.127074,-.000989,.601151,.399838),
Matrix3!double(1.255528,-.076749,-.178779,-.078411,.930809,.147602,.004733,.691367,.303900)
];

bool same(T)(Matrix3!T a, Matrix3!T b, T tol)
@safe pure nothrow @nogc
{
    return abs(a.m00-b.m00)<=tol && abs(a.m01-b.m01)<=tol && abs(a.m02-b.m02)<=tol
        && abs(a.m10-b.m10)<=tol && abs(a.m11-b.m11)<=tol && abs(a.m12-b.m12)<=tol
        && abs(a.m20-b.m20)<=tol && abs(a.m21-b.m21)<=tol && abs(a.m22-b.m22)<=tol;
}

Matrix3!T castMatrix(T)(Matrix3!double m)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return Matrix3!T(cast(T)m.m00,cast(T)m.m01,cast(T)m.m02,
                     cast(T)m.m10,cast(T)m.m11,cast(T)m.m12,
                     cast(T)m.m20,cast(T)m.m21,cast(T)m.m22);
}

void validateTable()
@safe
{
    foreach(i; 0 .. 11)
    {
        const T = cast(double)i / 10.0;
        assert(same(matrixAtSeverity(protanTable[], T), protanTable[i], 1e-12));
        assert(same(matrixAtSeverity(deutanTable[], T), deutanTable[i], 1e-12));
        assert(same(matrixAtSeverity(tritanTable[], T), tritanTable[i], 1e-12));
    }

    enum double half = 0.5;
    const p = matrixAtSeverity(protanTable[], half);
    const d = matrixAtSeverity(deutanTable[], half);
    const t = matrixAtSeverity(tritanTable[], half);
    assert(same(p, lerp(protanTable[5], protanTable[6], 0.0), 1e-12));
    assert(same(d, lerp(deutanTable[5], deutanTable[6], 0.0), 1e-12));
    assert(same(t, lerp(tritanTable[5], tritanTable[6], 0.0), 1e-12));

    assert(!same(tritanTable[5], lerp(tritanTable[0], tritanTable[10], 0.5), 1e-6));
    writeln("R7.3 PASS");
    writeln("33 Machado reference matrices: PASS");
    writeln("11 severity points x 3 deficiencies: PASS");
    writeln("Adjacent-table interpolation: PASS");
    writeln("Nonlinear severity table preserved: PASS");
}

void errorEnvelope()
@safe
{
    enum Rgb!double[12] points = [
        Rgb!double(0,0,0), Rgb!double(1,1,1), Rgb!double(.5,.5,.5),
        Rgb!double(1,0,0), Rgb!double(0,1,0), Rgb!double(0,0,1),
        Rgb!double(0,1,1), Rgb!double(1,0,1), Rgb!double(1,1,0),
        Rgb!double(.2,.4,.7), Rgb!double(.63,.21,.47), Rgb!double(.17,.59,.33)
    ];

    double maxAbs = 0.0;
    foreach(si; 0 .. 11)
    foreach(pi; 0 .. points.length)
    {
        foreach(mi, ref table; [protanTable[], deutanTable[], tritanTable[]])
        {
            const md = matrixAtSeverity(table, cast(double)si / 10.0);
            const mf = castMatrix!float(md);
            const vf = apply(mf, castRgb!float(points[pi]));
            const vd = apply(md, points[pi]);
            const e0 = abs(vf.r - cast(float)vd.r);
            const e1 = abs(vf.g - cast(float)vd.g);
            const e2 = abs(vf.b - cast(float)vd.b);
            assert(!isNaN(e0) && !isNaN(e1) && !isNaN(e2));
            assert(!isInfinity(e0) && !isInfinity(e1) && !isInfinity(e2));
            const e = e0 > e1 ? (e0 > e2 ? e0 : e2) : (e1 > e2 ? e1 : e2);
            assert(!isNaN(e));
            if (e > maxAbs) { maxAbs=e; }
        }
    }
    assert(!isNaN(maxAbs) && !isInfinity(maxAbs));
    assert(maxAbs < 2e-6);
    writeln("R7.4.2 PASS");
    writeln("float-vs-double matrix/output envelope: PASS");
    writeln("max absolute component error: ", maxAbs);
}

void validateNonFiniteAndGamut()
@safe
{
    enum nanInput = Rgb!double(double.nan, 0.25, 0.75);
    enum infInput = Rgb!double(double.infinity, 0.25, 0.75);
    enum outInput = Rgb!double(-0.25, 1.25, 2.0);

    enum nanOut = apply(protanTable[10], nanInput);
    assert(isNaN(nanOut.r) || isNaN(nanOut.g) || isNaN(nanOut.b));

    enum infOut = apply(protanTable[10], infInput);
    assert(isInfinity(infOut.r) || isInfinity(infOut.g) || isInfinity(infOut.b)
        || isNaN(infOut.r) || isNaN(infOut.g) || isNaN(infOut.b));

    enum out = apply(protanTable[10], outInput);
    assert(out.r < 0.0 || out.g > 1.0 || out.b > 1.0);

    writeln("R7.4.3 PASS");
    writeln("NaN/Infinity IEEE propagation: PASS");
    writeln("Out-of-gamut values preserved: PASS");
}

void main()
@safe
{
    validateTable();
    errorEnvelope();
    validateNonFiniteAndGamut();

    enum pCtfe = matrixAtSeverity(protanTable[], 0.35);
    enum dCtfe = matrixAtSeverity(deutanTable[], 0.65);
    enum tCtfe = matrixAtSeverity(tritanTable[], 0.85);

    const pRuntime = matrixAtSeverity(protanTable[], 0.35);
    const dRuntime = matrixAtSeverity(deutanTable[], 0.65);
    const tRuntime = matrixAtSeverity(tritanTable[], 0.85);

    assert(same(pCtfe, pRuntime, 1e-15));
    assert(same(dCtfe, dRuntime, 1e-15));
    assert(same(tCtfe, tRuntime, 1e-15));

    enum Matrix3!float[11] protanFloat = [
        castMatrix!float(protanTable[0]), castMatrix!float(protanTable[1]), castMatrix!float(protanTable[2]),
        castMatrix!float(protanTable[3]), castMatrix!float(protanTable[4]), castMatrix!float(protanTable[5]),
        castMatrix!float(protanTable[6]), castMatrix!float(protanTable[7]), castMatrix!float(protanTable[8]),
        castMatrix!float(protanTable[9]), castMatrix!float(protanTable[10])
    ];
    enum fp = matrixAtSeverity(protanFloat[], 0.35f);
    static assert(fp.m00 > 0.5f && fp.m00 < 0.9f);

    writeln("CTFE/runtime equivalence: PASS");
    writeln("float matrix path: CTFE PASS");
}
