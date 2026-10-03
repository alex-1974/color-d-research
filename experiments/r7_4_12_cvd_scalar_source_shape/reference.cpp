#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

template<class T>
struct Rgb
{
    T r;
    T g;
    T b;
};

template<class T>
struct Matrix3
{
    T m00; T m01; T m02;
    T m10; T m11; T m12;
    T m20; T m21; T m22;
};

template<class T>
struct BrettelPlan
{
    Matrix3<T> first;
    Matrix3<T> second;
    T nr;
    T ng;
    T nb;
};

static constexpr Matrix3<double> vienotProtan = {
    0.11238,  0.88762, 0.0,
    0.11238,  0.88762, 0.0,
    0.00401, -0.00401, 1.0
};

static constexpr Matrix3<double> vienotDeutan = {
     0.29275, 0.70725, 0.0,
     0.29275, 0.70725, 0.0,
    -0.02234, 0.02234, 1.0
};

static constexpr Matrix3<double> brettelProtan1 = {
     0.14980,  1.19548, -0.34528,
     0.10764,  0.84864,  0.04372,
     0.00384, -0.00540,  1.00156
};

static constexpr Matrix3<double> brettelProtan2 = {
     0.14570,  1.16172, -0.30742,
     0.10816,  0.85291,  0.03892,
     0.00386, -0.00524,  1.00139
};

static constexpr Matrix3<double> brettelDeutan1 = {
     0.36477,  0.86381, -0.22858,
     0.26294,  0.64245,  0.09462,
    -0.02006,  0.02728,  0.99278
};

static constexpr Matrix3<double> brettelDeutan2 = {
     0.37298,  0.88166, -0.25464,
     0.25954,  0.63506,  0.10540,
    -0.01980,  0.02784,  0.99196
};

static constexpr Matrix3<double> brettelTritan1 = {
     1.01277,  0.13548, -0.14826,
    -0.01243,  0.86812,  0.14431,
     0.07589,  0.80500,  0.11911
};

static constexpr Matrix3<double> brettelTritan2 = {
     0.93678,  0.18979, -0.12657,
     0.06154,  0.81526,  0.12320,
    -0.37562,  1.12767,  0.24796
};

static constexpr Matrix3<double> identityMatrix = {
    1, 0, 0,
    0, 1, 0,
    0, 0, 1
};

static constexpr std::array<Matrix3<double>, 11> machadoProtanTable = {{
    identityMatrix,
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

static constexpr std::array<Matrix3<double>, 11> machadoDeutanTable = {{
    identityMatrix,
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
static inline Matrix3<T> precisionMatrix(Matrix3<double> matrix)
{
    return {
        T(matrix.m00), T(matrix.m01), T(matrix.m02),
        T(matrix.m10), T(matrix.m11), T(matrix.m12),
        T(matrix.m20), T(matrix.m21), T(matrix.m22)
    };
}

template<class T>
static inline void directWrite(
    Rgb<T>& output,
    const Matrix3<T>& matrix,
    T r,
    T g,
    T b
)
{
    output.r = matrix.m00 * r + matrix.m01 * g + matrix.m02 * b;
    output.g = matrix.m10 * r + matrix.m11 * g + matrix.m12 * b;
    output.b = matrix.m20 * r + matrix.m21 * g + matrix.m22 * b;
}

template<class T>
static inline Matrix3<T> prepareVienot(unsigned deficiency)
{
    return precisionMatrix<T>(
        deficiency == 0
            ? vienotProtan
            : vienotDeutan
    );
}

template<class T>
static inline BrettelPlan<T> prepareBrettel(unsigned deficiency)
{
    if (deficiency == 0)
    {
        return {
            precisionMatrix<T>(brettelProtan1),
            precisionMatrix<T>(brettelProtan2),
            T(0.00048),
            T(0.00393),
            T(-0.00441)
        };
    }

    if (deficiency == 1)
    {
        return {
            precisionMatrix<T>(brettelDeutan1),
            precisionMatrix<T>(brettelDeutan2),
            T(-0.00281),
            T(-0.00611),
            T(0.00892)
        };
    }

    return {
        precisionMatrix<T>(brettelTritan1),
        precisionMatrix<T>(brettelTritan2),
        T(0.03901),
        T(-0.02788),
        T(-0.01113)
    };
}

static inline const std::array<Matrix3<double>, 11>&
machadoTable(unsigned deficiency)
{
    return deficiency == 0
        ? machadoProtanTable
        : machadoDeutanTable;
}

template<class T>
static inline Matrix3<T> prepareMachado(
    unsigned deficiency,
    T severity
)
{
    const auto& table = machadoTable(deficiency);

    const T scaled = severity * T(10);
    const std::size_t lower =
        static_cast<std::size_t>(scaled);

    if (lower >= 10)
        return precisionMatrix<T>(table[10]);

    const T alpha = scaled - T(lower);
    const auto x = precisionMatrix<T>(table[lower]);
    const auto y = precisionMatrix<T>(table[lower + 1]);

    return {
        x.m00 + (y.m00 - x.m00) * alpha,
        x.m01 + (y.m01 - x.m01) * alpha,
        x.m02 + (y.m02 - x.m02) * alpha,
        x.m10 + (y.m10 - x.m10) * alpha,
        x.m11 + (y.m11 - x.m11) * alpha,
        x.m12 + (y.m12 - x.m12) * alpha,
        x.m20 + (y.m20 - x.m20) * alpha,
        x.m21 + (y.m21 - x.m21) * alpha,
        x.m22 + (y.m22 - x.m22) * alpha
    };
}

template<class T>
static inline Rgb<T> scalarVienot(
    Rgb<T> color,
    unsigned deficiency
)
{
    const auto matrix =
        prepareVienot<T>(deficiency);

    Rgb<T> output;
    directWrite(
        output,
        matrix,
        color.r,
        color.g,
        color.b
    );

    return output;
}

template<class T>
static inline Rgb<T> scalarMachado(
    Rgb<T> color,
    unsigned deficiency,
    T severity
)
{
    const auto matrix =
        prepareMachado<T>(
            deficiency,
            severity
        );

    Rgb<T> output;
    directWrite(
        output,
        matrix,
        color.r,
        color.g,
        color.b
    );

    return output;
}

template<class T>
static inline Rgb<T> scalarBrettel(
    Rgb<T> color,
    unsigned deficiency
)
{
    const auto plan =
        prepareBrettel<T>(deficiency);

    const auto& matrix =
        color.r * plan.nr +
        color.g * plan.ng +
        color.b * plan.nb >= T(0)
            ? plan.first
            : plan.second;

    Rgb<T> output;
    directWrite(
        output,
        matrix,
        color.r,
        color.g,
        color.b
    );

    return output;
}


enum class ScalarModel
{
    Vienot,
    Machado,
    Brettel
};

enum class Workload
{
    Fixed,
    Dynamic
};

static constexpr const char* scalarModelLabels[] = {
    "vienot",
    "machado",
    "brettel"
};

static constexpr const char* workloadLabels[] = {
    "fixed",
    "dynamic"
};

template<class T>
static const char* scalarLabel()
{
    return sizeof(T) == sizeof(float)
        ? "float"
        : "double";
}

template<class T, ScalarModel model>
static Rgb<T> scalarCall(
    Rgb<T> color,
    unsigned deficiency,
    T severity
)
{
    if constexpr (model == ScalarModel::Vienot)
        return scalarVienot<T>(color, deficiency);
    else if constexpr (model == ScalarModel::Machado)
        return scalarMachado<T>(color, deficiency, severity);
    else
        return scalarBrettel<T>(color, deficiency);
}

template<class T, ScalarModel model, Workload workload>
__attribute__((noinline))
static void scalarBatch(
    const std::vector<Rgb<T>>& input,
    std::vector<Rgb<T>>& output,
    const std::vector<unsigned>& deficiencies,
    const std::vector<T>& severities,
    unsigned fixedDeficiency,
    T fixedSeverity
)
{
    if constexpr (workload == Workload::Fixed)
    {
        for (std::size_t i = 0; i < input.size(); ++i)
            output[i] =
                scalarCall<T, model>(
                    input[i],
                    fixedDeficiency,
                    fixedSeverity
                );
    }
    else
    {
        for (std::size_t i = 0; i < input.size(); ++i)
            output[i] =
                scalarCall<T, model>(
                    input[i],
                    deficiencies[i],
                    severities[i]
                );
    }
}

template<class T, ScalarModel model, Workload workload>
static void runCase(
    std::size_t n,
    bool reverse
)
{
    std::vector<Rgb<T>> input(n);
    std::vector<Rgb<T>> output(n);
    std::vector<unsigned> deficiencies(n);
    std::vector<T> severities(n);

    std::uint32_t state = 0x12345678;
    constexpr unsigned count =
        model == ScalarModel::Brettel ? 3u : 2u;

    for (std::size_t i = 0; i < n; ++i)
    {
        state = state * 1664525u + 1013904223u;
        input[i].r =
            T((state >> 8) & 65535) / T(32767) - T(0.5);

        state = state * 1664525u + 1013904223u;
        input[i].g =
            T((state >> 8) & 65535) / T(32767) - T(0.5);

        state = state * 1664525u + 1013904223u;
        input[i].b =
            T((state >> 8) & 65535) / T(32767) - T(0.5);

        deficiencies[i] =
            unsigned((i * 5 + 1) % count);

        severities[i] =
            T((i * 17 + 13) % 101) / T(100);
    }

    constexpr unsigned fixedDeficiency = 0;
    const T fixedSeverity = T(0.65);

    for (int warm = 0; warm < 4; ++warm)
        scalarBatch<T, model, workload>(
            input,
            output,
            deficiencies,
            severities,
            fixedDeficiency,
            fixedSeverity
        );

    for (int round = 0; round < 5; ++round)
    {
        double checksum = 0;

        const auto start =
            std::chrono::steady_clock::now();

        for (int repeat = 0; repeat < 3; ++repeat)
        {
            input[0].r =
                T(repeat + round) / T(12);

            scalarBatch<T, model, workload>(
                input,
                output,
                deficiencies,
                severities,
                fixedDeficiency,
                fixedSeverity
            );

            const auto color =
                output[
                    (
                        std::size_t(repeat) * 997 +
                        std::size_t(round) * 37
                    ) %
                    n
                ];

            checksum +=
                double(color.r) +
                double(color.g) +
                double(color.b);
        }

        const auto stop =
            std::chrono::steady_clock::now();

        const double ns =
            std::chrono::duration<double, std::nano>(
                stop - start
            ).count() /
            double(n * 3);

        std::printf(
            "sample,CPP,%s,%s,%s,%zu,%s,%d,%.9f,%.17g\n",
            scalarLabel<T>(),
            scalarModelLabels[static_cast<int>(model)],
            workloadLabels[static_cast<int>(workload)],
            n,
            reverse ? "true" : "false",
            round,
            ns,
            checksum
        );
    }
}

template<class T, Workload workload>
static void runWorkload(
    std::size_t n,
    bool reverse
)
{
    if (reverse)
    {
        runCase<T, ScalarModel::Brettel, workload>(n, reverse);
        runCase<T, ScalarModel::Machado, workload>(n, reverse);
        runCase<T, ScalarModel::Vienot, workload>(n, reverse);
    }
    else
    {
        runCase<T, ScalarModel::Vienot, workload>(n, reverse);
        runCase<T, ScalarModel::Machado, workload>(n, reverse);
        runCase<T, ScalarModel::Brettel, workload>(n, reverse);
    }
}

template<class T>
static void cases(
    std::size_t n,
    bool reverse
)
{
    if (reverse)
    {
        runWorkload<T, Workload::Dynamic>(n, reverse);
        runWorkload<T, Workload::Fixed>(n, reverse);
    }
    else
    {
        runWorkload<T, Workload::Fixed>(n, reverse);
        runWorkload<T, Workload::Dynamic>(n, reverse);
    }
}

int main(
    int argc,
    char** argv
)
{
    const std::size_t n =
        argc > 1
            ? std::strtoull(argv[1], nullptr, 10)
            : 8191;

    if (n < 32 || n > 1048576)
        return 2;

    const bool reverse =
        argc > 2;

    if (reverse)
    {
        cases<double>(n, reverse);
        cases<float>(n, reverse);
    }
    else
    {
        cases<float>(n, reverse);
        cases<double>(n, reverse);
    }

    return 0;
}
