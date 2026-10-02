#include <array>
#include <vector>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <cstdint>

template<class T> struct Rgb { T r,g,b; };
template<class T> struct Matrix { T m00,m01,m02,m10,m11,m12,m20,m21,m22; };
#include "_generated/coefficients.hpp"

template<class T> Matrix<T> precision(Matrix<double> m) {
    return {T(m.m00),T(m.m01),T(m.m02),T(m.m10),T(m.m11),T(m.m12),T(m.m20),T(m.m21),T(m.m22)};
}
template<class T> Rgb<T> apply(Matrix<T> m, Rgb<T> p) {
    return {m.m00*p.r+m.m01*p.g+m.m02*p.b,
        m.m10*p.r+m.m11*p.g+m.m12*p.b,
        m.m20*p.r+m.m21*p.g+m.m22*p.b};
}
template<class T> Matrix<T> at(const std::array<Matrix<T>,11>& table, T severity) {
    T scaled = severity*T(10);
    size_t lo = size_t(scaled);
    if (lo>=10) return table[10];
    T a=scaled-T(lo);
    auto x=table[lo], y=table[lo+1];
    return {x.m00+(y.m00-x.m00)*a,x.m01+(y.m01-x.m01)*a,x.m02+(y.m02-x.m02)*a,
        x.m10+(y.m10-x.m10)*a,x.m11+(y.m11-x.m11)*a,x.m12+(y.m12-x.m12)*a,
        x.m20+(y.m20-x.m20)*a,x.m21+(y.m21-x.m21)*a,x.m22+(y.m22-x.m22)*a};
}
template<class T> Rgb<T> brettel(Rgb<T> p, unsigned d) {
    Matrix<double> matrix;
    if (d==0) matrix = p.r*T(.00048)+p.g*T(.00393)-p.b*T(.00441)>=0 ? brettelProtan1 : brettelProtan2;
    else if (d==1) matrix = -p.r*T(.00281)-p.g*T(.00611)+p.b*T(.00892)>=0 ? brettelDeutan1 : brettelDeutan2;
    else matrix = p.r*T(.03901)-p.g*T(.02788)-p.b*T(.01113)>=0 ? brettelTritan1 : brettelTritan2;
    return apply(precision<T>(matrix),p);
}
enum Mode { Brettel, Vienot, Prepared, LookupApply };
template<class T,Mode mode> __attribute__((noinline))
void batch(const std::vector<Rgb<T>>& in, std::vector<Rgb<T>>& out,
    const std::array<Matrix<T>,11>& table, Matrix<T> prepared, unsigned d) {
    for(size_t i=0;i<in.size();++i) {
        auto p=in[i];
        if constexpr(mode==Brettel) out[i]=brettel(p,d);
        else if constexpr(mode==Vienot) out[i]=apply(precision<T>(d==1 ? vienotDeutan : vienotProtan),p);
        else if constexpr(mode==Prepared) out[i]=apply(prepared,p);
        else out[i]=apply(at(table,T(i%1001)/T(1000)),p);
    }
}
template<class T> __attribute__((noinline))
void lookup(std::vector<Matrix<T>>& out,const std::array<Matrix<T>,11>& table,unsigned shift) {
    for(size_t i=0;i<out.size();++i) out[i]=at(table,T((i+shift)%1001)/T(1000));
}
template<class T> auto makeTable(unsigned d) {
    std::array<Matrix<T>,11> table;
    auto source=d==0 ? protanTable : d==1 ? deutanTable : tritanTable;
    for(size_t i=0;i<11;++i) table[i]=precision<T>(source[i]);
    return table;
}
template<class T> const char* scalar() { return sizeof(T)==4 ? "float" : "double"; }
template<class T,Mode mode> void runCase(size_t n,unsigned d,bool reverse) {
    std::vector<Rgb<T>> input(n),output(n);
    uint32_t state=0x12345678;
    for(auto& p:input) {
        state=state*1664525u+1013904223u;p.r=T((state>>8)&65535)/T(65535);
        state=state*1664525u+1013904223u;p.g=T((state>>8)&65535)/T(65535);
        state=state*1664525u+1013904223u;p.b=T((state>>8)&65535)/T(65535);
    }
    auto table=makeTable<T>(d); auto prepared=at(table,T(.65));
    for(int w=0;w<3;++w) batch<T,mode>(input,output,table,prepared,d);
    for(auto p:output) if(!std::isfinite(p.r)||!std::isfinite(p.g)||!std::isfinite(p.b)) std::abort();
    const char* labels[]={"brettel","vienot","prepared","lookupApply"};
    for(int round=0;round<9;++round) {
        double checksum=0;auto start=std::chrono::steady_clock::now();
        for(int repeat=0;repeat<16;++repeat) {
            input[0].r=T(repeat+round)/T(32);
            batch<T,mode>(input,output,table,prepared,d);
            auto p=output[(repeat*997+round*37)%n];checksum+=double(p.r)+double(p.g)+double(p.b);
        }
        double ns=std::chrono::duration<double,std::nano>(std::chrono::steady_clock::now()-start).count()/(n*16);
        std::printf("sample,CPP,%s,%s,%u,%zu,%s,%d,%.9f,%.17g\n",scalar<T>(),labels[mode],d,n,reverse?"true":"false",round,ns,checksum);
    }
}
template<class T> void runLookup(size_t n,unsigned d,bool reverse) {
    std::vector<Matrix<T>> output(n);auto table=makeTable<T>(d);
    for(int w=0;w<3;++w) lookup(output,table,0);
    for(int round=0;round<9;++round) {
        double checksum=0;auto start=std::chrono::steady_clock::now();
        for(int repeat=0;repeat<16;++repeat) {
            lookup(output,table,repeat+round);
            auto p=output[(repeat*997+round*37)%n];checksum+=double(p.m00)+double(p.m11)+double(p.m22);
        }
        double ns=std::chrono::duration<double,std::nano>(std::chrono::steady_clock::now()-start).count()/(n*16);
        std::printf("sample,CPP,%s,lookup,%u,%zu,%s,%d,%.9f,%.17g\n",scalar<T>(),d,n,reverse?"true":"false",round,ns,checksum);
    }
}
template<class T> void cases(size_t n,bool reverse) {
    for(unsigned index=0;index<3;++index) {
        unsigned d=reverse?2-index:index;
        if(reverse) {runLookup<T>(n,d,reverse);runCase<T,LookupApply>(n,d,reverse);runCase<T,Prepared>(n,d,reverse);}
        runCase<T,Brettel>(n,d,reverse);
        if(d<2) runCase<T,Vienot>(n,d,reverse);
        if(!reverse) {runCase<T,Prepared>(n,d,reverse);runCase<T,LookupApply>(n,d,reverse);runLookup<T>(n,d,reverse);}
    }
}
int main(int argc,char** argv) {
    size_t n=argc>1?std::strtoull(argv[1],nullptr,10):65536;bool reverse=argc>2;
    if(n<32||n>1048576) return 2;
    if(reverse) {cases<double>(n,reverse);cases<float>(n,reverse);}
    else {cases<float>(n,reverse);cases<double>(n,reverse);}
}
