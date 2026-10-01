import std.stdio : writeln;
import std.math : abs, isNaN;

struct Rgb(T){ T r; T g; T b; }
struct Lms(T){ T l; T m; T s; }

struct Matrix3(T)
{
    T m00; T m01; T m02;
    T m10; T m11; T m12;
    T m20; T m21; T m22;

    Rgb!T apply(Rgb!T v) const @safe pure nothrow @nogc
    {
        return Rgb!T(
            m00*v.r + m01*v.g + m02*v.b,
            m10*v.r + m11*v.g + m12*v.b,
            m20*v.r + m21*v.g + m22*v.b
        );
    }
}

/*
 * These are the precomputed linear-sRGB transforms used by the independent
 * DaltonLens reference implementation for the Smith & Pokorny 1975 LMS model
 * adapted to modern sRGB. Brettel uses two RGB-space matrices per deficiency
 * plus a separation-plane normal.
 */
enum Matrix3!double brettelProtan1 = Matrix3!double(
    0.14980, 1.19548, -0.34528,
    0.10764, 0.84864, 0.04372,
    0.00384, -0.00540, 1.00156
);
enum Matrix3!double brettelProtan2 = Matrix3!double(
    0.14570, 1.16172, -0.30742,
    0.10816, 0.85291, 0.03892,
    0.00386, -0.00524, 1.00139
);
enum Matrix3!double brettelDeutan1 = Matrix3!double(
    0.36477, 0.86381, -0.22858,
    0.26294, 0.64245, 0.09462,
    -0.02006, 0.02728, 0.99278
);
enum Matrix3!double brettelDeutan2 = Matrix3!double(
    0.37298, 0.88166, -0.25464,
    0.25954, 0.63506, 0.10540,
    -0.01980, 0.02784, 0.99196
);
enum Matrix3!double brettelTritan1 = Matrix3!double(
    1.01277, 0.13548, -0.14826,
    -0.01243, 0.86812, 0.14431,
    0.07589, 0.80500, 0.11911
);
enum Matrix3!double brettelTritan2 = Matrix3!double(
    0.93678, 0.18979, -0.12657,
    0.06154, 0.81526, 0.12320,
    -0.37562, 1.12767, 0.24796
);

enum Matrix3!double vienotProtan = Matrix3!double(
    0.11238, 0.88762, 0.0,
    0.11238, 0.88762, 0.0,
    0.00401, -0.00401, 1.0
);
enum Matrix3!double vienotDeutan = Matrix3!double(
    0.29275, 0.70725, 0.0,
    0.29275, 0.70725, 0.0,
    -0.02234, 0.02234, 1.0
);

void checkMatrix(Matrix3!double m)
@safe pure nothrow @nogc
{
    const auto white = m.apply(Rgb!double(1, 1, 1));
    assert(!isNaN(white.r) && !isNaN(white.g) && !isNaN(white.b));
}

void assertNear(T)(T actual, T expected, T tolerance)
@safe pure nothrow @nogc
{
    assert(abs(actual - expected) <= tolerance);
}

void checkGoldenBrettel()
@safe
{
    enum points = [
        Rgb!double(0.2, 0.4, 0.7),
        Rgb!double(0.1, 0.5, 0.2),
        Rgb!double(0.8, 0.2, 0.1),
        Rgb!double(1, 1, 1),
        Rgb!double(0, 0, 0)
    ];

    enum bpExpected = [
        Rgb!double(0.278634, 0.390040, 0.699649),
        Rgb!double(0.543664, 0.443828, 0.197996),
        Rgb!double(0.324408, 0.260212, 0.102148),
        Rgb!double(1.0, 1.0, 1.0),
        Rgb!double(0.0, 0.0, 0.0)
    ];
    enum bdExpected = [
        Rgb!double(0.258472, 0.375802, 0.701846),
        Rgb!double(0.427200, 0.364564, 0.210332),
        Rgb!double(0.449252, 0.345184, 0.088924),
        Rgb!double(1.0, 1.00001, 1.0),
        Rgb!double(0.0, 0.0, 0.0)
    ];
    enum btExpected = [
        Rgb!double(0.174673, 0.424652, 0.549516),
        Rgb!double(0.163259, 0.438424, 0.575865),
        Rgb!double(0.822486, 0.178111, 0.233623),
        Rgb!double(0.99999, 1.0, 1.0),
        Rgb!double(0.0, 0.0, 0.0)
    ];

    foreach(i, p; points)
    {
        const bp = (p.r*0.00048 + p.g*0.00393 + p.b*(-0.00441) >= 0)
            ? brettelProtan1.apply(p) : brettelProtan2.apply(p);
        const bd = (p.r*(-0.00281) + p.g*(-0.00611) + p.b*0.00892 >= 0)
            ? brettelDeutan1.apply(p) : brettelDeutan2.apply(p);
        const bt = (p.r*0.03901 + p.g*(-0.02788) + p.b*(-0.01113) >= 0)
            ? brettelTritan1.apply(p) : brettelTritan2.apply(p);

        assertNear(bp.r, bpExpected[i].r, 1e-6);
        assertNear(bp.g, bpExpected[i].g, 1e-6);
        assertNear(bp.b, bpExpected[i].b, 1e-6);
        assertNear(bd.r, bdExpected[i].r, 1e-6);
        assertNear(bd.g, bdExpected[i].g, 1e-6);
        assertNear(bd.b, bdExpected[i].b, 1e-6);
        assertNear(bt.r, btExpected[i].r, 1e-6);
        assertNear(bt.g, btExpected[i].g, 1e-6);
        assertNear(bt.b, btExpected[i].b, 1e-6);
    }
}

void checkGoldenVienot()
@safe
{
    enum p = Rgb!double(0.2, 0.4, 0.7);
    enum vp = vienotProtan.apply(p);
    enum vd = vienotDeutan.apply(p);

    assertNear(vp.r, 0.377524, 1e-6);
    assertNear(vp.g, 0.377524, 1e-6);
    assertNear(vp.b, 0.699198, 1e-6);
    assertNear(vd.r, 0.341450, 1e-6);
    assertNear(vd.g, 0.341450, 1e-6);
    assertNear(vd.b, 0.704468, 1e-6);
}


Matrix3!T precisionMatrix(T)(Matrix3!double m)
@safe pure nothrow @nogc
{
    return Matrix3!T(cast(T)m.m00, cast(T)m.m01, cast(T)m.m02,
        cast(T)m.m10, cast(T)m.m11, cast(T)m.m12,
        cast(T)m.m20, cast(T)m.m21, cast(T)m.m22);
}


Rgb!T brettelProbe(T)(Rgb!T p, uint deficiency)
@safe pure nothrow @nogc
{
    switch (deficiency)
    {
    case 0:
        return precisionMatrix!T(
            p.r*cast(T)0.00048 + p.g*cast(T)0.00393 - p.b*cast(T)0.00441 >= 0
            ? brettelProtan1 : brettelProtan2).apply(p);
    case 1:
        return precisionMatrix!T(
            -p.r*cast(T)0.00281 - p.g*cast(T)0.00611 + p.b*cast(T)0.00892 >= 0
            ? brettelDeutan1 : brettelDeutan2).apply(p);
    case 2:
        return precisionMatrix!T(
            p.r*cast(T)0.03901 - p.g*cast(T)0.02788 - p.b*cast(T)0.01113 >= 0
            ? brettelTritan1 : brettelTritan2).apply(p);
    default:
        assert(0, "unsupported research deficiency");
    }
}

Rgb!T vienotProbe(T)(Rgb!T p, bool deutan)
@safe pure nothrow @nogc
{
    return precisionMatrix!T(deutan ? vienotDeutan : vienotProtan).apply(p);
}

void qualifyAttributes(T)()
@safe pure nothrow @nogc
{
    enum sample = Rgb!T(cast(T)0.2, cast(T)0.4, cast(T)0.7);
    enum T tolerance = is(T == float) ? cast(T)2e-6 : cast(T)1e-12;
    // Parameters of the attributed wrappers cover runtime calls as well as CTFE.
    foreach (deficiency; 0u .. 3u)
    {
        const runtime = brettelProbe(sample, deficiency);
        assert(!isNaN(runtime.r) && !isNaN(runtime.g) && !isNaN(runtime.b));
    }
    static foreach (deficiency; 0u .. 3u)
    {
        enum expected = brettelProbe(sample, deficiency);
        const actual = brettelProbe(sample, deficiency);
        assertNear(actual.r, expected.r, tolerance);
        assertNear(actual.g, expected.g, tolerance);
        assertNear(actual.b, expected.b, tolerance);
    }
    static foreach (deutan; [false, true])
    {
        enum expected = vienotProbe(sample, deutan);
        const actual = vienotProbe(sample, deutan);
        assertNear(actual.r, expected.r, tolerance);
        assertNear(actual.g, expected.g, tolerance);
        assertNear(actual.b, expected.b, tolerance);
    }
    // Primaries exercise both sides of each Brettel separation plane.
    const Rgb!T[3] primaries = [Rgb!T(1,0,0), Rgb!T(0,1,0), Rgb!T(0,0,1)];
    foreach (p; primaries)
        foreach (deficiency; 0u .. 3u)
        {
            const actual = brettelProbe(p, deficiency);
            assert(!isNaN(actual.r) && !isNaN(actual.g) && !isNaN(actual.b));
        }
}

void main()
{
    checkMatrix(brettelProtan1);
    checkMatrix(brettelProtan2);
    checkMatrix(brettelDeutan1);
    checkMatrix(brettelDeutan2);
    checkMatrix(brettelTritan1);
    checkMatrix(brettelTritan2);
    checkMatrix(vienotProtan);
    checkMatrix(vienotDeutan);
    checkGoldenBrettel();
    checkGoldenVienot();
    qualifyAttributes!float();
    qualifyAttributes!double();
    writeln("R7.4.4 Brettel/Vienot float/double attributed runtime + CTFE: PASS");

    enum sample = Rgb!double(0.2, 0.4, 0.7);
    enum bp1 = brettelProtan1.apply(sample);
    enum vd = vienotDeutan.apply(sample);

    static assert(bp1.r == 0.2*0.14980 + 0.4*1.19548 - 0.7*0.34528);
    static assert(vd.g == 0.2*0.29275 + 0.4*0.70725);

    writeln("R7.2 PASS");
    writeln("Brettel protan/deutan/tritan two-plane matrices: CTFE PASS");
    writeln("Vienot protan/deutan matrices: CTFE PASS");
}
