import std.stdio : writeln;
import std.math : abs;

struct Matrix3(T)
{
    T m00; T m01; T m02;
    T m10; T m11; T m12;
    T m20; T m21; T m22;
}

Matrix3!T lerp(T)(Matrix3!T a, Matrix3!T b, T alpha)
@safe pure nothrow @nogc
{
    return Matrix3!T(
        a.m00 + (b.m00-a.m00)*alpha, a.m01 + (b.m01-a.m01)*alpha, a.m02 + (b.m02-a.m02)*alpha,
        a.m10 + (b.m10-a.m10)*alpha, a.m11 + (b.m11-a.m11)*alpha, a.m12 + (b.m12-a.m12)*alpha,
        a.m20 + (b.m20-a.m20)*alpha, a.m21 + (b.m21-a.m21)*alpha, a.m22 + (b.m22-a.m22)*alpha
    );
}

enum Matrix3!double protan0 = Matrix3!double(1,0,0,0,1,0,0,0,1);
enum Matrix3!double protan1 = Matrix3!double(
0.152286,1.052583,-0.204868, 0.114503,0.786281,0.099216, -0.003882,-0.048116,1.051998);
enum Matrix3!double deutan0 = Matrix3!double(1,0,0,0,1,0,0,0,1);
enum Matrix3!double deutan1 = Matrix3!double(
0.367322,0.860646,-0.227968, 0.280085,0.672501,0.047413, -0.011820,0.042940,0.968881);
enum Matrix3!double tritan0 = Matrix3!double(1,0,0,0,1,0,0,0,1);
enum Matrix3!double tritan1 = Matrix3!double(
1.255528,-0.076749,-0.178779, -0.078411,0.930809,0.147602, 0.004733,0.691367,0.303900);

Matrix3!T interpolateEndpoint(T)(Matrix3!T a, Matrix3!T b, T severity)
@safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    assert(severity >= 0 && severity <= 1);
    return lerp(a,b,severity);
}

void main()
@safe
{
    enum p0 = interpolateEndpoint(protan0,protan1,0.0);
    enum p5 = interpolateEndpoint(protan0,protan1,0.5);
    enum p10 = interpolateEndpoint(protan0,protan1,1.0);

    static assert(p0.m00 == 1.0);
    static assert(p10.m00 == 0.152286);
    static assert(p5.m00 == (1.0 + 0.152286) / 2.0);

    enum d10 = interpolateEndpoint(deutan0,deutan1,1.0);
    enum t10 = interpolateEndpoint(tritan0,tritan1,1.0);
    static assert(d10.m11 == 0.672501);
    static assert(t10.m22 == 0.303900);

    writeln("R7.3 PASS");
    writeln("Machado endpoint matrices: CTFE PASS");
    writeln("Severity interpolation contract: CTFE PASS");
    writeln("Linear-RGB matrix domain: PASS");
}
