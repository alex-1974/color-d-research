// R5.7 research probe for color-d #161.
// Scalar-specific fixed-iteration binary-search accuracy against each scalar's ULP oracle.

import std.algorithm : max;
import std.math : abs, cos, sin, PI;
import std.stdio : writefln;

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
struct B(T){T lo;T hi;size_t growth;size_t bis;}

B!T solve(T)(T L,T h,size_t limit,bool ulp=false) {
    T lo=0,hi=cast(T).125; size_t g,b;
    while(inside(rgb(L,hi,h))){lo=hi;hi*=2;++g;}
    const size_t n=ulp ? (is(T==float)?64:128) : limit;
    foreach(_;0..n){
        const T mid=lo+(hi-lo)/2;
        if(mid==lo||mid==hi) break;
        if(inside(rgb(L,mid,h)))lo=mid;else hi=mid;
        ++b;
    }
    return B!T(lo,hi,g,b);
}

void test(T)(size_t n) {
    size_t samples,outsideFailures,exactMismatch,maxActualBis,maxGrowth;
    double maxAbs=0,maxRel=0,maxWidth=0,wL=0,wH=0,wO=0,wF=0;
    foreach(li;1..100)foreach(hi;0..360){
        const T L=cast(T)li/cast(T)100, h=cast(T)hi;
        const o=solve!T(L,h,0,true), f=solve!T(L,h,n,false);
        if(!inside(rgb(L,f.lo,h)))++outsideFailures;
        if(f.lo!=o.lo)++exactMismatch;
        const double ae=abs(cast(double)f.lo-cast(double)o.lo);
        const double re=ae/cast(double)o.lo, width=cast(double)f.hi-cast(double)f.lo;
        if(ae>maxAbs){maxAbs=ae;maxRel=re;wL=cast(double)L;wH=cast(double)h;wO=cast(double)o.lo;wF=cast(double)f.lo;}
        maxWidth=max(maxWidth,width); maxActualBis=max(maxActualBis,f.bis); maxGrowth=max(maxGrowth,f.growth); ++samples;
    }
    writefln("scalar=%s iterations=%s",T.stringof,n);
    writefln("samples=%s",samples);
    writefln("returned-inside failures=%s",outsideFailures);
    writefln("exact-oracle mismatches=%s",exactMismatch);
    writefln("max abs error=%.17g",maxAbs);
    writefln("relative error at abs-error worst=%.17g",maxRel);
    writefln("max remaining bracket width=%.17g",maxWidth);
    writefln("max actual bisections=%s",maxActualBis);
    writefln("max growth steps=%s",maxGrowth);
    writefln("worst L=%.17g h=%.17g oracle=%.17g fixed=%.17g",wL,wH,wO,wF);
}
void main(){
    foreach(n;[12UL,16UL,20UL,24UL]) test!float(n);
    foreach(n;[16UL,20UL,24UL,32UL]) test!double(n);
}
