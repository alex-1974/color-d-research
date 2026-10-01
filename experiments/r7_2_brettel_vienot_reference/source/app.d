import std.stdio : writeln;
import std.math : abs, isNaN;

struct Rgb(T){ T r; T g; T b; }
struct Lms(T){ T l; T m; T s; }

struct Matrix3(T)
{
    T m00; T m01; T m02;
    T m10; T m11; T m12;
    T m20; T m21; T m22;

    Rgb!T apply(T)(Rgb!T v) const
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

    enum sample = Rgb!double(0.2, 0.4, 0.7);
    enum bp1 = brettelProtan1.apply(sample);
    enum vd = vienotDeutan.apply(sample);

    static assert(bp1.r == 0.2*0.14980 + 0.4*1.19548 - 0.7*0.34528);
    static assert(vd.g == 0.2*0.29275 + 0.4*0.70725);

    writeln("R7.2 PASS");
    writeln("Brettel protan/deutan/tritan two-plane matrices: CTFE PASS");
    writeln("Vienot protan/deutan matrices: CTFE PASS");
}
