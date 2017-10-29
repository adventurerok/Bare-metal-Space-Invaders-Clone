; int 0x10 reference: https://courses.engr.illinois.edu/ece390/books/labmanual/graphics-int10h.html

; positions are 0xRRCC where RR is the row and CC is the column. RR=0x00 is the top, and CC=0x00 is the left

; Color Chars are 0xCCAA where AA is the ASCII code and CC is the color code

; MACROS --------------------------------

%define int_video int 0x10
%define int_sys int 0x15
%define int_io int 0x13
%define int_keys int 0x16

; CODE --------------------------------

; setVideoMode 80x25 text
    ;mov ah, 0x00
    ;mov al, 0x03
    ;int_video

    mov si, msg_load
    call video_writeString

; store the screen width in [screen_width]
    mov	ah, 0x0F
    int_video
    mov	[screen_width], ah

; hide the cursor
    mov ah, 0x01
    mov cx, 0x2007
    int_video

    call video_debug

; decrease delay before keyboard repeat
    mov	ax, 0x0305
    mov	bx, 0x001F
    int_keys

    call video_debug

    jmp reset

main_loop:
    mov byte [flag_retry], 0

    call keyboard_input

    call aliens_move
    call missiles_move

    call missiles_collide
    call aliens_win

    mov al, [flag_death]
    cmp al, 1
    je loss_setup

    mov al, [flag_retry]
    cmp al, 1
    je loss_setup

    mov al, [aliens_movecount]
    cmp al, 0
    je main_loop_spawnCheck

    cmp al, 8
    jne main_loop_postSpawnCheck

main_loop_spawnCheck:
    call aliens_spawnCheck

main_loop_postSpawnCheck:

    call video_clear
    call player_draw
    call aliens_draw
    call missiles_draw

    mov dh, 23
    mov dl, 1
    call video_setCursorPos

    mov si, msg_score
    call video_writeString

    mov ax, [player_score]
    call video_writeNum

; Sleep for 0.15 seconds
    mov	cx, 0x0002
    mov	dx, 0x49F0
    call sys_wait

    jmp main_loop


loss_setup:
    mov ax, [player_score]
    mov bx, [highScore_score]

    cmp bx, ax
    jge loss_loop

    mov [highScore_score], ax

loss_loop:
    mov byte [flag_retry], 0

    call keyboard_input

    mov al, [flag_retry]
    cmp al, 1
    je reset

    call video_clear

    mov dh, 1
    mov dl, 1
    call video_setCursorPos

    mov si, msg_lose
    call video_writeString

    mov dh, 3
    mov dl, 1
    call video_setCursorPos

    mov si, msg_score
    call video_writeString

    mov ax, [player_score]
    call video_writeNum

    mov dh, 5
    mov dl, 1
    call video_setCursorPos

    mov si, msg_highScore
    call video_writeString

    mov ax, [highScore_score]
    call video_writeNum

    mov	cx, 0x0002
    mov	dx, 0x49F0
    call sys_wait

    jmp loss_loop

reset:
    call video_debug

    mov ax, 0

    mov di, aliens
    mov cx, aliens_max
    call memory_fillWord

    mov di, missiles
    mov cx, missiles_max
    call memory_fillWord

    mov word [player_score], 0
    mov byte [player_x], player_x_initial
    mov byte [aliens_movecount], 0

    mov word [aliens_spawning_timer], 0
    mov word [aliens_spawning_offset], 0

    mov byte [flag_death], 0

    mov bx, 5
    call aliens_spawnRow

    jmp main_loop

; FUNCTIONS -----------------------------

; set the cursor position to dx
video_setCursorPos:
    mov ah, 0x02
    mov bh, 0
    int_video

    ret

; ax = color char, dx = position
; sets a char at a position
video_setChar:
    push ax

    call video_setCursorPos

    pop ax

    mov bl,ah
    mov ah,0x09
    mov cx,1
    mov bh,0
    int_video

    ret

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

; print the number in ax
video_writeNum:
    mov bx, 10
    mov cx, sp

video_writeNum_pushLoop:
    xor dx, dx
    div bx
    push dx
    test ax, ax
    jnz video_writeNum_pushLoop

video_writeNum_popLoop:
    pop ax
    add al, '0'

    call video_writeChar

    cmp cx, sp
    jne video_writeNum_popLoop

    ret

; clear the screen
video_clear:
    mov ax,0x0700
    mov bh,0x0F
    mov cx,0
    mov dh,24
    mov dl,[screen_width]
    int_video

    ret

video_debug:
    pusha

    mov si, msg_debug
    call video_writeString

    popa

    ret

player_draw:
    mov ax, player_code
    mov dh, player_y
    mov dl, [player_x]
    call video_setChar

    ret

; Spawn a missile at the player position
player_missile:
    mov si, missiles
    mov cx, missiles_max

player_missile_loop:
    dec cx
    test cx, cx
    jz player_missile_end

    lodsw
    test ah, ah
    jnz player_missile_loop

    mov ah, player_y
    mov al, [player_x]
    mov [si - 2], ax

player_missile_end:
    ret

aliens_spawnCheck:
    mov dx, [aliens_spawning_timer]
    inc dx
    mov [aliens_spawning_timer], dx

    mov si, [aliens_spawning_offset]
    cmp si, aliens_spawndata_times_length
    jge aliens_spawnCheck_minTime

    mov bl, [aliens_spawndata_times + si]
    jmp aliens_spawnCheck_timeCheck

aliens_spawnCheck_minTime:
    mov bl, aliens_spawndata_times_min

aliens_spawnCheck_timeCheck:
    cmp dl, bl
    jl return

    mov word [aliens_spawning_timer], 0

    cmp si, aliens_spawndata_count_length
    jge aliens_spawnCheck_maxCount

    mov bl, [aliens_spawndata_count + si]
    jmp aliens_spawnCheck_spawn

aliens_spawnCheck_maxCount:
    mov bl, aliens_spawndata_count_max

aliens_spawnCheck_spawn:
    inc si
    mov [aliens_spawning_offset], si

    mov bh, 0
    call aliens_spawnRow

    ret

; Spawn an alien at dx
alien_spawn:
    ; mov si, aliens :assume an index is already in si
    ; mov cx, aliens_max :assume the same

    dec cx
    test cx, cx
    jz return

    lodsw
    test ah, ah
    jnz alien_spawn

    mov [si - 2], dx

; Utility return function
return:
    ret

; bx is the number to spawn
aliens_spawnRow:

; Calculate 1/2 screen width
    mov ah, 0
    mov al, [screen_width]
    mov dx, 0
    mov cx, 2
    div cx

    sub ax, bx


    mov si, [aliens_movecount]
    mov dl, [aliens_movecount_offset + si]
    add dl, al
    sub dl, 3
    mov dh, 1


    mov si, aliens
    mov cx, aliens_max

aliens_spawnRow_loop:
    call alien_spawn

    add dl, 2
    dec bx

    test bx, bx
    jnz aliens_spawnRow_loop

    ret

aliens_move:
    mov bl,[aliens_movecount]

    inc bl

    and bl, 0xF
    mov [aliens_movecount],bl
; 0x0 and 0x8 are down, 0x1-0x7 are move right, 0x9-0xF are move left

    test bl, 0b0111
    jz aliens_move_setupDown

    test bl, 0b1000
    jz aliens_move_setupRight

; aliens_move_setupLeft:
    mov bl, 2
    jmp aliens_move_postSetup

aliens_move_setupDown:
    mov bl, 0
    jmp aliens_move_postSetup

aliens_move_setupRight:
    mov bl, 1
    jmp aliens_move_postSetup

aliens_move_postSetup:
; now bl=0 is down, bl=1 is right and bl=2 is left
    mov si, aliens
    mov cx, aliens_max

aliens_move_loop:
    dec cx
    test cx, cx
    jz aliens_move_end

    lodsw
    test ah, ah
    jz aliens_move_loop

    cmp bl, 0
    je aliens_move_loopDown

    cmp bl, 1
    je aliens_move_loopRight

;aliens_move_loopLeft:
    sub al,1
    jmp aliens_move_loopEnd

aliens_move_loopDown:
    add ah,1
    jmp aliens_move_loopEnd

aliens_move_loopRight:
    add al,1
    jmp aliens_move_loopEnd

aliens_move_loopEnd:
    mov [si-2], ax

    jmp aliens_move_loop

aliens_move_end:
    ret

aliens_draw:
    mov si, aliens
    mov cx, aliens_max

aliens_draw_loop:
; Check if we are at the end of the loop
    dec cx
    test cx, cx
    jz aliens_draw_end

    lodsw
    test ah, ah
    jz aliens_draw_loop

    mov dx, ax
    mov ax, alien_code

    push cx
    call video_setChar
    pop cx

    jmp aliens_draw_loop


aliens_draw_end:
    ret

; Check if any aliens are on the same line as the player
aliens_win:
    mov si, aliens
    mov cx, aliens_max

aliens_win_loop:
    dec cx,
    test cx, cx
    jz aliens_win_end

    lodsw
    cmp ah, player_y
    jne aliens_win_loop

    mov byte [flag_death], 1

aliens_win_end:
    ret

missiles_move:
    mov si, missiles
    mov cx, missiles_max

missiles_move_loop:
    dec cx
    test cx, cx
    jz missiles_move_end

    lodsw
    test ah, ah
    jz missiles_move_loop

    sub ah, 1
    mov [si - 2], ax

    jmp missiles_move_loop

missiles_move_end:
    ret

missiles_draw:
    mov si, missiles
    mov cx, missiles_max

missiles_draw_loop:
    dec cx
    test cx, cx
    jz missiles_draw_end

    lodsw
    test ah, ah
    jz missiles_draw_loop

    mov dx, ax
    mov ax, missile_code

    push cx
    call video_setChar
    pop cx

    jmp missiles_draw_loop

missiles_draw_end:
    ret

missiles_collide:
    mov di, aliens
    mov cx, aliens_max

missiles_collide_alienLoop:
    dec cx
    test cx, cx
    jz missiles_collide_end

    mov bx, [di]
    add di, 2

    test bh, bh
    jz missiles_collide_missileLoop

    mov si, missiles
    mov dx, missiles_max
missiles_collide_missileLoop:
    dec dx
    test dx, dx
    jz missiles_collide_alienLoop

    lodsw
    test ah, ah
    jz missiles_collide_missileLoop

    cmp bx, ax
    jnz missiles_collide_missileLoop

    mov ax, 0
    mov [si - 2], ax
    mov [di - 2], ax

    mov ax, [player_score]
    inc ax
    mov [player_score], ax

    jmp missiles_collide_alienLoop

missiles_collide_end:
    ret

keyboard_input:

    mov ah, 0x01
    int_keys
    jz keyboard_input_end

    mov ah, 0x00
    int_keys
; al now contains the key

    cmp al, 'd'
    je keyboard_input_right

    cmp al, 'a'
    je keyboard_input_left

    cmp al, ' '
    je keyboard_input_fire

    cmp al, 'r'
    je keyboard_input_retry

    jmp keyboard_input_end

keyboard_input_right:
    mov bl, [player_x]
    mov cl, [screen_width]
    sub cl, 2
    cmp bl, cl
    jge keyboard_input

    add bl, 1
    mov [player_x], bl

    jmp keyboard_input

keyboard_input_left:
    mov bl, [player_x]
    cmp bl, 1
    jle keyboard_input

    sub bl, 1
    mov [player_x], bl

    jmp keyboard_input

keyboard_input_fire:
    call player_missile
    jmp keyboard_input

keyboard_input_retry:
    mov byte [flag_retry], 1
    jmp keyboard_input

keyboard_input_end:
    ret

; cx:dx contains the time to sleep, in multiples of 0.1 ms
sys_wait:
    mov ah,0x86
    int_sys

    ret

; di is the memory pointer, ax is the word, cx is the count
memory_fillWord:
    stosw
    loop memory_fillWord
    ret



; CONSTANTS --------------------------------
    alien_code equ 0x0C48 ; red 'H'
    aliens_movecount db 0
    missile_code equ 0x0269; green 'i'
    player_code equ 0x035E ;blue '^'
    player_y equ 21
    player_x_initial equ 36

    msg_score db 'Score: ', 0
    msg_highScore db 'Hiscore: ', 0
    msg_lose db 'You Lose! Press r to retry', 0
    msg_load db 'The game should run now!', 0xd, 0xa, 0
    msg_debug db 'Debug Message!', 0xd, 0xa, 0

    missiles_max equ 10
    aliens_max equ 100

    aliens_movecount_offset db 0, 1, 2, 3, 4, 5, 6, 7, 7, 6, 5, 4, 3, 2, 1, 0
    aliens_spawndata_times db 10, 10, 10, 9, 9, 9, 8, 8, 7, 7, 6, 6, 5, 5, 5
    aliens_spawndata_times_length equ $ - aliens_spawndata_times
    aliens_spawndata_times_min equ 4

    aliens_spawndata_count db 8, 9, 10, 11, 12, 13, 14
    aliens_spawndata_count_length equ $ - aliens_spawndata_count
    aliens_spawndata_count_max equ 15

    aliens_spawning_timer dw 0
    aliens_spawning_offset dw 0

; VARIABLES --------------------------------

    flag_retry db 0
    flag_death db 0

    player_x db player_x_initial
    screen_width db 0
    player_score dw 0
    highScore_score dw 0

    missiles resw missiles_max ;stores the positions of the missiles. 0x0000 indicates that they are missing
    aliens resw aliens_max; stores the positions of the alians. 0x0000 indicates that they are missing/dead
