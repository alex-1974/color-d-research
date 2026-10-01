// R6.4 research probe for color-d #162.
// CIEDE2000 validation against Sharma/Wu/Dalal supplementary test data.

import std.math : abs, atan2, cos, sin, sqrt, PI;
import std.stdio : writeln;

struct Lab(T){T l;T a;T b;}

T degToRad(T)(T x) @safe pure nothrow @nogc { return x*cast(T)(PI/180.0L); }
T radToDeg(T)(T x) @safe pure nothrow @nogc { return x*cast(T)(180.0L/PI); }

T cbrt(T)(T x) @safe pure nothrow @nogc
{
    if (x==0) return x;
    const bool neg=x<0;
    T a=neg?-x:x;
    T y=a>cast(T)1?a:cast(T)1;
    foreach(_;0..40) y=(cast(T)2*y+a/(y*y))/cast(T)3;
    return neg?-y:y;
}

T deltaE00(T)(Lab!T x, Lab!T y) @safe pure nothrow @nogc
{
    enum T kL=1,kC=1,kH=1;
    const T c1=sqrt(x.a*x.a+x.b*x.b), c2=sqrt(y.a*y.a+y.b*y.b);
    const T cbar=(c1+c2)/cast(T)2;
    const T cbar7=cbar*cbar*cbar*cbar*cbar*cbar*cbar;
    const T G=cast(T)0.5*(cast(T)1-sqrt(cbar7/(cbar7+cast(T)6103515625.0)));
    const T ap1=(cast(T)1+G)*x.a, ap2=(cast(T)1+G)*y.a;
    const T cp1=sqrt(ap1*ap1+x.b*x.b), cp2=sqrt(ap2*ap2+y.b*y.b);

    T hp1=radToDeg(atan2(x.b,ap1)); if(hp1<0) hp1+=cast(T)360;
    T hp2=radToDeg(atan2(y.b,ap2)); if(hp2<0) hp2+=cast(T)360;

    const T dL=y.l-x.l, dC=cp2-cp1;
    T dh=hp2-hp1;
    if(cp1*cp2==0) dh=0;
    else if(dh>180) dh-=360;
    else if(dh<-180) dh+=360;
    const T dH=cast(T)2*sqrt(cp1*cp2)*sin(degToRad(dh/cast(T)2));

    const T lbar=(x.l+y.l)/cast(T)2;
    const T cbarp=(cp1+cp2)/cast(T)2;
    T hbar;
    if(cp1*cp2==0) hbar=hp1+hp2;
    else if(abs(hp1-hp2)<=180) hbar=(hp1+hp2)/cast(T)2;
    else if(hp1+hp2<360) hbar=(hp1+hp2+360)/cast(T)2;
    else hbar=(hp1+hp2-360)/cast(T)2;

    const T Tt=
        cast(T)1-
        cast(T)0.17*cos(degToRad(hbar-cast(T)30))+
        cast(T)0.24*cos(degToRad(cast(T)2*hbar))+
        cast(T)0.32*cos(degToRad(cast(T)3*hbar+cast(T)6))-
        cast(T)0.20*cos(degToRad(cast(T)4*hbar-cast(T)63));

    const T dl=lbar-cast(T)50;
    const T Sl=cast(T)1+cast(T)0.015*dl*dl/sqrt(cast(T)20+dl*dl);
    const T Sc=cast(T)1+cast(T)0.045*cbarp;
    const T Sh=cast(T)1+cast(T)0.015*cbarp*Tt;

    const T Rt=-cast(T)2*sqrt(
        cbarp*cbarp*cbarp*cbarp*cbarp*cbarp*cbarp/
        (cbarp*cbarp*cbarp*cbarp*cbarp*cbarp*cbarp+cast(T)6103515625.0)
    ) * sin(degToRad(cast(T)60*exp2(-((hbar-cast(T)275)/cast(T)25)*((hbar-cast(T)275)/cast(T)25)))));

    const T vl=dL/(kL*Sl), vc=dC/(kC*Sc), vh=dH/(kH*Sh);
    return sqrt(vl*vl+vc*vc+vh*vh+Rt*vc*vh);
}

struct Case { double l1,a1,b1,l2,a2,b2,expected; }
enum cases = [
Case(50,2.6772,-79.7751,50,0,-82.7485,2.0425),
Case(50,3.1571,-77.2803,50,0,-82.7485,2.8615),
Case(50,2.8361,-74.0200,50,0,-82.7485,3.4412),
Case(50,-1.3802,-84.2814,50,0,-82.7485,1.0000),
Case(50,-1.1848,-84.8006,50,0,-82.7485,1.0000),
Case(50,-0.9009,-85.5211,50,0,-82.7485,1.0000),
Case(50,0,0,50,-1,2,2.3669),
Case(50,-1,2,50,0,0,2.3669),
Case(50,2.49,-0.001,50,-2.49,0.0009,7.1792),
Case(50,2.49,-0.001,50,-2.49,0.001,7.1792),
Case(50,2.49,-0.001,50,-2.49,0.0011,7.2195),
Case(50,2.49,-0.001,50,-2.49,0.0012,7.2195),
Case(50,-0.001,2.49,50,0.0009,-2.49,4.8045),
Case(50,-0.001,2.49,50,0.001,-2.49,4.8045),
Case(50,-0.001,2.49,50,0.0011,-2.49,4.7461),
Case(50,2.5,0,50,0,-2.5,4.3065),
Case(50,2.5,0,73,25,-18,27.1492),
Case(50,2.5,0,61,-5,29,22.8977),
Case(50,2.5,0,56,-27,-3,31.9030),
Case(50,2.5,0,58,24,15,19.4535),
Case(50,2.5,0,50,3.1736,0.5854,1.0000),
Case(50,2.5,0,50,3.2972,0,1.0000),
Case(50,2.5,0,50,1.8634,0.5757,1.0000),
Case(50,2.5,0,50,3.2592,0.3350,1.0000),
Case(60.2574,-34.0099,36.2677,60.4626,-34.1751,39.4387,1.2644),
Case(63.0109,-31.0961,-5.8663,62.8187,-29.7946,-4.0864,1.2630),
Case(61.2901,3.7196,-5.3901,61.4292,2.2480,-4.9620,1.8731),
Case(35.0831,-44.1164,3.7933,35.0232,-40.0716,1.5901,1.8645),
Case(22.7233,20.0904,-46.6940,23.0331,14.9730,-42.5619,2.0373),
Case(36.4612,47.8580,18.3852,36.2715,50.5065,21.2231,1.4146),
Case(90.8027,-2.0831,1.4410,91.1528,-1.6435,0.0447,1.4441),
Case(90.9257,-0.5406,-0.9208,88.6381,-0.8985,-0.7239,1.5381),
Case(6.7747,-0.2908,-2.4247,5.8714,-0.0985,-2.2286,0.6377),
Case(2.0776,0.0795,-1.1350,0.9033,-0.0636,-0.5514,0.9082)
];

bool close(double a,double b){return abs(a-b)<=0.00006;}

void main(){
    size_t failures;
    double maxError;
    foreach(i,c;cases){
        enum d=deltaE00(Lab!double(c.l1,c.a1,c.b1),Lab!double(c.l2,c.a2,c.b2));
        static assert(d>=0);
        const e=abs(d-c.expected);
        if(e>maxError) maxError=e;
        if(!close(d,c.expected)){
            ++failures;
            writeln("FAIL case ",i+1,": got ",d," expected ",c.expected," error ",e);
        }
    }
    assert(failures==0);
    writeln("R6.4 PASS");
    writeln("cases=",cases.length);
    writeln("max absolute error=",maxError);
    writeln("CTFE reference evaluation PASS");
}
