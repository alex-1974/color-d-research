// R6.2 research probe for color-d #162.
// CIELAB forward/reverse reference-vector feasibility and CTFE.

import std.math : cbrt, pow;
import std.stdio : writeln;

struct Xyz(T){T x;T y;T z;}
struct Lab(T){T l;T a;T b;}

Lab!T xyzD50ToLab(T)(Xyz!T xyz)
@safe pure nothrow @nogc
{
    enum T e = cast(T)(216.0L/24389.0L);
    enum T k = cast(T)(24389.0L/27.0L);
    enum T wx = cast(T)0.96422;
    enum T wy = cast(T)1.0;
    enum T wz = cast(T)0.82521;

    T f(T v) {
        return v > e ? cbrt(v) : (k*v + cast(T)16)/cast(T)116;
    }

    const T fx=f(xyz.x/wx), fy=f(xyz.y/wy), fz=f(xyz.z/wz);
    return Lab!T(
        cast(T)116*fy-cast(T)16,
        cast(T)500*(fx-fy),
        cast(T)200*(fy-fz)
    );
}

Xyz!T labToXyzD50(T)(Lab!T lab)
@safe pure nothrow @nogc
{
    enum T e = cast(T)(216.0L/24389.0L);
    enum T k = cast(T)(24389.0L/27.0L);
    enum T wx = cast(T)0.96422;
    enum T wy = cast(T)1.0;
    enum T wz = cast(T)0.82521;

    const T fy=(lab.l+cast(T)16)/cast(T)116;
    const T fx=lab.a/cast(T)500+fy;
    const T fz=fy-lab.b/cast(T)200;

    T finv(T v) {
        const T cube=v*v*v;
        return cube > e ? cube : (cast(T)116*v-cast(T)16)/k;
    }

    return Xyz!T(wx*finv(fx),wy*finv(fy),wz*finv(fz));
}

bool close(T)(T a,T b,T eps)
@safe pure nothrow @nogc { return (a-b<0?b-a:a-b)<=eps; }

void main(){
    // W3C CSS Color 4 equivalence example:
    // xyz-d50 0.2005 0.14089 0.4472 <-> lab 44.36 36.05 -58.99
    enum xyz = Xyz!double(0.2005,0.14089,0.4472);
    enum lab = xyzD50ToLab(xyz);
    enum back = labToXyzD50(lab);

    static assert(close(lab.l,44.36,0.01));
    static assert(close(lab.a,36.05,0.02));
    static assert(close(lab.b,-58.99,0.02));
    static assert(close(back.x,xyz.x,0.0002));
    static assert(close(back.y,xyz.y,0.0002));
    static assert(close(back.z,xyz.z,0.0002));

    // D65/D50 boundary is explicit: feeding D65 white directly as D50
    // produces a different Lab value; adaptation must not be implicit.
    enum d65White=Xyz!double(0.95047,1.0,1.08883);
    enum d65AsLab=xyzD50ToLab(d65White);
    assert(d65AsLab.l>100.0);

    writeln("R6.2 PASS");
    writeln("CIELAB forward CTFE PASS");
    writeln("CIELAB reverse CTFE PASS");
    writeln("reference-vector envelope PASS");
    writeln("explicit D65/D50 distinction PASS");
}
