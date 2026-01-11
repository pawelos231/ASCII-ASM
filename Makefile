.PHONY: run clean

run:
	@nasm -f elf64 init.asm -o init.o
	@ld -o init.elf init.o
	@./init.elf
clean: 
	@rm -f init.o init