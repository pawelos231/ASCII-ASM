; hello world program in x86 assembly
global _start
section .text


_start:
    ; open
    mov rax, 2
    mov rdi, name 
    mov rsi, 0
    syscall
    mov r12, rax ; remember the file descriptor

    xor r9, r9
    jmp loop

after_loop:
    ;close
    mov rax, 3
    mov rdi, r12
    syscall
    
    ;exit
    mov rax, 60 
    xor rdi, rdi ; status = 0
    syscall


loop:
    ; read step
    mov rdi, r12 ; set rdi to fd
    mov rax, 0 ; set rax to open file descriptor sys call 
    mov rsi, buf ; set rsi register to buf (which is 16 bytes)
    movzx edx, byte[value] ; count - how many bytes to read, zero-extend - will set higher up bits to 0
    syscall
    mov r9, rax ;holds amount of data read
    cmp r9, 0
    jle after_loop ; if number of bytes read is 0, then quit

    ; write step
    mov rdx, rax
    mov rsi, buf
    mov rax, 1
    mov rdi, 1
    syscall

    jmp loop


section .data
msg db 'Hello, World!', 10
name db 'siema.txt', 0
value db 128, 0
msg_len equ $ - msg


section .bss
buf resb 16