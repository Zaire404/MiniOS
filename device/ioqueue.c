#include "ioqueue.h"

#include "debug.h"
#include "global.h"
#include "interrupt.h"
#define NULL 0
// 初始化io队列ioq
void ioqueue_init(struct ioqueue* ioq) {
    lock_init(&ioq->lock);                 // 初始化io队列的锁
    ioq->producer = ioq->consumer = NULL;  // 生产者和消费者置空
    ioq->head = ioq->tail = 0;             // 队列的首尾指针指向缓冲区数组第0个位置
};

// 返回pos在缓冲区中的下一个位置值
static int32_t next_pos(int32_t pos) {
    return (pos + 1) % bufsize;  // 到达缓冲区数组末尾后返回数组第0个位置
}

// 判断队列是否已满
bool ioq_full(struct ioqueue* ioq) {
    ASSERT(intr_get_status() == INTR_OFF);
    return next_pos(ioq->head) == ioq->tail;
}

// 判断队列是否已空
bool ioq_empty(struct ioqueue* ioq) {
    ASSERT(intr_get_status() == INTR_OFF);
    return ioq->head == ioq->tail;
}

// 使当前生产者或消费者在此缓冲区上等待
static void ioq_wait(struct task_struct** waiter) {
    ASSERT(*waiter == NULL && waiter != NULL);
    *waiter = running_thread();
    thread_block(TASK_BLOCKED);
}

// 唤醒waiter
static void wakeup(struct task_struct** waiter) {
    ASSERT(*waiter != NULL);
    thread_unblock(*waiter);
    *waiter = NULL;
}

// 消费者从ioq队列中获取一个字符
char ioq_getchar(struct ioqueue* ioq) {
    ASSERT(intr_get_status() == INTR_OFF);

    // 若缓冲区(队列)为空,把消费者ioq->consumer记为当前线程自己,
    // 目的是当生产者想唤醒消费者时(生产者发现缓冲区没满),消费者能方便的被唤醒
    while (ioq_empty(ioq)) {
        lock_acquire(&ioq->lock);  // 获取锁
        ioq_wait(&ioq->consumer);  // 消费者进入睡眠
        lock_release(&ioq->lock);  // 释放锁
    }

    char byte = ioq->buf[ioq->tail];  // 从缓冲区中取出
    ioq->tail = next_pos(ioq->tail);  // 把读游标移到下一位置

    if (ioq->producer != NULL) {
        wakeup(&ioq->producer);  // 唤醒生产者
    }

    return byte;
}

// 生产者往ioq队列中写入一个字符byte
void ioq_putchar(struct ioqueue* ioq, char byte) {
    ASSERT(intr_get_status() == INTR_OFF);

    // 若缓冲区(队列)已经满了,把生产者ioq->producer记为自己,
    // 目的是当消费者想唤醒生产者时(消费者发现缓冲区没空),生产者能方便的被唤醒
    while (ioq_full(ioq)) {
        lock_acquire(&ioq->lock);  // 获取锁
        ioq_wait(&ioq->producer);  // 生产者进入睡眠
        lock_release(&ioq->lock);  // 释放锁
    }

    ioq->buf[ioq->head] = byte;  // 把字节放入缓冲区中
    ioq->head = next_pos(ioq->head);  // 把写游标移到下一位置

    if (ioq->consumer != NULL) {
        wakeup(&ioq->consumer);  // 唤醒消费者
    }
}