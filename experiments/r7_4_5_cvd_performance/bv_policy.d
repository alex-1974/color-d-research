module bv_policy;

import bv;
import candidates : prepareBrettel, prepareVienot, directBrettel, directWrite;

// Internal research choices; neither is a production API or an acceptance gate.
enum BvPolicy { portable, compilerSelected }

// Centralized candidate decision, measured on DMD 2.111/2.113 and LDC 1.41/1.43.
// Other compilers retain the portable original-double path. No version threshold
// or future-compiler performance promise follows from this experiment.
version (LDC) enum bool preferDirectDoubleVienot = false;
else version (DigitalMars) enum bool preferDirectDoubleVienot = true;
else enum bool preferDirectDoubleVienot = false;

enum bool usesDirectVienot(T, BvPolicy policy) = is(T == float)
    || (is(T == double) && policy == BvPolicy.compilerSelected && preferDirectDoubleVienot);

static assert(usesDirectVienot!(float,BvPolicy.portable));
static assert(usesDirectVienot!(float,BvPolicy.compilerSelected));
static assert(!usesDirectVienot!(double,BvPolicy.portable));
static assert(usesDirectVienot!(double,BvPolicy.compilerSelected) == preferDirectDoubleVienot);

pragma(inline, true)
void policyBrettelBatch(T)(const bv.Rgb!T[] input, bv.Rgb!T[] output, uint deficiency)
@safe pure nothrow @nogc
{
    static assert(is(T == float) || is(T == double));
    assert(input.length == output.length);
    const plan = prepareBrettel!T(deficiency);
    foreach (i,p; input)
        directBrettel!(T,true)(output[i],plan,p.r,p.g,p.b);
}

pragma(inline, true)
void policyVienotBatch(T, BvPolicy policy)(const bv.Rgb!T[] input,
    bv.Rgb!T[] output, uint deficiency)
@safe pure nothrow @nogc
{
    static assert(is(T == float) || is(T == double));
    assert(input.length == output.length);
    static if (usesDirectVienot!(T,policy))
    {
        const matrix = prepareVienot!T(deficiency);
        foreach (i,p; input)
            directWrite!T(output[i],matrix,p.r,p.g,p.b);
    }
    else
    {
        // Preserve the original source form, including its per-item coefficient
        // selection. Preparing once and returning a value is a different probe.
        foreach (i,p; input)
            output[i] = bv.vienotProbe(p,deficiency == 1);
    }
}
