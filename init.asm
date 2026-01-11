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

    ; read
    mov rdi, rax
    mov rax, 0
    mov rsi, buf
    mov rdx, 1024
    syscall

    ; write to stdout
    mov rdx, rax
    mov rsi, buf
    mov rax, 1
    mov rdi, 1
    syscall

    ;close
    mov rax, 3
    mov rdi, r12
    syscall

    mov rax, 60 ; exit
    xor rdi, rdi ; status = 0
    syscall



section .data
msg db 'Hello, World!', 10
name db 'siema.txt'
msg_len equ $ - msg


section .bss
buf resb 1024