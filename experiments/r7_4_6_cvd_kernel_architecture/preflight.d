module preflight;

import kernels;
import std.stdio : writeln;

void main()
{
    validateKernels!float();
    validateKernels!double();

    writeln(
        "R7.4.6 CVD kernel architecture preflight: PASS"
    );
}
