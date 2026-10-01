// R6.5 research probe for color-d #162.
// CIEDE2000 singularities, hue wrap, symmetry, scalar and CTFE behavior.
// The calculation is copied independently from R6.4; this probe focuses on
// edge-case invariants rather than the published reference table.

import std.math : abs, atan2, cos, sin, sqrt, exp2, PI;
import std.stdio : writeln;

struct Lab(T){T l;T a;T b;}
T degToRad(T)(T x) @safe pure nothrow @nogc { return x*cast(T)(PI/180.0L); }
T radToDeg(T)(T x) @safe pure nothrow @nogc { return x*cast(T)(180.0L/PI); }
T cbrtCtfe(T)(T x) @safe pure nothrow @nogc {
    if(x==0) return x; const bool neg=x<0; T a=neg?-x:x; T y=a>cast(T)1?a:cast(T)1;
    foreach(_;0..40) y=(cast(T)2*y+a/(y*y))/cast(T)3;
    return neg?-y:y;
}
T de00(T)(Lab!T x,Lab!T y) @safe pure nothrow @nogc {
    const T c1=sqrt(x.a*x.a+x.b*x.b),c2=sqrt(y.a*y.a+y.b*y.b),cb=(c1+c2)/cast(T)2;
    const T c7=cb*cb*cb*cb*cb*cb*cb;
    const T G=cast(T)0.5*(cast(T)1-sqrt(c7/(c7+cast(T)6103515625.0)));
    const T ap1=(cast(T)1+G)*x.a,ap2=(cast(T)1+G)*y.a;
    const T cp1=sqrt(ap1*ap1+x.b*x.b),cp2=sqrt(ap2*ap2+y.b*y.b);
    T hp1=radToDeg(atan2(x.b,ap1)); if(hp1<0)hp1+=cast(T)360;
    T hp2=radToDeg(atan2(y.b,ap2)); if(hp2<0)hp2+=cast(T)360;
    const T dL=y.l-x.l,dC=cp2-cp1; T dh=hp2-hp1;
    if(cp1*cp2==0)dh=0; else if(dh>180)dh-=360; else if(dh<-180)dh+=360;
    const T dH=cast(T)2*sqrt(cp1*cp2)*sin(degToRad(dh/cast(T)2));
    const T lb=(x.l+y.l)/cast(T)2,cbp=(cp1+cp2)/cast(T)2;
    T hb;
    if(cp1*cp2==0)hb=hp1+hp2;
    else if(abs(hp1-hp2)<=180)hb=(hp1+hp2)/cast(T)2;
    else if(hp1+hp2<360)hb=(hp1+hp2+360)/cast(T)2;
    else hb=(hp1+hp2-360)/cast(T)2;
    const T tt=cast(T)1-cast(T)0.17*cos(degToRad(hb-30))+cast(T)0.24*cos(degToRad(cast(T)2*hb))
        +cast(T)0.32*cos(degToRad(cast(T)3*hb+6))-cast(T)0.20*cos(degToRad(cast(T)4*hb-63));
    const T dl=lb-50,sl=cast(T)1+cast(T)0.015*dl*dl/sqrt(cast(T)20+dl*dl);
    const T sc=cast(T)1+cast(T)0.045*cbp,sh=cast(T)1+cast(T)0.015*cbp*tt;
    const T rt=-cast(T)2*sqrt(cbp*cbp*cbp*cbp*cbp*cbp*cbp/(cbp*cbp*cbp*cbp*cbp*cbp*cbp+cast(T)6103515625.0))
        *sin(degToRad(cast(T)60*exp2(-((hb-275)/cast(T)25)*((hb-275)/cast(T)25))));
    const T vl=dL/sl,vc=dC/sc,vh=dH/sh;
    return sqrt(vl*vl+vc*vc+vh*vh+rt*vc*vh);
}
bool close(double a,double b,double e){return abs(a-b)<=e;}

void main(){
    enum black=Lab!double(0,0,0), black2=Lab!double(100,0,0);
    enum neutral=Lab!double(50,0,0), nearNeutral=Lab!double(50,1e-12,0);
    enum hueA=Lab!double(50,20,0), hueB=Lab!double(50,-20,0);
    enum boundaryA=Lab!double(50,0,20), boundaryB=Lab!double(50,0,-20);

    static assert(de00(black,black)==0);
    static assert(de00(neutral,neutral)==0);
    static assert(de00(neutral,nearNeutral)>=0);

    enum ab=de00(hueA,hueB), ba=de00(hueB,hueA);
    assert(close(ab,ba,1e-12));

    enum wrap1=de00(boundaryA,boundaryB);
    enum wrap2=de00(boundaryB,boundaryA);
    assert(close(wrap1,wrap2,1e-12));

    enum dn=de00(neutral,nearNeutral);
    assert(dn>=0);

    // Explicit hue-singularity cases must remain finite.
    assert(de00(black,black2)>=0);
    assert(de00(black,neutral)>=0);

    writeln("R6.5 PASS");
    writeln("zero-distance PASS");
    writeln("zero-chroma/hue-singularity PASS");
    writeln("hue-wrap symmetry PASS");
    writeln("non-negative finite-domain result PASS");
    writeln("CTFE edge-case evaluation PASS");
}
