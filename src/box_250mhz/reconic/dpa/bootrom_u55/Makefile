CROSSCOMPILE ?= riscv64-unknown-elf-
CC 			= ${CROSSCOMPILE}gcc
PYTHON		=python3

# snitch
 CFLAGS	 = -Os -ggdb -march=rv32g -mabi=ilp32d -Wall

# ariane
# CFLAGS 		= -Os -ggdb -march=rv64gc -mabi=lp64d -Wall

CCASFLAGS 	= -mcmodel=medany -mexplicit-relocs
LDFLAGS 	= -nostdlib -nostartfiles

INCLUDES 	= -I./ -I./src

SRCS_C 		= src/main.c src/uart.c # src/spi.c src/sd.c src/gpt.c
SRCS_ASM 	= startup.S
OBJS_C 		= $(SRCS_C:.c=.o)
OBJS_S 		= $(SRCS_ASM:.S=.o)

MAIN 		= bootrom.elf
MAIN_BIN 	= $(MAIN:.elf=.bin)
MAIN_IMG 	= $(MAIN:.elf=.img)
MAIN_SV 	= $(MAIN:.elf=.sv)

#.PHONY: clean

$(MAIN): $(OBJS_C) $(OBJS_S) linker.lds
	$(CC) $(CFLAGS) $(LDFLAGS) $(INCLUDES) -Tlinker.lds $(OBJS_S) $(OBJS_C) -o $(MAIN)
	@echo "LD    >= $(MAIN)"

%.img: %.bin
	dd if=$< of=$@ bs=128

%.bin: %.elf
	$(CROSSCOMPILE)objcopy -O binary $< $@

%.o: %.c
	@$(CC) $(CFLAGS) $(INCLUDES) -c $<  -o $@
	@echo "CC    <= $<"

%.o: %.S
	@$(CC) $(CFLAGS) $(CCASFLAGS) $(INCLUDES) -c $<  -o $@
	@echo "CC    <= $<"

%.sv: %.img
	$(PYTHON) ./gen_rom.py $<
	@echo "PYTHON >= $(MAIN_SV)"

clean:
	$(RM) $(OBJS_C) $(OBJS_S) $(MAIN) $(MAIN_BIN) $(MAIN_IMG) $(MAIN_SV) *.dtb

all: $(MAIN) $(MAIN_BIN) $(MAIN_IMG) $(MAIN_SV)
	@echo "zero stage bootloader has been compiled!"
	riscv64-unknown-elf-objdump -d bootrom.elf > dump.txt 

# DO NOT DELETE THIS LINE -- make depend needs it
