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

    ; read the first 4 bytes (width)
    mov rax, 0
    mov rdi, r12
    mov rsi, width_buf
    mov rdx, 4 ; 4 bytes
    syscall

    ; read the next 4 bytes (height)
    mov rax, 0
    mov rdi, r12
    mov rsi, height_buf
    mov rdx, 4 ; 4 bytes
    syscall

    call place_image_in_memory
    ; at this point, the image is in memory at address r13
    ; with size r15 (width * height)
    

    ; jmp read_file_loop

after_read_file_loop:
    ;close
    mov rax, 3
    mov rdi, r12
    syscall
    
    ;exit
    mov rax, 60 
    xor rdi, rdi ; status = 0
    syscall


; for know entire image goes into ram, streaming might be an idea for later tho...
place_image_in_memory:
    mov r15d, dword[width_buf] ;holds pointer to width_buf (which points to width of the image in pixels), 
    mov r10d, dword[height_buf] ;hold pointer to height_buf (which points to the height of the image in pixels)
    imul r15, r10 ; hold it in calee save register for later use in clear function
    mov rsi, r15 ; width * height
    mov rax, 9 ;mmap
    mov rdi, 0 ; kernel chooses space
    mov rdx, 1; PROT_READ
    mov r10, 2 ; MAP_PRIVATE
    mov r8, r12 ; fd
    mov r9, 0 ; offset
    syscall
    mov r13, rax ;base adress rememebr (after 8 bytes of header info)
    ret

clear_memory_from_image_data:
    mov rax, 11 ; munmap
    mov rdi, r13 ; base adress of image
    mov rsi, r15
    syscall
    ret

read_file_loop:
    ; read step
    mov rdi, r12 ; set rdi to fd
    mov rax, 0 ; set rax to open file descriptor sys call 
    mov rsi, read_buf ; set rsi register to buf (which is 4096 bytes)
    mov rdx, [value] ; count - how many bytes to read, zero-extend 
    syscall
    mov r9, rax ;holds amount of data read
    cmp r9, 0
    jle after_read_file_loop ; if number of bytes read is 0, then quit

    ; write step
    mov rdx, rax
    mov rsi, read_buf
    mov rax, 1
    mov rdi, 1
    syscall

    jmp read_file_loop


section .data
msg db 'Hello, World!', 10
name db 'out.bruh', 0
value dq 4096, 0
chunk_width db 8
chunk_height db 8

msg_len equ $ - msg


section .bss
read_buf resb 4096
width_buf resb 4
height_buf resb 4
