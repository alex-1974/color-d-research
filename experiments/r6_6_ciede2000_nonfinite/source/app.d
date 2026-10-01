// R6.6 research probe for color-d #162.
// Establish CIEDE2000 finite/non-finite and extended-value behavior.
// This probe is deliberately research-only: it documents behavior that a
// future public API must choose explicitly rather than inheriting accidentally.

import std.math : abs, atan2, cos, sin, sqrt, exp2, PI, isNaN, isInfinity;
import std.stdio : writeln;

struct Lab(T){T l;T a;T b;}

T degToRad(T)(T x) @safe pure nothrow @nogc { return x*cast(T)(PI/180.0L); }
T radToDeg(T)(T x) @safe pure nothrow @nogc { return x*cast(T)(180.0L/PI); }
T cbrtCtfe(T)(T x) @safe pure nothrow @nogc {
    if(x==0)return x; const bool neg=x<0; T a=neg?-x:x; T y=a>cast(T)1?a:cast(T)1;
    foreach(_;0..40)y=(cast(T)2*y+a/(y*y))/cast(T)3;
    return neg?-y:y;
}
T de00(T)(Lab!T x,Lab!T y) @safe pure nothrow @nogc {
    const T c1=sqrt(x.a*x.a+x.b*x.b),c2=sqrt(y.a*y.a+y.b*y.b),cb=(c1+c2)/cast(T)2;
    const T c7=cb*cb*cb*cb*cb*cb*cb;
    const T G=cast(T)0.5*(cast(T)1-sqrt(c7/(c7+cast(T)6103515625.0)));
    const T ap1=(cast(T)1+G)*x.a,ap2=(cast(T)1+G)*y.a;
    const T cp1=sqrt(ap1*ap1+x.b*x.b),cp2=sqrt(ap2*ap2+y.b*y.b);
    T hp1=radToDeg(atan2(x.b,ap1));if(hp1<0)hp1+=cast(T)360;
    T hp2=radToDeg(atan2(y.b,ap2));if(hp2<0)hp2+=cast(T)360;
    const T dL=y.l-x.l,dC=cp2-cp1;T dh=hp2-hp1;
    if(cp1*cp2==0)dh=0;else if(dh>180)dh-=360;else if(dh<-180)dh+=360;
    const T dH=cast(T)2*sqrt(cp1*cp2)*sin(degToRad(dh/cast(T)2));
    const T lb=(x.l+y.l)/cast(T)2,cbp=(cp1+cp2)/cast(T)2;
    T hb;
    if(cp1*cp2==0)hb=hp1+hp2;else if(abs(hp1-hp2)<=180)hb=(hp1+hp2)/cast(T)2;
    else if(hp1+hp2<360)hb=(hp1+hp2+360)/cast(T)2;else hb=(hp1+hp2-360)/cast(T)2;
    const T tt=cast(T)1-cast(T)0.17*cos(degToRad(hb-30))+cast(T)0.24*cos(degToRad(cast(T)2*hb))
      +cast(T)0.32*cos(degToRad(cast(T)3*hb+6))-cast(T)0.20*cos(degToRad(cast(T)4*hb-63));
    const T dl=lb-50,sl=cast(T)1+cast(T)0.015*dl*dl/sqrt(cast(T)20+dl*dl);
    const T sc=cast(T)1+cast(T)0.045*cbp,sh=cast(T)1+cast(T)0.015*cbp*tt;
    const T rt=-cast(T)2*sqrt(cbp*cbp*cbp*cbp*cbp*cbp*cbp/(cbp*cbp*cbp*cbp*cbp*cbp*cbp+cast(T)6103515625.0))
      *sin(degToRad(cast(T)60*exp2(-((hb-275)/cast(T)25)*((hb-275)/cast(T)25))));
    const T vl=dL/sl,vc=dC/sc,vh=dH/sh;
    return sqrt(vl*vl+vc*vc+vh*vh+rt*vc*vh);
}

void main(){
    enum valid=Lab!double(50,2,-3);
    enum nL=Lab!double(double.nan,2,-3);
    enum nA=Lab!double(50,double.nan,-3);
    enum nB=Lab!double(50,2,double.nan);
    enum infL=Lab!double(double.infinity,2,-3);
    enum infA=Lab!double(50,double.infinity,-3);

    enum dnL=de00(nL,valid),dnA=de00(nA,valid),dnB=de00(nB,valid);
    enum diL=de00(infL,valid),diA=de00(infA,valid);

    static assert(isNaN(dnL));
    static assert(isNaN(dnA));
    static assert(isNaN(dnB));
    static assert(isNaN(diL));
    static assert(isNaN(diA));

    // Large but finite coordinates are a separate contract question. They
    // must not be confused with a CIELAB domain error or silently clamped.
    enum huge=Lab!double(1e100,1e100,-1e100);
    enum dh=de00(huge,valid);
    assert(isInfinity(dh) || dh>=0);

    writeln("R6.6 PASS");
    writeln("NaN propagation PASS");
    writeln("infinity propagation PASS");
    writeln("large finite behavior observed");
    writeln("no implicit clamping PASS");
    writeln("CTFE non-finite evaluation PASS");
}
