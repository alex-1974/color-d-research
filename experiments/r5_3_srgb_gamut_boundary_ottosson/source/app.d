// R5.3 research probe for color-d #161.
//
// Compares the independent binary-search oracle with Björn Ottosson's
// sRGB gamut-intersection construction, specialized to constant L.
// Algorithm adapted from MIT-licensed reference code:
// https://bottosson.github.io/posts/gamutclipping/

import std.algorithm : max, min;
import std.math : abs, cbrt, cos, sin, PI;
import std.stdio : writefln;

struct Rgb(T) { T r; T g; T b; }
struct LC(T) { T L; T C; }
struct Boundary(T) { T inside; T outside; }

Rgb!T toRgb(T)(T L, T C, T aDir, T bDir)
{
    const T a = C * aDir, b = C * bDir;
    const T lp = L + cast(T)0.3963377774*a + cast(T)0.2158037573*b;
    const T mp = L - cast(T)0.1055613458*a - cast(T)0.0638541728*b;
    const T sp = L - cast(T)0.0894841775*a - cast(T)1.2914855480*b;
    const T l=lp*lp*lp, m=mp*mp*mp, s=sp*sp*sp;
    return Rgb!T(
        cast(T)4.0767416621*l-cast(T)3.3077115913*m+cast(T)0.2309699292*s,
       -cast(T)1.2684380046*l+cast(T)2.6097574011*m-cast(T)0.3413193965*s,
       -cast(T)0.0041960863*l-cast(T)0.7034186147*m+cast(T)1.7076147010*s);
}
bool inCube(T)(Rgb!T c) { return c.r>=0&&c.r<=1&&c.g>=0&&c.g<=1&&c.b>=0&&c.b<=1; }

Boundary!T oracle(T)(T L,T ad,T bd)
{
    T lo=0, hi=cast(T).125;
    while(inCube(toRgb(L,hi,ad,bd))) hi*=2;
    foreach(_;0..(is(T==float)?64:128)) {
        const mid=lo+(hi-lo)/2;
        if(mid==lo||mid==hi) break;
        if(inCube(toRgb(L,mid,ad,bd))) lo=mid; else hi=mid;
    }
    return Boundary!T(lo,hi);
}

T maxSaturation(T)(T a,T b)
{
    T k0,k1,k2,k3,k4,wl,wm,ws;
    if(cast(T)-1.88170328*a-cast(T).80936493*b>1) {
        k0=cast(T)1.19086277;k1=cast(T)1.76576728;k2=cast(T).59662641;k3=cast(T).75515197;k4=cast(T).56771245;
        wl=cast(T)4.0767416621;wm=cast(T)-3.3077115913;ws=cast(T).2309699292;
    } else if(cast(T)1.81444104*a-cast(T)1.19445276*b>1) {
        k0=cast(T).73956515;k1=cast(T)-.45954404;k2=cast(T).08285427;k3=cast(T).12541070;k4=cast(T).14503204;
        wl=cast(T)-1.2684380046;wm=cast(T)2.6097574011;ws=cast(T)-.3413193965;
    } else {
        k0=cast(T)1.35733652;k1=cast(T)-.00915799;k2=cast(T)-1.15130210;k3=cast(T)-.50559606;k4=cast(T).00692167;
        wl=cast(T)-.0041960863;wm=cast(T)-.7034186147;ws=cast(T)1.7076147010;
    }
    T S=k0+k1*a+k2*b+k3*a*a+k4*a*b;
    const kl=cast(T).3963377774*a+cast(T).2158037573*b;
    const km=cast(T)-.1055613458*a-cast(T).0638541728*b;
    const ks=cast(T)-.0894841775*a-cast(T)1.2914855480*b;
    const lp=1+S*kl,mp=1+S*km,sp=1+S*ks;
    const l=lp*lp*lp,m=mp*mp*mp,s=sp*sp*sp;
    const ld=3*kl*lp*lp,md=3*km*mp*mp,sd=3*ks*sp*sp;
    const ld2=6*kl*kl*lp,md2=6*km*km*mp,sd2=6*ks*ks*sp;
    const f=wl*l+wm*m+ws*s, f1=wl*ld+wm*md+ws*sd, f2=wl*ld2+wm*md2+ws*sd2;
    return S-f*f1/(f1*f1-cast(T).5*f*f2);
}

LC!T cusp(T)(T a,T b)
{
    const S=maxSaturation(a,b);
    const rgb=toRgb(cast(T)1,S,a,b);
    const L=cbrt(cast(T)1/max(rgb.r,max(rgb.g,rgb.b)));
    return LC!T(L,L*S);
}

// Ottosson intersection with L1 == L0 == L and C1 == 1.
// Returned t is therefore directly C_max.
T ottossonCmax(T)(T L,T a,T b)
{
    const cp=cusp(a,b);
    T t;
    if ((L-cp.L) >= 0) {
        t=cp.C*(L-1)/(cp.C*(L-1)); // triangle seed simplifies to 1; replaced below
        t=cp.C*(L-1)/(cp.L-1);     // C1=1, L0=L1=L
        const kl=cast(T).3963377774*a+cast(T).2158037573*b;
        const km=cast(T)-.1055613458*a-cast(T).0638541728*b;
        const ks=cast(T)-.0894841775*a-cast(T)1.2914855480*b;
        const ldt=kl,mdt=km,sdt=ks;
        const lp=L+t*kl,mp=L+t*km,sp=L+t*ks;
        const l=lp*lp*lp,m=mp*mp*mp,s=sp*sp*sp;
        const ld=3*ldt*lp*lp,md=3*mdt*mp*mp,sd=3*sdt*sp*sp;
        const ld2=6*ldt*ldt*lp,md2=6*mdt*mdt*mp,sd2=6*sdt*sdt*sp;
        const rr=cast(T)4.0767416621*l-cast(T)3.3077115913*m+cast(T).2309699292*s-1;
        const r1=cast(T)4.0767416621*ld-cast(T)3.3077115913*md+cast(T).2309699292*sd;
        const r2=cast(T)4.0767416621*ld2-cast(T)3.3077115913*md2+cast(T).2309699292*sd2;
        const gg=cast(T)-1.2684380046*l+cast(T)2.6097574011*m-cast(T).3413193965*s-1;
        const g1=cast(T)-1.2684380046*ld+cast(T)2.6097574011*md-cast(T).3413193965*sd;
        const g2=cast(T)-1.2684380046*ld2+cast(T)2.6097574011*md2-cast(T).3413193965*sd2;
        const bb=cast(T)-.0041960863*l-cast(T).7034186147*m+cast(T)1.7076147010*s-1;
        const b1=cast(T)-.0041960863*ld-cast(T).7034186147*md+cast(T)1.7076147010*sd;
        const b2=cast(T)-.0041960863*ld2-cast(T).7034186147*md2+cast(T)1.7076147010*sd2;
        const ur=r1/(r1*r1-cast(T).5*rr*r2), ug=g1/(g1*g1-cast(T).5*gg*g2), ub=b1/(b1*b1-cast(T).5*bb*b2);
        const tr=ur>=0 ? -rr*ur : T.max, tg=ug>=0 ? -gg*ug : T.max, tb=ub>=0 ? -bb*ub : T.max;
        t+=min(tr,min(tg,tb));
    } else {
        t=cp.C*L/cp.L; // exact lower straight edge
    }
    return t;
}

void main()
{
    size_t n, outsideFast, belowOracle, aboveOracle;
    double maxAbs=0,maxRel=0,wL=0,wH=0,wO=0,wF=0;
    foreach(li;1..100) foreach(hi;0..360) {
        const L=li/100.0, h=cast(double)hi, rad=h*(PI/180.0);
        const ad=cos(rad),bd=sin(rad);
        const o=oracle!double(L,ad,bd);
        const f=ottossonCmax!double(L,ad,bd);
        const e=abs(f-o.inside), rel=e/o.inside;
        if(e>maxAbs){maxAbs=e;maxRel=rel;wL=L;wH=h;wO=o.inside;wF=f;}
        if(!inCube(toRgb(L,f,ad,bd))) ++outsideFast;
        if(f<o.inside) ++belowOracle;
        if(f>o.outside) ++aboveOracle;
        ++n;
    }
    writefln("samples=%s",n);
    writefln("fast candidate outside strict cube=%s",outsideFast);
    writefln("fast candidate below oracle inside=%s",belowOracle);
    writefln("fast candidate above oracle outside=%s",aboveOracle);
    writefln("max abs error=%.17g",maxAbs);
    writefln("relative error at worst=%.17g",maxRel);
    writefln("worst L=%.17g h=%.17g oracle=%.17g fast=%.17g",wL,wH,wO,wF);
}
