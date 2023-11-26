#include "bitmap.h"

#include "debug.h"
#include "interrupt.h"
#include "print.h"
#include "stdint.h"
#include "string.h"

// 将位图初始化
void bitmap_init(struct bitmap* btmp) { memset(btmp->bits, 0, btmp->btmp_bytes_len); }

// 判断bit_idx位是否为1,若为1,则返回true, 否则返回false
bool bitmap_scan_test(struct bitmap* btmp, uint32_t bit_idx) {
    uint32_t byte_idx = bit_idx / 8;                           // 这里是求所在位所处的字节偏移
    uint32_t bit_odd = bit_idx % 8;                            // 这里是求在字节中的位偏移
    return (btmp->bits[byte_idx] & (BITMAP_MASK << bit_odd));  // 与1进行与操作, 查看是否为1
}
// 在位图中申请连续cnt个位, 成功返回其起始位下标, 失败返回-1
int bitmap_scan(struct bitmap* btmp, uint32_t cnt) {
    uint32_t idx_byte = 0;  // 记录空闲位所在的字节
    // 逐字节比较
    while ((0xff == btmp->bits[idx_byte]) && (idx_byte < btmp->btmp_bytes_len)) {
        // 1表示已经分配, 若为0xff, 则说明该字节内已经无空闲位, 向下一字节继续找
        idx_byte++;
    }
    ASSERT(idx_byte < btmp->btmp_bytes_len);
    if (idx_byte == btmp->btmp_bytes_len) {  // 若内存池找不到可用空间
        return -1;
    }

    // 这里若找到了空闲位, 则在该字节内逐位比对, 返回空闲位的索引
    int idx_bit = 0;
    while ((uint8_t)(BITMAP_MASK << idx_bit) & btmp->bits[idx_byte]) {
        idx_bit++;
    }

    int bit_idx_start = idx_byte * 8 + idx_bit;  // 空闲位在位图中的坐标
    if (cnt == 1) {
        return bit_idx_start;
    }

    uint32_t bit_left = (btmp->btmp_bytes_len * 8 - bit_idx_start);
    uint32_t next_bit = bit_idx_start + 1;
    uint32_t count = 1;  // 用来记录找到空闲位的个数

    bit_idx_start = -1;  // 先将其置-1, 若找不到连续的位就直接返回
    while (bit_left-- > 0) {
        if (!(bitmap_scan_test(btmp, next_bit))) {
            count++;
        } else {
            count = 0;
        }
        if (count == cnt) {
            bit_idx_start = next_bit - cnt + 1;
            break;
        }
        next_bit++;
    }
    return bit_idx_start;
}

// 将位图btmp的bit_idx位设置为value
void bitmap_set(struct bitmap* btmp, uint32_t bit_idx, int8_t value) {
    ASSERT((value == 0) || (value == 1));
    uint32_t byte_idx = bit_idx / 8;
    uint32_t bit_odd = bit_idx % 8;
    if (value) {
        btmp->bits[byte_idx] |= (BITMAP_MASK << bit_odd);
    } else {
        btmp->bits[byte_idx] &= ~(BITMAP_MASK << bit_odd);
    }
}
