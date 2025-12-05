#include "uart.h"
#include "platform.h"
#include <stdint.h>
#include <stdio.h>

int main()
{
    uint32_t hartid;
    asm volatile ("csrr %0, mhartid" : "=r"(hartid));
    if (hartid == 0)
    {
        init_uart(CORE_CLK,UART_BAUD);
    }

    // jump to the start address of the payload 
    switch (hartid)
    {
    case 0:  
        __asm__ volatile(
            "li s0, 0x80010000 ;"
            "jalr s0"
        );
        break;
    case 1:
        __asm__ volatile(
            "li s0, 0x81010000 ;"
            "jalr s0"
        );
        break;
    case 2:
        __asm__ volatile(
            "li s0, 0x82010000 ;"
            "jalr s0"
        );
        break;
    case 3:
        __asm__ volatile(
            "li s0, 0x83010000 ;"
            "jalr s0"
        );
        break;
    case 4:  
        __asm__ volatile(
            "li s0, 0x84010000 ;"
            "jalr s0"
        );
        break;
    case 5:
        __asm__ volatile(
            "li s0, 0x85010000 ;"
            "jalr s0"
        );
        break;
    case 6:
        __asm__ volatile(
            "li s0, 0x86010000 ;"
            "jalr s0"
        );
        break;
    case 7:
        __asm__ volatile(
            "li s0, 0x87010000 ;"
            "jalr s0"
        );
        break;
    case 8:  
        __asm__ volatile(
            "li s0, 0x88010000 ;"
            "jalr s0"
        );
        break;
    case 9:
        __asm__ volatile(
            "li s0, 0x89010000 ;"
            "jalr s0"
        );
        break;
    case 10:
        __asm__ volatile(
            "li s0, 0x8A010000 ;"
            "jalr s0"
        );
        break;
    case 11:
        __asm__ volatile(
            "li s0, 0x8B010000 ;"
            "jalr s0"
        );
        break;
    case 12:  
        __asm__ volatile(
            "li s0, 0x8C010000 ;"
            "jalr s0"
        );
        break;
    case 13:
        __asm__ volatile(
            "li s0, 0x8D010000 ;"
            "jalr s0"
        );
        break;
    case 14:
        __asm__ volatile(
            "li s0, 0x8E010000 ;"
            "jalr s0"
        );
        break;
    case 15:
        __asm__ volatile(
            "li s0, 0x8F010000 ;"
            "jalr s0"
        );
        break;
    case 16:  
        __asm__ volatile(
            "li s0, 0x90010000 ;"
            "jalr s0"
        );
        break;
    case 17:
        __asm__ volatile(
            "li s0, 0x91010000 ;"
            "jalr s0"
        );
        break;
    case 18:
        __asm__ volatile(
            "li s0, 0x92010000 ;"
            "jalr s0"
        );
        break;
    case 19:
        __asm__ volatile(
            "li s0, 0x93010000 ;"
            "jalr s0"
        );
        break;
    case 20:  
        __asm__ volatile(
            "li s0, 0x94010000 ;"
            "jalr s0"
        );
        break;
    case 21:
        __asm__ volatile(
            "li s0, 0x95010000 ;"
            "jalr s0"
        );
        break;
    case 22:
        __asm__ volatile(
            "li s0, 0x96010000 ;"
            "jalr s0"
        );
        break;
    case 23:
        __asm__ volatile(
            "li s0, 0x97010000 ;"
            "jalr s0"
        );
        break;
    default:
        break;
    }

    // if (hartid == 0)
    // {
    //     print_uart("Success\n");
    // }
    return 0;
}

void handle_trap(void)
{
    while (1) {}
}