#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

template<class T>
struct Rgb { T r; T g; T b; };

template<class T>
struct Matrix3
{
    T m00; T m01; T m02;
    T m10; T m11; T m12;
    T m20; T m21; T m22;
};

static constexpr Matrix3<double> vienotProtan = {
    0.11238, 0.88762, 0.0,
    0.11238, 0.88762, 0.0,
    0.00401,-0.00401, 1.0
};

static constexpr Matrix3<double> vienotDeutan = {
     0.29275, 0.70725, 0.0,
     0.29275, 0.70725, 0.0,
    -0.02234, 0.02234, 1.0
};

static constexpr Matrix3<double> identity = {
    1,0,0, 0,1,0, 0,0,1
};

static constexpr std::array<Matrix3<double>,11> machadoProtan = {{
    identity,
    {.856167,.182038,-.038205,.029342,.955115,.015544,-.002880,-.001563,1.004443},
    {.734766,.334872,-.069637,.051840,.919198,.028963,-.004928,-.004209,1.009137},
    {.630323,.465641,-.095964,.069181,.890046,.040773,-.006308,-.007724,1.014032},
    {.539009,.579343,-.118352,.082546,.866121,.051332,-.007136,-.011959,1.019095},
    {.458064,.679578,-.137642,.092785,.846313,.060902,-.007494,-.016807,1.024301},
    {.385450,.769005,-.154455,.100526,.829802,.069673,-.007442,-.022190,1.029632},
    {.319627,.849633,-.169261,.106241,.815969,.077790,-.007025,-.028051,1.035076},
    {.259411,.923008,-.182420,.110296,.804340,.085364,-.006276,-.034346,1.040622},
    {.203876,.990338,-.194214,.112975,.794542,.092483,-.005222,-.041043,1.046265},
    {.152286,1.052583,-.204868,.114503,.786281,.099216,-.003882,-.048116,1.051998}
}};

static constexpr std::array<Matrix3<double>,11> machadoDeutan = {{
    identity,
    {.866435,.177704,-.044139,.049567,.939063,.011370,-.003453,.007233,.996220},
    {.760729,.319078,-.079807,.090568,.889315,.020117,-.006027,.013325,.992702},
    {.675425,.433850,-.109275,.125303,.847755,.026942,-.007950,.018572,.989378},
    {.605511,.528560,-.134071,.155318,.812366,.032316,-.009376,.023176,.986200},
    {.547494,.607765,-.155259,.181692,.781742,.036566,-.010410,.027275,.983136},
    {.498864,.674741,-.173604,.205199,.754872,.039929,-.011131,.030969,.980162},
    {.457771,.731899,-.189670,.226409,.731012,.042579,-.011595,.034333,.977261},
    {.422823,.781057,-.203881,.245752,.709602,.044646,-.011843,.037423,.974421},
    {.392952,.823610,-.216562,.263559,.690210,.046232,-.011910,.040281,.971630},
    {.367322,.860646,-.227968,.280085,.672501,.047413,-.011820,.042940,.968881}
}};

template<class T>
static inline Matrix3<T> castMatrix(const Matrix3<double>& m)
{
    return {T(m.m00),T(m.m01),T(m.m02),T(m.m10),T(m.m11),T(m.m12),
            T(m.m20),T(m.m21),T(m.m22)};
}

template<class T>
static Matrix3<T> prepareVienot(unsigned deficiency)
{
    return castMatrix<T>(deficiency ? vienotDeutan : vienotProtan);
}

template<class T>
static Matrix3<T> prepareMachado(unsigned deficiency, T severity)
{
    const auto& table = deficiency ? machadoDeutan : machadoProtan;
    const T scaled = severity * T(10);
    const std::size_t lower = static_cast<std::size_t>(scaled);
    if (lower >= 10) return castMatrix<T>(table[10]);

    const T alpha = scaled - T(lower);
    const auto a = castMatrix<T>(table[lower]);
    const auto b = castMatrix<T>(table[lower+1]);

    return {
        a.m00+(b.m00-a.m00)*alpha, a.m01+(b.m01-a.m01)*alpha, a.m02+(b.m02-a.m02)*alpha,
        a.m10+(b.m10-a.m10)*alpha, a.m11+(b.m11-a.m11)*alpha, a.m12+(b.m12-a.m12)*alpha,
        a.m20+(b.m20-a.m20)*alpha, a.m21+(b.m21-a.m21)*alpha, a.m22+(b.m22-a.m22)*alpha
    };
}

template<class T>
__attribute__((noinline))
static void batch(const Matrix3<T>& m, const std::vector<Rgb<T>>& in, std::vector<Rgb<T>>& out)
{
    for (std::size_t i=0; i<in.size(); ++i)
    {
        const T r=in[i].r, g=in[i].g, b=in[i].b;
        out[i].r = m.m00*r + m.m01*g + m.m02*b;
        out[i].g = m.m10*r + m.m11*g + m.m12*b;
        out[i].b = m.m20*r + m.m21*g + m.m22*b;
    }
}

enum class Model { Vienot, Machado };
static constexpr const char* modelLabels[] = {"vienot","machado"};
static constexpr double severity = 0.65;

template<class T, Model model>
static void runCase(std::size_t n, unsigned deficiency, bool reverse)
{
    std::vector<Rgb<T>> in(n), out(n);
    std::uint32_t state=0x12345678;

    for (auto& c : in)
    {
        state=state*1664525u+1013904223u; c.r=T((state>>8)&65535)/T(65535);
        state=state*1664525u+1013904223u; c.g=T((state>>8)&65535)/T(65535);
        state=state*1664525u+1013904223u; c.b=T((state>>8)&65535)/T(65535);
    }

    const auto matrix = model==Model::Vienot
        ? prepareVienot<T>(deficiency)
        : prepareMachado<T>(deficiency,T(severity));

    for(int w=0; w<4; ++w) batch(matrix,in,out);

    for(int round=0; round<11; ++round)
    {
        double checksum=0;
        const auto start=std::chrono::steady_clock::now();

        for(int repeat=0; repeat<24; ++repeat)
        {
            in[0].r=T(repeat+round)/T(48);
            batch(matrix,in,out);
            const auto c=out[(std::size_t(repeat)*997+std::size_t(round)*37)%n];
            checksum += double(c.r)+double(c.g)+double(c.b);
        }

        const auto stop=std::chrono::steady_clock::now();
        const double ns=std::chrono::duration<double,std::nano>(stop-start).count()/double(n*24);

        std::printf("sample,CPP,%s,%s,%u,%zu,%s,%d,%.9f,%.17g\n",
            sizeof(T)==sizeof(float)?"float":"double",
            modelLabels[static_cast<int>(model)], deficiency, n,
            reverse?"true":"false", round, ns, checksum);
    }
}

template<class T, Model model>
static void runModel(std::size_t n, bool reverse)
{
    for(unsigned x=0; x<2; ++x)
    {
        const unsigned d=reverse ? 1u-x : x;
        runCase<T,model>(n,d,reverse);
    }
}

template<class T>
static void cases(std::size_t n,bool reverse)
{
    if(reverse){ runModel<T,Model::Machado>(n,reverse); runModel<T,Model::Vienot>(n,reverse); }
    else { runModel<T,Model::Vienot>(n,reverse); runModel<T,Model::Machado>(n,reverse); }
}

int main(int argc,char** argv)
{
    const std::size_t n=argc>1?std::strtoull(argv[1],nullptr,10):65536;
    if(n<32 || n>1048576) return 2;
    const bool reverse=argc>2;
    if(reverse){ cases<double>(n,reverse); cases<float>(n,reverse); }
    else { cases<float>(n,reverse); cases<double>(n,reverse); }
    return 0;
}
