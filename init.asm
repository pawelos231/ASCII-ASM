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
    mov r8d, dword[width_buf] ; width
    mov r15, rdx ; save outer row counter in r15 for later use in effective height calculation
    imul r15, r8 ; y offset within current chunk row
    lea rsi, [r13 + r15] ; base address + y offset of current chunk row
    add rsi, r10 ; x offset in current chunk row
    add rsi, rbx ; y offset of current chunk

    ; effective width for this chunk column = min(chunk_width, width - x_offset)
    mov eax, r8d ; width
    sub eax, r10d ; width - x_offset
    movzx r15d, byte [chunk_width] ; chunk_width
    cmp eax, r15d ; compare width - x_offset with chunk_width
    cmova eax, r15d ; if width - x_offset > chunk_width, effective width = chunk_width, else effective width = width - x_offset
    mov r8d, eax ; r8d = effective width

    ; effective height for this chunk row = min(chunk_height, rows_remaining)
    mov r15, rdx ; save outer row counter across div
    mov rax, [image_size] ; total image size in bytes
    sub rax, rbx ; bytes remaining in the image from the current y offset
    xor edx, edx ; clear edx for div
    mov ecx, dword [width_buf] ; width (bytes in a row)
    div rcx ; rax = rows remaining from current chunk row start
    movzx r11d, byte [chunk_height]
    cmp eax, r11d ; compare rows remaining with chunk_height
    cmova eax, r11d ; if rows remaining > chunk_height, effective height = chunk_height, else effective height = rows remaining
    mov r11d, eax ; r11d = effective height
    mov rdx, r15 ; restore outer row counter
    xor rcx, rcx ; restore inner counter after using rcx as div divisor
    
inner:
    mov al, [rsi + rcx] ; load byte from image data
    movzx rax, al
    add r9, rax ; we add the pixel value to r9 on every iteration
    inc rcx
    cmp ecx, r8d ; compare inner counter with effective width
    jne inner ; do the loop again if we did not reach effective width
    inc rdx
    cmp edx, r11d
    jne process_chunk


after_memory_read:
    ; compute average = sum / (effective_width * effective_height)
    mov eax, r8d
    imul eax, r11d ; pixel count in the current (possibly clipped) chunk
    mov ecx, eax
    mov rax, r9
    xor edx, edx
    div rcx
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
chunk_width db 64 
chunk_height db 64



section .bss
read_buf resb 4096
width_buf resb 4
height_buf resb 4
converted_buf_size dq 0
image_size dq 0
