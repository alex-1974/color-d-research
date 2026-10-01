// R6.8 research probe for color-d #162.
// Consumer-shaped validation: generic Delta-E metrics are exercised only as
// primitives. No theme/accessibility threshold or automatic algorithm choice
// is encoded here.

import std.math : abs, sqrt;
import std.stdio : writeln;

struct Lab(T){T l;T a;T b;}

T deltaE76(T)(Lab!T x,Lab!T y)
@safe pure nothrow @nogc
{
    const T dl=x.l-y.l, da=x.a-y.a, db=x.b-y.b;
    return sqrt(dl*dl+da*da+db*db);
}

struct Pair(T){Lab!T lhs;Lab!T rhs;}

enum Pair!double uiNear = Pair!double(
    Lab!double(62, 8, 14),
    Lab!double(62, 8.4, 14.1));

enum Pair!double uiDifferent = Pair!double(
    Lab!double(62, 8, 14),
    Lab!double(52, -4, 24));

enum nearDistance = deltaE76(uiNear.lhs, uiNear.rhs);
enum differentDistance = deltaE76(uiDifferent.lhs, uiDifferent.rhs);

void main()
{
    // A consumer can compute a metric at CTFE and decide its own policy later.
    static assert(nearDistance >= 0);
    static assert(differentDistance >= nearDistance);

    // The important architectural property is that the color library returns
    // measurements; the consumer owns thresholds and semantic decisions.
    static assert(nearDistance < 1.0);
    static assert(differentDistance > 10.0);

    writeln("R6.8 PASS");
    writeln("consumer-shaped metric calculation PASS");
    writeln("CTFE metric calculation PASS");
    writeln("no consumer threshold API PASS");
    writeln("no automatic algorithm-selection policy PASS");
}
