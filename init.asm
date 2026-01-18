global _start
section .text
; r12 in this application is a long lived register (callee save nature) - it holds fd (file-descriptor)
; r13 in this application is also a long lived register (callee save nature) it holds the start address of base-adress of image
; r14 in this application is also a long lived register (callee save nature) it holds the start of address space for converted chunks

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
    call register_memory_for_converted_chunks
    ; at this point, the image is in memory at address r13
    ; with size r15 (width * height)
    mov rcx, 0
    mov rdx, 0
    xor rax, rax ; zero out rax as al is the bottom 8 bits of this register
    xor r10, r10 ; set r10 register to 0
    xor r9, r9 ; set r9 to zero (this register will hold the sum of the pixel values)
    jmp loop_over_memory_in_chunks
    ; jmp read_file_loop


loop_over_memory_in_chunks:
    xor rcx, rcx

inner:
    mov al, [r13 + rcx] ; load byte from image data
    movzx rax, al
    add r9, rax ; we add the pixel value to r9 on every iteration
    inc rcx
    cmp rcx, 8
    jne inner ; do the loop again if rcx is not equal to 8
    add r13, r15 ; r13 (base address) now holds (base address) + (buf_width * rdx)
    inc rdx
    cmp rdx, 8
    jne loop_over_memory_in_chunks


after_read_file_loop:
    shr r9, 6 ; divide the sum of pixels in a chunk(64byte chunk) by 64
    xor r11, r11 ; make place for index calculation
    mov r11, r9
    imul r11, 9 ;multiply the average value times 9
    imul r11, r11, 257 ; this 257 can really seem out of nowhere, but 1 / 255 ≈ K / 2^16 (we are trying to find K, which should be a veryyy close approximation), so K ≈ 2^16/255 ≈ 257 
    shr r11, 16 ; approxiamate the index (divide by 65536)
    cmp r11, 9
    call ok  ; jump if below or equal (to make sure we are in bounds [0-9 index])
    mov r11, 9 ; if went outside the scope, set it to 9

    ;close
    mov rax, 3
    mov rdi, r12
    syscall
    
    ;exit
    mov rax, 60 
    xor rdi, rdi ; status = 0
    syscall

ok:
    xor r9, r9
    mov r9b, [string_collection + r11]
    ; place the converted chunk (so just char) into memory
    ret 
    

register_memory_for_converted_chunks:
    xor r15, r15
    xor r10, r10
    mov r15d, dword[width_buf] ;holds pointer to width_buf (which points to width of the image in pixels), 
    mov r10d, dword[height_buf] ;hold pointer to height_buf (which points to the height of the image in pixels)
    imul r15d, r10d
    shr r15d, 6 ;divide it by 64, beacuse we have number_of_pixels / 64 chunks
    ; syscall related stuff
    mov rax, 9 ; mmap
    mov rsi, r15 ; width * height (bytes)
    mov rdi, 0 ; kernel chooses space
    mov rdx, 1; PROT_READ
    mov r10, 0x22 ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1 ; fd = -1
    xor r9, r9 ; offset = 0
    syscall
    mov r14, rax
    ret


; for know entire image goes into ram, streaming might be an idea for later tho...
place_image_in_memory:
    mov r15d, dword[width_buf] ;holds pointer to width_buf (which points to width of the image in pixels), 
    mov r10d, dword[height_buf] ;hold pointer to height_buf (which points to the height of the image in pixels)
    mov r11, r15 ; hold a copy of width to not overwrite it
    imul r11, r10 ; hold it in calee save register for later use in clear function
    mov rsi, r11 ; width * height (bytes)
    mov rax, 9 ; mmap
    mov rdi, 0 ; kernel chooses space
    mov rdx, 1; PROT_READ
    mov r10, 2 ; MAP_PRIVATE
    mov r8, r12 ; fd
    xor r9, r9 ; offset = 0
    syscall
    mov r13, rax ; base adress rememebr (after 8 bytes of header info)
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
string_collection db " .:-=+*#%@", 0
name db 'out.bruh', 0
value dq 4096, 0
chunk_width db 8
chunk_height db 8

msg_len equ $ - msg


section .bss
read_buf resb 4096
width_buf resb 4
height_buf resb 4
