// hpCluster memory map 


// core clock in mhz
#define CORE_CLK    50000000
#define UART_BAUD   115200
// dram address space
#define DRAM_BASE   0x80000000
#define DRAM_PAYLOAD_OFFSET 0x10000
#define DRAM_SIZE   0x20000000 //512MB per core
// pheripheral address space

// UNUSED
#define DEBUG_BASE   0x00000000

// ROM
#define ROM_BASE     0x00000000

// clint
#define CLINT_BASE          0x02000000
#define CLINT_IPI_OFF		0
#define CLINT_TIMER_CMP_OFF	0x4000
#define CLINT_TIMER_VAL_OFF	0xbff8
#define CLINT_TIMER_FREQ    10000000

// Peripherals
#define PLIC_BASE    0x10000000
#define UART_BASE    0x14000000
#define IIMER_BASE   0x14001000


//UNUSED
#define SPIBase     0x20000000
#define EtheBase    0x30000000
#define GPIOBase    0x40000000