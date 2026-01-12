.PHONY: run run-debug clean

ASM = nasm
LD  = ld

run:
	@go run decode.go
	@$(ASM) -f elf64 init.asm -o init.o
	@$(LD) -o init.elf init.o
	@./init.elf

run-debug:
	@$(ASM) -f elf64 -g -F dwarf init.asm -o init.o
	@$(LD) -g -o init.elf init.o
	@gdb ./init.elf

clean:
	@rm -f init.o init.elf out.bruh
