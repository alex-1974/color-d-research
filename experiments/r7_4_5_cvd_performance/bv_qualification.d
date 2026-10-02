module bv_qualification;

import bv;
import candidates;
import bv_policy;
import std.stdio : writefln;

// Comparisons use the existing preliminary component envelope. This is source
// equivalence qualification, not an independent model-accuracy oracle.
bool colorsMatch(T)(bv.Rgb!T a, bv.Rgb!T b)
@safe pure nothrow @nogc
{
    return componentMatches(a.r,b.r) && componentMatches(a.g,b.g)
        && componentMatches(a.b,b.b);
}

bool qualifyInput(T)(bv.Rgb!T input)
@safe pure nothrow @nogc
{
    const bv.Rgb!T[1] source = [input];
    bv.Rgb!T[1] policyOutput, inPlaceOutput;
    foreach (deficiency; 0u .. 3u)
    {
        const plan = prepareBrettel!T(deficiency);
        const expected = bv.brettelProbe(input,deficiency);
        policyBrettelBatch!T(source[],policyOutput[],deficiency);
        inPlaceOutput[0] = input;
        policyBrettelBatch!T(inPlaceOutput[],inPlaceOutput[],deficiency);
        if (!colorsMatch!T(policyOutput[0],expected)
            || !colorsMatch!T(inPlaceOutput[0],expected)) return false;
        bv.Rgb!T split, direct;
        directBrettel!(T,true)(split,plan,input.r,input.g,input.b);
        directBrettel!(T,false)(direct,plan,input.r,input.g,input.b);
        auto inPlace = input;
        directBrettel!(T,true)(inPlace,plan,inPlace.r,inPlace.g,inPlace.b);
        if (!colorsMatch!T(split,expected) || !colorsMatch!T(direct,expected)
            || !colorsMatch!T(inPlace,expected)) return false;
        if (deficiency < 2)
        {
            const matrix = prepareVienot!T(deficiency);
            const vienotExpected = bv.vienotProbe(input,deficiency == 1);
            static foreach (policy; [BvPolicy.portable,BvPolicy.compilerSelected])
            {{
                policyVienotBatch!(T,policy)(source[],policyOutput[],deficiency);
                inPlaceOutput[0] = input;
                policyVienotBatch!(T,policy)(inPlaceOutput[],inPlaceOutput[],deficiency);
                if (!colorsMatch!T(policyOutput[0],vienotExpected)
                    || !colorsMatch!T(inPlaceOutput[0],vienotExpected)) return false;
            }}
            static foreach (shape; [0,1,2])
            {{
                static if (shape == 1) staticVienotBatch!T(source[],policyOutput[],deficiency);
                else static if (shape == 2) referenceVienotBatch!T(source[],policyOutput[],deficiency);
                else indexedVienotBatch!T(source[],policyOutput[],deficiency);
                inPlaceOutput[0] = input;
                static if (shape == 1) staticVienotBatch!T(inPlaceOutput[],inPlaceOutput[],deficiency);
                else static if (shape == 2) referenceVienotBatch!T(inPlaceOutput[],inPlaceOutput[],deficiency);
                else indexedVienotBatch!T(inPlaceOutput[],inPlaceOutput[],deficiency);
                if (!colorsMatch!T(policyOutput[0],vienotExpected)
                    || !colorsMatch!T(inPlaceOutput[0],vienotExpected)) return false;
            }}
            directWrite!T(direct,matrix,input.r,input.g,input.b);
            inPlace = input;
            directWrite!T(inPlace,matrix,inPlace.r,inPlace.g,inPlace.b);
            if (!colorsMatch!T(direct,vienotExpected)
                || !colorsMatch!T(inPlace,vienotExpected)) return false;
        }
    }
    return true;
}

// Distinct synthetic matrices make equality selection observable.
// Published matrices meet on their separation plane.
bool qualifySelection(T)()
@safe pure nothrow @nogc
{
    auto plan = prepareBrettel!T(0);
    plan.nr=1; plan.ng=0; plan.nb=0;
    plan.first.m11=2; plan.second.m11=3;
    bv.Rgb!T result;
    directBrettel!(T,true)(result,plan,T(0),T(1),T(0));
    if (result.g != T(2)) return false;
    directBrettel!(T,true)(result,plan,-T(0),T(1),T(0));
    if (result.g != T(2)) return false;
    directBrettel!(T,true)(result,plan,T(-1),T(1),T(0));
    if (!colorsMatch!T(result,plan.second.apply(bv.Rgb!T(-1,1,0)))) return false;
    directBrettel!(T,true)(result,plan,T(1),T(1),T(0));
    if (!colorsMatch!T(result,plan.first.apply(bv.Rgb!T(1,1,0)))) return false;
    directBrettel!(T,true)(result,plan,T.nan,T(1),T(0));
    if (!colorsMatch!T(result,plan.second.apply(bv.Rgb!T(T.nan,1,0)))) return false;
    return true;
}


bool qualifyVienotBatches(T)()
@safe pure nothrow @nogc
{
    bv.Rgb!T[65] source, output, inPlace;
    foreach (i, ref p; source)
        p = bv.Rgb!T(T(i)/T(32)-T(1),T(i%7)/T(3),T(i%11)/T(5)-T(1));
    foreach (n; [0,1,2,3,7,8,9,31,32,33,65])
    foreach (deficiency; 0u .. 2u)
    static foreach (shape; [0,1,2])
    {{
        inPlace[] = source[];
        static if (shape == 1)
        {
            staticVienotBatch!T(source[0..n],output[0..n],deficiency);
            staticVienotBatch!T(inPlace[0..n],inPlace[0..n],deficiency);
        }
        else static if (shape == 2)
        {
            referenceVienotBatch!T(source[0..n],output[0..n],deficiency);
            referenceVienotBatch!T(inPlace[0..n],inPlace[0..n],deficiency);
        }
        else
        {
            indexedVienotBatch!T(source[0..n],output[0..n],deficiency);
            indexedVienotBatch!T(inPlace[0..n],inPlace[0..n],deficiency);
        }
        foreach (i; 0 .. n)
        {
            const expected = bv.vienotProbe(source[i],deficiency == 1);
            if (!colorsMatch!T(output[i],expected) || !colorsMatch!T(inPlace[i],expected))
                return false;
        }
        foreach (i; n .. source.length)
            if (!colorsMatch!T(inPlace[i],source[i])) return false;
    }}
    return true;
}

bool qualifyCtfe(T)()
@safe pure nothrow @nogc
{
    if (!qualifySelection!T() || !qualifyVienotBatches!T()) return false;
    const bv.Rgb!T[5] inputs=[bv.Rgb!T(1,0,0),bv.Rgb!T(-1,0,0),bv.Rgb!T(0,0,0),
                 bv.Rgb!T(-2,2,1),bv.Rgb!T(T.nan,1,0)];
    foreach (p; inputs)
        if (!qualifyInput!T(p)) return false;
    return true;
}

static assert(qualifyCtfe!float());
static assert(qualifyCtfe!double());

bool qualifyRuntime(T)(out size_t inputs)
@safe pure nothrow @nogc
{
    inputs = 0;
    if (!qualifySelection!T() || !qualifyVienotBatches!T()) return false;
    uint state=0x7a31b49c;
    foreach (i; 0 .. 4096)
    {
        bv.Rgb!T p;
        state=state*1664525u+1013904223u; p.r=T((state>>8)&65535)/T(16384)-T(2);
        state=state*1664525u+1013904223u; p.g=T((state>>8)&65535)/T(16384)-T(2);
        state=state*1664525u+1013904223u; p.b=T((state>>8)&65535)/T(16384)-T(2);
        if (!qualifyInput!T(p)) return false;
        ++inputs;
    }
    const T[12] values=[T(-2),-T(0),T(0),T(1),T(2),T.min_normal,
        -T.min_normal,T.min_normal/T(16),-T.min_normal/T(16),
        T.nan,T.infinity,-T.infinity];
    foreach (r; values) foreach (g; values) foreach (b; values)
    {
        if (!qualifyInput!T(bv.Rgb!T(r,g,b))) return false;
        ++inputs;
    }
    foreach (deficiency; 0u .. 3u)
    {
        const plan=prepareBrettel!T(deficiency);
        const T r=T(0.2),g=T(0.4),b=-(r*plan.nr+g*plan.ng)/plan.nb;
        const T[5] offsets=[T(-1e-5),T(-1e-6),T(0),T(1e-6),T(1e-5)];
        foreach (offset; offsets)
        {
            if (!qualifyInput!T(bv.Rgb!T(r,g,b+offset))) return false;
            ++inputs;
        }
    }
    return true;
}

void main()
{
    writefln("policy,portable,double-vienot=original,compilerSelected,double-vienot=%s",
        preferDirectDoubleVienot ? "direct" : "original");
    size_t inputs;
    if (!qualifyRuntime!float(inputs)) throw new Exception("combined BV float qualification failed");
    writefln("qualification,float,inputs=%s,extended/IEEE/selection/in-place/CTFE/attributes=PASS",inputs);
    if (!qualifyRuntime!double(inputs)) throw new Exception("combined BV double qualification failed");
    writefln("qualification,double,inputs=%s,extended/IEEE/selection/in-place/CTFE/attributes=PASS",inputs);
    writefln("vienot,indexed/static,empty/tails/batch-in-place/CTFE/attributes=PASS");
    writefln("vienot,reference,empty/tails/batch-in-place/CTFE/attributes=PASS");
}
