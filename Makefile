.PHONY: run clean

run:
	@nasm -f elf64 init.asm -o init.o
	@ld -o init init.o
	@./init
clean: 
	@rm -f init.o init