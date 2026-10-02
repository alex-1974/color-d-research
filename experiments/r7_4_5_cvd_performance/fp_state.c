#include <stdint.h>
#include <xmmintrin.h>

uint32_t colorDReadMxcsr(void) {
    return _mm_getcsr();
}

uint16_t colorDReadX87Control(void) {
    uint16_t control;
    __asm__ volatile ("fnstcw %0" : "=m"(control));
    return control;
}
