import std.stdio : writeln;

struct Rgb(T){T r;T g;T b;}
struct Lms(T){T l;T m;T s;}

Lms!T rgbToLms(T)(Rgb!T c) @safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return Lms!T(
        cast(T)0.31399022*c.r + cast(T)0.63951294*c.g + cast(T)0.04649755*c.b,
        cast(T)0.15537241*c.r + cast(T)0.75789446*c.g + cast(T)0.08670142*c.b,
        cast(T)0.01775239*c.r + cast(T)0.10944209*c.g + cast(T)0.87256922*c.b
    );
}

Rgb!T lmsToRgb(T)(Lms!T c) @safe pure nothrow @nogc
if (is(T == float) || is(T == double))
{
    return Rgb!T(
        cast(T)5.47221206*c.l - cast(T)4.64196010*c.m + cast(T)0.16963708*c.s,
        -cast(T)1.12524190*c.l + cast(T)2.29317094*c.m - cast(T)0.16789520*c.s,
        cast(T)0.02980165*c.l - cast(T)0.19318073*c.m + cast(T)1.16364789*c.s
    );
}

enum Rgb!double whiteD65 = Rgb!double(0.95047,1.0,1.08883);
enum Lms!double whiteLms = rgbToLms(whiteD65);

static assert(whiteLms.l > 0);
static assert(whiteLms.m > 0);
static assert(whiteLms.s > 0);

void main()
{
    enum rgb = Rgb!double(0.2,0.4,0.7);
    enum lms = rgbToLms(rgb);
    enum back = lmsToRgb(lms);

    assert(back.r > 0 && back.r < 1);
    assert(back.g > 0 && back.g < 1);
    assert(back.b > 0 && back.b < 1);

    writeln("R7.1 PASS");
    writeln("RGB->LMS CTFE PASS");
    writeln("LMS->RGB CTFE PASS");
}
