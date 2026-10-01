// R6.3 research probe for color-d #162.
// Delta E 1976 reference-vector validation and CTFE feasibility.

import std.math : sqrt;
import std.stdio : writeln;

struct Lab(T){T l;T a;T b;}

T deltaE76(T)(Lab!T x, Lab!T y)
@safe pure nothrow @nogc
{
    const T dl=x.l-y.l, da=x.a-y.a, db=x.b-y.b;
    return sqrt(dl*dl+da*da+db*db);
}

bool close(T)(T a,T b,T eps)
@safe pure nothrow @nogc { return (a-b<0?b-a:a-b)<=eps; }

void main()
{
    enum a=Lab!double(50.0,2.6772,-79.7751);
    enum b=Lab!double(50.0,0.0,-82.7485);
    enum d=deltaE76(a,b);

    // Sharma/Wu/Dalal CIEDE2000 supplementary table contains this pair;
    // its Delta E 1976 value is independently useful as a baseline.
    enum expected=4.001063283678486;
    static assert(close(d,expected,1e-12));

    enum identical=deltaE76(a,a);
    static assert(identical==0.0);

    enum symmetryA=deltaE76(a,b);
    enum symmetryB=deltaE76(b,a);
    static assert(symmetryA==symmetryB);

    writeln("R6.3 PASS");
    writeln("Delta E 1976 reference vector PASS");
    writeln("zero-distance PASS");
    writeln("symmetry PASS");
    writeln("CTFE PASS");
}
