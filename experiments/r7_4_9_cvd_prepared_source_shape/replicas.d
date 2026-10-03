module replicas;

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


Matrix3!T prepareReplicaVienot(T)(
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


void freeRefLoop(T)(
    const ref Matrix3!T matrix,
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);

    foreach (i, ref color; input)
    {
        const T r = color.r;
        const T g = color.g;
        const T b = color.b;

        writeMatrix(
            output[i],
            matrix,
            r,
            g,
            b
        );
    }
}


void freeValueLoop(T)(
    Matrix3!T matrix,
    const(LinearSRgb!T)[] input,
    LinearSRgb!T[] output
)
@safe pure nothrow @nogc
{
    assert(input.length == output.length);

    foreach (i, ref color; input)
    {
        const T r = color.r;
        const T g = color.g;
        const T b = color.b;

        writeMatrix(
            output[i],
            matrix,
            r,
            g,
            b
        );
    }
}


void freeCoefficientsLoop(T)(
    const ref Matrix3!T matrix,
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

    foreach (i, ref color; input)
    {
        const T r = color.r;
        const T g = color.g;
        const T b = color.b;

        output[i].r =
            m00 * r +
            m01 * g +
            m02 * b;

        output[i].g =
            m10 * r +
            m11 * g +
            m12 * b;

        output[i].b =
            m20 * r +
            m21 * g +
            m22 * b;
    }
}


struct ReplicaPrepared(T)
{
    Matrix3!T matrix;

    bool memberSnapshot(
        const(LinearSRgb!T)[] input,
        LinearSRgb!T[] output
    ) const
    @safe pure nothrow @nogc
    {
        if (input.length != output.length)
            return false;

        const localMatrix = matrix;

        freeRefLoop(
            localMatrix,
            input,
            output
        );

        return true;
    }


    bool memberBacked(
        const(LinearSRgb!T)[] input,
        LinearSRgb!T[] output
    ) const
    @safe pure nothrow @nogc
    {
        if (input.length != output.length)
            return false;

        freeRefLoop(
            matrix,
            input,
            output
        );

        return true;
    }
}


ReplicaPrepared!T prepareReplica(T)(
    uint deficiency
)
@safe pure nothrow @nogc
{
    return ReplicaPrepared!T(
        prepareReplicaVienot!T(
            deficiency
        )
    );
}
