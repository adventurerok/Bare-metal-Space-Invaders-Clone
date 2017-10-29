; MACROS --------------------------------
    %define int_video int 0x10
    %define int_io int 0x13

; BOOTLOADER ------------------------

    mov ax, 0x07C0
    mov ds, ax

; store the drive
    mov [drive], dl

; setup the stack
    mov ax, 0x0050
    cli
    mov ss, ax
    mov sp, 16384 ;16kb of stack
    sti

    mov si, msg_loading
    call video_writeString

; load the code
    mov bx, target
    mov es, bx
    mov bx, 0

    mov dh, 00 ;read head 0
    mov dl, [drive]
    mov ch, 00 ;read track 0
    mov cl, 02 ;read sector 02
    mov al, 10 ;read n sectors
    mov ah, 02 ;read function code

read_code:
    int_io
    jc error

    mov si, msg_success
    call video_writeString

    mov bx,target
    mov ds, bx
    mov es, bx

    jmp target:0x0000

error:
    mov si, msg_error
    call video_writeString

    jmp read_code

; writes a char at the current position
; al is the char
video_writeChar:
    mov ah, 0x0e
    int_video

    ret

; print the null terminated string in si
video_writeString:
    lodsb
    test al,al
    jz video_writeString_end

    call video_writeChar
    jmp video_writeString

video_writeString_end:
    ret

; BOOTLOADER STORAGE -------------------
    drive db 0

    target equ 0x07E0

    msg_loading db 'Loading space...', 0xd, 0xa, 0
    msg_error db 'Error!', 0xd, 0xa, 0
    msg_success db 'Success! Jumping to it!', 0xd, 0xa, 0

; PADDING AND BOOT SIGNATURE --------------------------------------------------
    times 510-($-$$) db 0
    db 0x55
    db 0xAA
