bits 16

section _TEXT class=CODE


; int 10h ah=0Eh
; @params: 
;   - character, 
;   - page
global _x86_Video_WriteCharTTY
_x86_Video_WriteCharTTY:
    ; make new call frame
    push bp                 ; save old call frame
    mov bp, sp              ; init new call frame
    
    push bx                 ; save bx rq
    ; [bp + 0] - old call frame
    ; [bp + 2] - return addr (small mem model => 2B)
    ; [bp + 4] - first arg (character), bytes converted to words
    ; [bp + 6] - second arg (page)
    mov ah, 0Eh
    mov al, [bp + 4]
    mov bh, [bp + 6]

    int 10h

    pop bx                  ; restore bx
    mov sp, bp              ; restore old call frame
    pop bp
    ret