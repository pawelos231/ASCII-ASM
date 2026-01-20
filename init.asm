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
    xor rcx, rcx
    xor rdx, rdx
    xor rax, rax ; zero out rax as al is the bottom 8 bits of this register
    xor r10, r10 
    xor r9, r9 ; set r9 to zero (this register will hold the sum of the pixel values)
    jmp process_chunk
    ; jmp read_file_loop



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
    mov rdx, 3; PROT_READ | PROT_WRITE
    mov r10, 0x22 ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1 ; fd = -1
    xor r9, r9 ; offset = 0
    syscall
    mov r14, rax
    xor rdx, rdx ; clear the register of any thrash data it will hold the outer counter for chunk processing
    xor r10, r10 ; clear the register of any thrash data (it will hold the X offset)
    xor rbx, rbx ; clear the register of any thrash data it will hold the Y offset
    ret


process_chunk:
    xor rcx, rcx
    mov r8d, dword[width_buf]
    mov r15, rdx
    imul r15, r8
    lea rsi, [r13 + r15]
    add rsi, r10
    add rsi, rbx
    
inner:
    mov al, [rsi + rcx] ; load byte from image data
    movzx rax, al
    add r9, rax ; we add the pixel value to r9 on every iteration
    inc rcx
    cmp rcx, 8
    jne inner ; do the loop again if rcx is not equal to 8
    inc rdx
    xor r15, r15
    cmp rdx, 8
    jne process_chunk


after_memory_read:
    ;remember the counter
    shr r9, 6 ; divide the sum of pixels in a chunk(64byte chunk) by 64
    xor r11, r11 ; make place for index calculation
    mov r11, r9
    imul r11, 9 ;multiply the average value times 9
    imul r11, r11, 257 ; this 257 can really seem out of nowhere, but 1 / 255 ≈ K / 2^16 (we are trying to find K, which should be a veryyy close approximation), so K ≈ 2^16/255 ≈ 257 
    shr r11, 16 ; approxiamate the index (divide by 65536)
    cmp r11, 9
    jbe place_converted_chunk_in_memory  ; jump if below or equal (to make sure we are in bounds [0-9 index])
    mov r11, 9 ; if went outside the scope, set it to 9


place_converted_chunk_in_memory:
    xor r9, r9
    mov r9b, [string_collection + r11]
    ; place it into memory (r14)
    mov byte [r14], r9b

    ; write the value to the console (this will not be here normally)
    mov rax, 1            ; sys_write
    mov rdi, 1            ; stdout
    mov rsi, r14          ; adres bufora
    mov rdx, 1            ; 1 bajt
    syscall

    inc r14 ; increment the address for next chunk

    
go_to_next_chunk:
    xor r9, r9 ; clear the the register from converted chunk 
    xor rax, rax ; clear rax as it holds byte from image data
    xor rdx, rdx ; clear the outer counter
    add r10d, 8 ; we add to move it to the right, so next chunk to the right, this will have to zeroed out if we go to the edge of the image
    cmp r10d, dword[width_buf]
    jl process_chunk

    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, newline
    mov rdx, 1
    syscall

    xor r10, r10 ; reset x offset
    mov r10d, dword [width_buf]
    imul r10, 8
    add rbx, r10         

    mov r8d, dword [width_buf]
    mov ecx, dword [height_buf]
    imul r8, rcx         

    cmp rbx, r8
    jge clear_memory_from_image_data

    xor r10, r10          ; reset x offset
    jmp process_chunk
    

clear_memory_from_image_data:
    mov rax, 11 ; munmap
    mov rdi, r13 ; base adress of image
    mov rsi, r15
    syscall

    ;close
    mov rax, 3
    mov rdi, r12
    syscall
    
    ;exit
    mov rax, 60 
    xor rdi, rdi ; status = 0
    syscall 



section .data
newline db 10
string_collection db " .:-=+*#%@", 0
name db 'out.bruh', 0
value dq 4096, 0
chunk_width db 8 ; same as height



section .bss
read_buf resb 4096
width_buf resb 4
height_buf resb 4
