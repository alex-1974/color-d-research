// R6.1 research probe for color-d #162.
// Establishes reference-white and linear-Bradford boundaries for CIELAB work.

import std.math : fabs;
import std.stdio : writeln;

struct Xyz(T) { T x; T y; T z; }

Xyz!T adaptD65ToD50(T)(Xyz!T v)
@safe pure nothrow @nogc
{
    return Xyz!T(
        cast(T)1.0479297925449969 * v.x +
        cast(T)0.022946870961 + v.y * cast(T)0.0 +
        cast(T)0.022946870961 * v.y -
        cast(T)0.05019226628920524 * v.z,
        cast(T)0.02962780877005599 * v.x +
        cast(T)0.9904344267538799 * v.y -
        cast(T)0.017073799063418826 * v.z,
        -cast(T)0.009243040646204504 * v.x +
        cast(T)0.015055191490298152 * v.y +
        cast(T)0.7518742814281371 * v.z
    );
}

Xyz!T adaptD50ToD65(T)(Xyz!T v)
@safe pure nothrow @nogc
{
    return Xyz!T(
        cast(T)0.955473421488075 * v.x -
        cast(T)0.02309845494876471 * v.y +
        cast(T)0.06325924320057072 * v.z,
        -cast(T)0.0283697093338637 * v.x +
        cast(T)1.0099953980813041 * v.y +
        cast(T)0.021041441191917323 * v.z,
        cast(T)0.012314014864481998 * v.x -
        cast(T)0.020507649298898964 * v.y +
        cast(T)1.330365926242124 * v.z
    );
}

bool close(T)(T a,T b,T eps)
@safe pure nothrow @nogc
{
    return fabs(a-b)<=eps;
}

void main()
{
    // W3C CSS Color 4 compatibility white points:
    // D65: x=0.312700, y=0.329000, Y=1
    // D50: x=0.345700, y=0.358500, Y=1
    enum Xyz!double d65 = Xyz!double(
        0.3127/0.3290, 1.0,
        (1.0-0.3127-0.3290)/0.3290
    );
    enum Xyz!double d50 = Xyz!double(
        0.3457/0.3585, 1.0,
        (1.0-0.3457-0.3585)/0.3585
    );

    enum adapted = adaptD65ToD50(d65);
    enum roundTrip = adaptD50ToD65(adapted);

    // The research question is whether a D65 XYZ core can expose a separate,
    // explicit D50 Lab boundary without silently treating XYZ D65 as Lab D50.
    static assert(close(adapted.x,d50.x,1e-6));
    static assert(close(adapted.y,d50.y,1e-6));
    static assert(close(adapted.z,d50.z,1e-6));

    static assert(close(roundTrip.x,d65.x,2e-6));
    static assert(close(roundTrip.y,d65.y,2e-6));
    static assert(close(roundTrip.z,d65.z,2e-6));

    writeln("R6.1 PASS");
    writeln("D65 -> D50 white mapping PASS");
    writeln("D50 -> D65 round-trip PASS");
    writeln("CTFE adaptation PASS");
}
