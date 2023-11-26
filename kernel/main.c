#include "debug.h"
#include "init.h"
#include "print.h"
int main(void) {
    init_all();
    ASSERT(1 == 2);
    while (1) {
    };
    return 0;
}