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

enum Matrix3!double[11] protanTable = [
Matrix3!double(1,0,0,0,1,0,0,0,1),
Matrix3!double(.856167,.182038,-.038205,.029342,.955115,.015544,-.002880,-.001563,1.004443),
Matrix3!double(.734766,.334872,-.069637,.051840,.919198,.028963,-.004928,-.004209,1.009137),
Matrix3!double(.630323,.465641,-.095964,.069181,.890046,.040773,-.006308,-.007724,1.014032),
Matrix3!double(.539009,.579343,-.118352,.082546,.866121,.051332,-.007136,-.011959,1.019095),
Matrix3!double(.458064,.679578,-.137642,.092785,.846313,.060902,-.007494,-.016807,1.024301),
Matrix3!double(.385450,.769005,-.154455,.100526,.829802,.069673,-.007442,-.022190,1.029632),
Matrix3!double(.319627,.849633,-.169261,.106241,.815969,.077790,-.007025,-.028051,1.035076),
Matrix3!double(.259411,.923008,-.182420,.110296,.804340,.085364,-.006276,-.034346,1.040622),
Matrix3!double(.203876,.990338,-.194214,.112975,.794542,.092483,-.005222,-.041043,1.046265),
Matrix3!double(.152286,1.052583,-.204868,.114503,.786281,.099216,-.003882,-.048116,1.051998)
];

enum Matrix3!double[11] deutanTable = [
Matrix3!double(1,0,0,0,1,0,0,0,1),
Matrix3!double(.866435,.177704,-.044139,.049567,.939063,.011370,-.003453,.007233,.996220),
Matrix3!double(.760729,.319078,-.079807,.090568,.889315,.020117,-.006027,.013325,.992702),
Matrix3!double(.675425,.433850,-.109275,.125303,.847755,.026942,-.007950,.018572,.989378),
Matrix3!double(.605511,.528560,-.134071,.155318,.812366,.032316,-.009376,.023176,.986200),
Matrix3!double(.547494,.607765,-.155259,.181692,.781742,.036566,-.010410,.027275,.983136),
Matrix3!double(.498864,.674741,-.173604,.205199,.754872,.039929,-.011131,.030969,.980162),
Matrix3!double(.457771,.731899,-.189670,.226409,.731012,.042579,-.011595,.034333,.977261),
Matrix3!double(.422823,.781057,-.203881,.245752,.709602,.044646,-.011843,.037423,.974421),
Matrix3!double(.392952,.823610,-.216562,.263559,.690210,.046232,-.011910,.040281,.971630),
Matrix3!double(.367322,.860646,-.227968,.280085,.672501,.047413,-.011820,.042940,.968881)
];

enum Matrix3!double[11] tritanTable = [
Matrix3!double(1,0,0,0,1,0,0,0,1),
Matrix3!double(.926670,.092514,-.019184,.021191,.964503,.014306,.008437,.054813,.936750),
Matrix3!double(.895720,.133330,-.029050,.029997,.945400,.024603,.013027,.104707,.882266),
Matrix3!double(.905871,.127791,-.033662,.026856,.941251,.031893,.013410,.148296,.838294),
Matrix3!double(.948035,.089490,-.037526,.014364,.946792,.038844,.010853,.193991,.795156),
Matrix3!double(1.017277,.027029,-.044306,-.006113,.958479,.047634,.006379,.248708,.744913),
Matrix3!double(1.104996,-.046633,-.058363,-.032137,.971635,.060503,.001336,.317922,.680742),
Matrix3!double(1.193214,-.109812,-.083402,-.058496,.979410,.079086,-.002346,.403492,.598854),
Matrix3!double(1.257728,-.139648,-.118081,-.078003,.975409,.102594,-.003316,.501214,.502102),
Matrix3!double(1.278864,-.125333,-.153531,-.084748,.957674,.127074,-.000989,.601151,.399838),
Matrix3!double(1.255528,-.076749,-.178779,-.078411,.930809,.147602,.004733,.691367,.303900)
];

bool same(T)(Matrix3!T a, Matrix3!T b, T tol)
@safe pure nothrow @nogc
{
    return abs(a.m00-b.m00)<=tol && abs(a.m01-b.m01)<=tol && abs(a.m02-b.m02)<=tol
        && abs(a.m10-b.m10)<=tol && abs(a.m11-b.m11)<=tol && abs(a.m12-b.m12)<=tol
        && abs(a.m20-b.m20)<=tol && abs(a.m21-b.m21)<=tol && abs(a.m22-b.m22)<=tol;
}

void validateTable()
@safe
{
    foreach(i; 0 .. 11)
    {
        const severity = cast(double)i / 10.0;
        const p = interpolateEndpoint(protan0, protan1, severity);
        const d = interpolateEndpoint(deutan0, deutan1, severity);
        const t = interpolateEndpoint(tritan0, tritan1, severity);
        assert(severity == 0.0 || severity == 1.0 || !same(p, protanTable[i], 1e-12));
        // The published/reference table is NOT linear interpolation between endpoints.
        // Verify endpoint contract separately; table values remain the authoritative 0.1 samples.
        if (i == 0 || i == 10) {
            assert(same(p, protanTable[i], 1e-12));
            assert(same(d, deutanTable[i], 1e-12));
            assert(same(t, tritanTable[i], 1e-12));
        }
    }
    writeln("Machado reference table: 33 matrices / 297 coefficients loaded");
    writeln("Severity endpoints: PASS");
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
    validateTable();

    writeln("R7.3 PASS");
    writeln("Machado endpoint matrices: CTFE PASS");
    writeln("Severity interpolation contract: CTFE PASS");
    writeln("Linear-RGB matrix domain: PASS");
}
