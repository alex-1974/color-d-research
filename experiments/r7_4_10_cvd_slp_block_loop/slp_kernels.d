module slp_kernels;

import color.rgb :
    LinearSRgb;


struct Matrix3(T)
{
    T m00; T m01; T m02;
    T m10; T m11; T m12;
    T m20; T m21; T m22;
}


private enum Matrix3!double vienotProtan =
    Matrix3!double(
        0.11238,  0.88762, 0.0,
        0.11238,  0.88762, 0.0,
        0.00401, -0.00401, 1.0
    );


private enum Matrix3!double vienotDeutan =
    Matrix3!double(
         0.29275, 0.70725, 0.0,
         0.29275, 0.70725, 0.0,
        -0.02234, 0.02234, 1.0
    );


Matrix3!T prepareVienotReplica(T)(
    uint deficiency
)
@safe pure nothrow @nogc
{
    assert(deficiency < 2);

    const source =
        deficiency == 0
            ? vienotProtan
            : vienotDeutan;

    return Matrix3!T(
        cast(T)source.m00,
        cast(T)source.m01,
        cast(T)source.m02,
        cast(T)source.m10,
        cast(T)source.m11,
        cast(T)source.m12,
        cast(T)source.m20,
        cast(T)source.m21,
        cast(T)source.m22
    );
}


pragma(inline, true)
private void writeMatrix(T)(
    ref LinearSRgb!T output,
    const ref Matrix3!T matrix,
    LinearSRgb!T color
)
@safe pure nothrow @nogc
{
    output.r =
        matrix.m00 * color.r +
        matrix.m01 * color.g +
        matrix.m02 * color.b;

    output.g =
        matrix.m10 * color.r +
        matrix.m11 * color.g +
        matrix.m12 * color.b;

    output.b =
        matrix.m20 * color.r +
        matrix.m21 * color.g +
        matrix.m22 * color.b;
}


void scalarReplica(T)(
    Matrix3!T matrix,
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);

    foreach (i, ref color; input)
    {
        writeMatrix(
            output[i],
            matrix,
            color
        );
    }
}


void unroll2(T)(
    Matrix3!T matrix,
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);

    size_t i;

    for (
        ;
        i + 2 <= input.length;
        i += 2
    )
    {
        const c0 = input[i];
        const c1 = input[i + 1];

        writeMatrix(
            output[i],
            matrix,
            c0
        );

        writeMatrix(
            output[i + 1],
            matrix,
            c1
        );
    }

    for (; i < input.length; ++i)
    {
        writeMatrix(
            output[i],
            matrix,
            input[i]
        );
    }
}


void unroll4(T)(
    Matrix3!T matrix,
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);

    size_t i;

    for (
        ;
        i + 4 <= input.length;
        i += 4
    )
    {
        const c0 = input[i];
        const c1 = input[i + 1];
        const c2 = input[i + 2];
        const c3 = input[i + 3];

        writeMatrix(
            output[i],
            matrix,
            c0
        );

        writeMatrix(
            output[i + 1],
            matrix,
            c1
        );

        writeMatrix(
            output[i + 2],
            matrix,
            c2
        );

        writeMatrix(
            output[i + 3],
            matrix,
            c3
        );
    }

    for (; i < input.length; ++i)
    {
        writeMatrix(
            output[i],
            matrix,
            input[i]
        );
    }
}


void unroll4Coefficients(T)(
    Matrix3!T matrix,
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);

    const T m00 = matrix.m00;
    const T m01 = matrix.m01;
    const T m02 = matrix.m02;
    const T m10 = matrix.m10;
    const T m11 = matrix.m11;
    const T m12 = matrix.m12;
    const T m20 = matrix.m20;
    const T m21 = matrix.m21;
    const T m22 = matrix.m22;

    size_t i;

    for (
        ;
        i + 4 <= input.length;
        i += 4
    )
    {
        const c0 = input[i];
        const c1 = input[i + 1];
        const c2 = input[i + 2];
        const c3 = input[i + 3];

        output[i].r =
            m00 * c0.r +
            m01 * c0.g +
            m02 * c0.b;
        output[i].g =
            m10 * c0.r +
            m11 * c0.g +
            m12 * c0.b;
        output[i].b =
            m20 * c0.r +
            m21 * c0.g +
            m22 * c0.b;

        output[i + 1].r =
            m00 * c1.r +
            m01 * c1.g +
            m02 * c1.b;
        output[i + 1].g =
            m10 * c1.r +
            m11 * c1.g +
            m12 * c1.b;
        output[i + 1].b =
            m20 * c1.r +
            m21 * c1.g +
            m22 * c1.b;

        output[i + 2].r =
            m00 * c2.r +
            m01 * c2.g +
            m02 * c2.b;
        output[i + 2].g =
            m10 * c2.r +
            m11 * c2.g +
            m12 * c2.b;
        output[i + 2].b =
            m20 * c2.r +
            m21 * c2.g +
            m22 * c2.b;

        output[i + 3].r =
            m00 * c3.r +
            m01 * c3.g +
            m02 * c3.b;
        output[i + 3].g =
            m10 * c3.r +
            m11 * c3.g +
            m12 * c3.b;
        output[i + 3].b =
            m20 * c3.r +
            m21 * c3.g +
            m22 * c3.b;
    }

    for (; i < input.length; ++i)
    {
        const color = input[i];

        output[i].r =
            m00 * color.r +
            m01 * color.g +
            m02 * color.b;

        output[i].g =
            m10 * color.r +
            m11 * color.g +
            m12 * color.b;

        output[i].b =
            m20 * color.r +
            m21 * color.g +
            m22 * color.b;
    }
}
