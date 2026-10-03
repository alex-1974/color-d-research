module simd_kernels;

import kernels :
    Matrix3,
    Rgb;

version (D_SIMD)
{
    import core.simd :
        XMM,
        __simd,
        float4,
        double2,
        loadUnaligned;
}


pragma(inline, true)
private void scalarWrite(T)(
    ref Rgb!T output,
    const ref Matrix3!T matrix,
    T r,
    T g,
    T b
)
@safe pure nothrow @nogc
{
    output.r =
        matrix.m00 * r +
        matrix.m01 * g +
        matrix.m02 * b;

    output.g =
        matrix.m10 * r +
        matrix.m11 * g +
        matrix.m12 * b;

    output.b =
        matrix.m20 * r +
        matrix.m21 * g +
        matrix.m22 * b;
}


version (D_SIMD)
{
    pragma(inline, true)
    private float4 shufps(ubyte imm)(
        float4 lhs,
        float4 rhs
    )
    @safe pure nothrow @nogc
    {
        return cast(float4)__simd(
            XMM.SHUFPS,
            lhs,
            rhs,
            imm
        );
    }


    pragma(inline, true)
    private float4 unpcklps(
        float4 lhs,
        float4 rhs
    )
    @safe pure nothrow @nogc
    {
        return cast(float4)__simd(
            XMM.UNPCKLPS,
            lhs,
            rhs
        );
    }


    pragma(inline, true)
    private float4 unpckhps(
        float4 lhs,
        float4 rhs
    )
    @safe pure nothrow @nogc
    {
        return cast(float4)__simd(
            XMM.UNPCKHPS,
            lhs,
            rhs
        );
    }


    pragma(inline, true)
    private double2 shufpd(ubyte imm)(
        double2 lhs,
        double2 rhs
    )
    @safe pure nothrow @nogc
    {
        return cast(double2)__simd(
            XMM.SHUFPD,
            lhs,
            rhs,
            imm
        );
    }


    /*
     * The public research kernels remain @safe. Pointer reinterpretation is
     * isolated here and only spans the already bounds-qualified RGB block.
     *
     * Rgb!float is three contiguous floats and Rgb!double three contiguous
     * doubles in this research model. The static asserts make that assumption
     * explicit before any vector load/store is compiled.
     */
    static assert(Rgb!float.sizeof == 3 * float.sizeof);
    static assert(Rgb!double.sizeof == 3 * double.sizeof);


    pragma(inline, true)
    private float4 loadFloatBlock(
        const Rgb!float[] input,
        size_t colorIndex,
        size_t vectorIndex
    )
    @trusted pure nothrow @nogc
    {
        const float* base =
            cast(const float*)input.ptr;

        const size_t scalarOffset =
            colorIndex * 3 +
            vectorIndex * 4;

        return loadUnaligned(
            cast(const float4*)(
                base + scalarOffset
            )
        );
    }


    pragma(inline, true)
    private double2 loadDoubleBlock(
        const Rgb!double[] input,
        size_t colorIndex,
        size_t vectorIndex
    )
    @trusted pure nothrow @nogc
    {
        const double* base =
            cast(const double*)input.ptr;

        const size_t scalarOffset =
            colorIndex * 3 +
            vectorIndex * 2;

        return loadUnaligned(
            cast(const double2*)(
                base + scalarOffset
            )
        );
    }


    /*
     * Store through a scalar static-array view rather than core.simd's
     * storeUnaligned intrinsic, whose current druntime declaration is not pure.
     * This keeps the research kernel eligible for the production purity
     * contract while retaining an unaligned scalar-aligned destination type.
     * Generated code is captured to verify whether each compiler lowers this
     * to vector or scalar stores.
     */
    pragma(inline, true)
    private void storeFloatBlock(
        Rgb!float[] output,
        size_t colorIndex,
        size_t vectorIndex,
        float4 value
    )
    @trusted pure nothrow @nogc
    {
        float* base =
            cast(float*)output.ptr;

        const size_t scalarOffset =
            colorIndex * 3 +
            vectorIndex * 4;

        *cast(float[4]*)(
            base + scalarOffset
        ) = value.array;
    }


    pragma(inline, true)
    private void storeDoubleBlock(
        Rgb!double[] output,
        size_t colorIndex,
        size_t vectorIndex,
        double2 value
    )
    @trusted pure nothrow @nogc
    {
        double* base =
            cast(double*)output.ptr;

        const size_t scalarOffset =
            colorIndex * 3 +
            vectorIndex * 2;

        *cast(double[2]*)(
            base + scalarOffset
        ) = value.array;
    }


    pragma(inline, true)
    private void deinterleaveFloat4(
        float4 a,
        float4 b,
        float4 c,
        out float4 r,
        out float4 g,
        out float4 blue
    )
    @safe pure nothrow @nogc
    {
        const rBridge =
            shufps!0x18(b, c);

        r =
            shufps!0x9C(a, rBridge);

        const gLow =
            unpcklps(a, b);

        const gHigh =
            unpckhps(b, c);

        g =
            shufps!0x66(
                gLow,
                gHigh
            );

        const bBridge =
            shufps!0x12(a, b);

        blue =
            shufps!0xC8(
                bBridge,
                c
            );
    }


    pragma(inline, true)
    private void reinterleaveFloat4(
        float4 r,
        float4 g,
        float4 blue,
        out float4 a,
        out float4 b,
        out float4 c
    )
    @safe pure nothrow @nogc
    {
        const aRG =
            unpcklps(r, g);

        const aBR =
            unpcklps(blue, r);

        a =
            shufps!0xC4(
                aRG,
                aBR
            );

        const bGB =
            unpcklps(g, blue);

        const bRG =
            unpckhps(r, g);

        b =
            shufps!0x4E(
                bGB,
                bRG
            );

        const cBR =
            unpckhps(blue, r);

        const cGB =
            unpckhps(g, blue);

        c =
            shufps!0xEC(
                cBR,
                cGB
            );
    }


    pragma(inline, true)
    private void deinterleaveDouble2(
        double2 a,
        double2 b,
        double2 c,
        out double2 r,
        out double2 g,
        out double2 blue
    )
    @safe pure nothrow @nogc
    {
        r = shufpd!0x2(a, b);
        g = shufpd!0x1(a, c);
        blue = shufpd!0x2(b, c);
    }


    pragma(inline, true)
    private void reinterleaveDouble2(
        double2 r,
        double2 g,
        double2 blue,
        out double2 a,
        out double2 b,
        out double2 c
    )
    @safe pure nothrow @nogc
    {
        a = shufpd!0x0(r, g);
        b = shufpd!0x2(blue, r);
        c = shufpd!0x3(g, blue);
    }


    void gatherSimdMatrixBatch(
        const Rgb!float[] input,
        Rgb!float[] output,
        const ref Matrix3!float matrix
    )
    @safe pure nothrow @nogc
    {
        assert(input.length == output.length);

        size_t i;

        const float4 m00 = matrix.m00;
        const float4 m01 = matrix.m01;
        const float4 m02 = matrix.m02;
        const float4 m10 = matrix.m10;
        const float4 m11 = matrix.m11;
        const float4 m12 = matrix.m12;
        const float4 m20 = matrix.m20;
        const float4 m21 = matrix.m21;
        const float4 m22 = matrix.m22;

        for (
            ;
            i + 4 <= input.length;
            i += 4
        )
        {
            const float4 r =
            [
                input[i].r,
                input[i + 1].r,
                input[i + 2].r,
                input[i + 3].r
            ];

            const float4 g =
            [
                input[i].g,
                input[i + 1].g,
                input[i + 2].g,
                input[i + 3].g
            ];

            const float4 b =
            [
                input[i].b,
                input[i + 1].b,
                input[i + 2].b,
                input[i + 3].b
            ];

            const float4 outR =
                m00 * r +
                m01 * g +
                m02 * b;

            const float4 outG =
                m10 * r +
                m11 * g +
                m12 * b;

            const float4 outB =
                m20 * r +
                m21 * g +
                m22 * b;

            const rr = outR.array;
            const gg = outG.array;
            const bb = outB.array;

            foreach (lane; 0 .. 4)
            {
                output[i + lane] =
                    Rgb!float(
                        rr[lane],
                        gg[lane],
                        bb[lane]
                    );
            }
        }

        for (; i < input.length; ++i)
        {
            const color = input[i];

            scalarWrite(
                output[i],
                matrix,
                color.r,
                color.g,
                color.b
            );
        }
    }


    void blockSimdMatrixBatch(
        const Rgb!float[] input,
        Rgb!float[] output,
        const ref Matrix3!float matrix
    )
    @safe pure nothrow @nogc
    {
        assert(input.length == output.length);

        size_t i;

        const float4 m00 = matrix.m00;
        const float4 m01 = matrix.m01;
        const float4 m02 = matrix.m02;
        const float4 m10 = matrix.m10;
        const float4 m11 = matrix.m11;
        const float4 m12 = matrix.m12;
        const float4 m20 = matrix.m20;
        const float4 m21 = matrix.m21;
        const float4 m22 = matrix.m22;

        for (
            ;
            i + 4 <= input.length;
            i += 4
        )
        {
            const a =
                loadFloatBlock(
                    input,
                    i,
                    0
                );

            const b =
                loadFloatBlock(
                    input,
                    i,
                    1
                );

            const c =
                loadFloatBlock(
                    input,
                    i,
                    2
                );

            float4 r;
            float4 g;
            float4 blue;

            deinterleaveFloat4(
                a,
                b,
                c,
                r,
                g,
                blue
            );

            const float4 outR =
                m00 * r +
                m01 * g +
                m02 * blue;

            const float4 outG =
                m10 * r +
                m11 * g +
                m12 * blue;

            const float4 outB =
                m20 * r +
                m21 * g +
                m22 * blue;

            float4 outA;
            float4 outBlockB;
            float4 outC;

            reinterleaveFloat4(
                outR,
                outG,
                outB,
                outA,
                outBlockB,
                outC
            );

            storeFloatBlock(
                output,
                i,
                0,
                outA
            );

            storeFloatBlock(
                output,
                i,
                1,
                outBlockB
            );

            storeFloatBlock(
                output,
                i,
                2,
                outC
            );
        }

        for (; i < input.length; ++i)
        {
            const color = input[i];

            scalarWrite(
                output[i],
                matrix,
                color.r,
                color.g,
                color.b
            );
        }
    }


    void gatherSimdMatrixBatch(
        const Rgb!double[] input,
        Rgb!double[] output,
        const ref Matrix3!double matrix
    )
    @safe pure nothrow @nogc
    {
        assert(input.length == output.length);

        size_t i;

        const double2 m00 = matrix.m00;
        const double2 m01 = matrix.m01;
        const double2 m02 = matrix.m02;
        const double2 m10 = matrix.m10;
        const double2 m11 = matrix.m11;
        const double2 m12 = matrix.m12;
        const double2 m20 = matrix.m20;
        const double2 m21 = matrix.m21;
        const double2 m22 = matrix.m22;

        for (
            ;
            i + 2 <= input.length;
            i += 2
        )
        {
            const double2 r =
            [
                input[i].r,
                input[i + 1].r
            ];

            const double2 g =
            [
                input[i].g,
                input[i + 1].g
            ];

            const double2 b =
            [
                input[i].b,
                input[i + 1].b
            ];

            const double2 outR =
                m00 * r +
                m01 * g +
                m02 * b;

            const double2 outG =
                m10 * r +
                m11 * g +
                m12 * b;

            const double2 outB =
                m20 * r +
                m21 * g +
                m22 * b;

            const rr = outR.array;
            const gg = outG.array;
            const bb = outB.array;

            foreach (lane; 0 .. 2)
            {
                output[i + lane] =
                    Rgb!double(
                        rr[lane],
                        gg[lane],
                        bb[lane]
                    );
            }
        }

        for (; i < input.length; ++i)
        {
            const color = input[i];

            scalarWrite(
                output[i],
                matrix,
                color.r,
                color.g,
                color.b
            );
        }
    }


    void blockSimdMatrixBatch(
        const Rgb!double[] input,
        Rgb!double[] output,
        const ref Matrix3!double matrix
    )
    @safe pure nothrow @nogc
    {
        assert(input.length == output.length);

        size_t i;

        const double2 m00 = matrix.m00;
        const double2 m01 = matrix.m01;
        const double2 m02 = matrix.m02;
        const double2 m10 = matrix.m10;
        const double2 m11 = matrix.m11;
        const double2 m12 = matrix.m12;
        const double2 m20 = matrix.m20;
        const double2 m21 = matrix.m21;
        const double2 m22 = matrix.m22;

        for (
            ;
            i + 2 <= input.length;
            i += 2
        )
        {
            const a =
                loadDoubleBlock(
                    input,
                    i,
                    0
                );

            const b =
                loadDoubleBlock(
                    input,
                    i,
                    1
                );

            const c =
                loadDoubleBlock(
                    input,
                    i,
                    2
                );

            double2 r;
            double2 g;
            double2 blue;

            deinterleaveDouble2(
                a,
                b,
                c,
                r,
                g,
                blue
            );

            const double2 outR =
                m00 * r +
                m01 * g +
                m02 * blue;

            const double2 outG =
                m10 * r +
                m11 * g +
                m12 * blue;

            const double2 outB =
                m20 * r +
                m21 * g +
                m22 * blue;

            double2 outA;
            double2 outBlockB;
            double2 outC;

            reinterleaveDouble2(
                outR,
                outG,
                outB,
                outA,
                outBlockB,
                outC
            );

            storeDoubleBlock(
                output,
                i,
                0,
                outA
            );

            storeDoubleBlock(
                output,
                i,
                1,
                outBlockB
            );

            storeDoubleBlock(
                output,
                i,
                2,
                outC
            );
        }

        for (; i < input.length; ++i)
        {
            const color = input[i];

            scalarWrite(
                output[i],
                matrix,
                color.r,
                color.g,
                color.b
            );
        }
    }
}
