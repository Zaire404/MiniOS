#include "print.h"
#include "init.h"
#include "debug.h"
int main(void) {
    init_all();   
    ASSERT(1 == 2);
    while(1);
    return 0;
}