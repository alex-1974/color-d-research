// R5.8 research probe for color-d #161.
// Validates proposed domain semantics and CTFE feasibility.

import std.math : cos, sin, PI, isFinite;
import std.stdio : writeln;

struct Rgb(T) { T r; T g; T b; }
Rgb!T rgb(T)(T L,T C,T h) {
    const T q=h*cast(T)(PI/180.0L), a=C*cos(q), b=C*sin(q);
    const T lp=L+cast(T).3963377774*a+cast(T).2158037573*b;
    const T mp=L-cast(T).1055613458*a-cast(T).0638541728*b;
    const T sp=L-cast(T).0894841775*a-cast(T)1.2914855480*b;
    const T l=lp*lp*lp,m=mp*mp*mp,s=sp*sp*sp;
    return Rgb!T(cast(T)4.0767416621*l-cast(T)3.3077115913*m+cast(T).2309699292*s,
        -cast(T)1.2684380046*l+cast(T)2.6097574011*m-cast(T).3413193965*s,
        -cast(T).0041960863*l-cast(T).7034186147*m+cast(T)1.7076147010*s);
}
bool inside(T)(Rgb!T c){return c.r>=0&&c.r<=1&&c.g>=0&&c.g<=1&&c.b>=0&&c.b<=1;}

struct Limit(T) {
    T value;
    bool valid;
}

Limit!T limit(T)(T L,T h) {
    if(!isFinite(L)||!isFinite(h)||L<0||L>1) return Limit!T(T.nan,false);
    if(L==0||L==1) return Limit!T(cast(T)0,true);
    T lo=0,hi=cast(T).125;
    while(inside(rgb(L,hi,h))){lo=hi;hi*=2;}
    foreach(_;0..24) {
        const mid=lo+(hi-lo)/2;
        if(mid==lo||mid==hi) break;
        if(inside(rgb(L,mid,h)))lo=mid;else hi=mid;
    }
    return Limit!T(lo,true);
}

enum d0=limit!double(0.5,0.0);
enum d360=limit!double(0.5,360.0);
enum f17=limit!float(0.5f,17.0f);
static assert(d0.valid && d0.value>0);
static assert(d360.valid && d360.value==d0.value);
static assert(f17.valid && f17.value>0);
static assert(limit!double(0.0,42.0).valid && limit!double(0.0,42.0).value==0);
static assert(limit!double(1.0,42.0).valid && limit!double(1.0,42.0).value==0);
static assert(!limit!double(-0.01,42.0).valid);
static assert(!limit!double(1.01,42.0).valid);
static assert(!limit!double(double.nan,42.0).valid);
static assert(!limit!double(0.5,double.nan).valid);
static assert(!limit!double(double.infinity,42.0).valid);
static assert(!limit!double(0.5,double.infinity).valid);

void main() {
    foreach(h;[-720.0,-360.0,0.0,360.0,720.0]) {
        const x=limit!double(0.5,h);
        assert(x.valid && x.value==d0.value);
    }
    assert(inside(rgb(0.5,d0.value,0.0)));
    writeln("R5.8 PASS");
    writeln("double CTFE boundary=",d0.value);
    writeln("float CTFE boundary=",f17.value);
    writeln("endpoint/invalid/periodicity checks PASS");
}
