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
    call close_file
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
    mov [image_size], r11 ; remember image size for later use in clear function
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

; we dont need the file anymore after loading it into memory
close_file:
    mov rax, 3
    mov rdi, r12
    syscall
    ret


register_memory_for_converted_chunks:
    ; cols = (width + chunk_width - 1) / chunk_width  (ceil), chunk_width = 2^n
    movzx   r9d, byte [chunk_width] ; r9d = chunk_width
    mov     eax, dword [width_buf] ; eax = width
    lea     eax, [eax + r9d - 1] ; eax = width + chunk_width - 1
    bsf     ecx, r9d ; ecx = log2(chunk_width)
    shr     eax, cl ; eax = cols
    mov     r8d, eax ; r8d = cols

    ; rows = (height + chunk_height - 1) / chunk_height (ceil), chunk_height = 2^n
    movzx   r9d, byte [chunk_height] ; r9d = chunk_height
    mov     eax, dword [height_buf] ; eax = height
    lea     eax, [eax + r9d - 1] ; eax = height + chunk_height - 1
    bsf     ecx, r9d ; ecx = log2(chunk_height)
    shr     eax, cl ; eax = rows
    mov     ecx, eax ; ecx = rows

    mov     eax, r8d               ; cols
    imul    eax, ecx               ; eax = cols*rows
    mov     edx, ecx
    dec     edx
    add     eax, edx               ; total_bytes
    mov     r15d, eax
    mov     [converted_buf_size], r15
    
    mov     rax, 9
    mov     rdi, 0
    mov     rsi, r15
    mov     rdx, 3
    mov     r10, 0x22
    mov     r8, -1
    xor     r9, r9
    syscall

    mov     r14, rax
    mov     r12, r14
    xor     rdx, rdx
    xor     r10, r10
    xor     rbx, rbx
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
    cmp cl, [chunk_width]
    jne inner ; do the loop again if rcx is not equal to chunk_width
    inc rdx
    xor r15, r15
    cmp dl, [chunk_height]
    jne process_chunk


after_memory_read:
    ; compute average = sum / (chunk_width * chunk_height)
    movzx r8d,  byte [chunk_width] ; r8d = chunk_width
    movzx r11d, byte [chunk_height] ; r11d = chunk_height
    bsf ecx, r8d ; ecx = log2(chunk_width)
    bsf edx, r11d ; edx = log2(chunk_height)
    add ecx, edx ; ecx = log2(chunk_width*chunk_height)
    shr r9, cl; r9 = avg (instead of div)
    mov r9, rax
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
    mov byte [r12], r9b 
    inc r12 ; increment the address for next chunk

    
go_to_next_chunk:
    xor r9, r9 ; clear the the register from converted chunk 
    xor rax, rax ; clear rax as it holds byte from image data
    xor rdx, rdx ; clear the outer counter
    movzx r11d, byte [chunk_width] ; we need chunk width to move to the next chunk
    add r10d, r11d ; we add to move it to the right, so next chunk to the right, this will have to zeroed out if we go to the edge of the image
    cmp r10d, dword[width_buf] ; compare x offset with width of image
    jl process_chunk

    xor r10, r10 ; reset x offset
    mov r10d, dword [width_buf]
    movzx r11d, byte [chunk_height]
    imul r10, r11
    add rbx, r10           

    cmp rbx, [image_size]
    jge write_to_console

    xor r10, r10          ; reset x offset
    mov byte[r12], 10     ; add newline after each row of chunks
    inc r12 ; increment the address for next chunk
    jmp process_chunk


write_to_console:
    mov     rax, 1        ; sys_write
    mov     rdi, 1        ; stdout
    mov     rsi, r14      ; buffer base
    mov     byte[r12], 10 ; add newline after each row of chunks
    mov     rdx, [converted_buf_size]
    add     rdx, 1
    syscall


clear_memory_from_image_data:
    mov rax, 11 ; munmap
    mov rdi, r13 ; base adress of image
    mov rsi, [image_size] ; size of image
    syscall

    mov rax, 11 ; munmap
    mov rdi, r14 ; base adress of converted chunks
    mov rsi, [converted_buf_size] ; size of converted chunks
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
chunk_width db 8 
chunk_height db 8



section .bss
read_buf resb 4096
width_buf resb 4
height_buf resb 4
converted_buf_size dq 0
image_size dq 0
