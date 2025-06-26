org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

; FAT12 header
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'       ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880             ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h             ; F0 = 3.5" floppy
bdb_sectors_per_fat:        dw 9                ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                ; 0x00 floppy, 0x80 hdd
                            db 0
ebr_signature:              db 29h
ebr_volume_id:              db 10h, 24h, 20h, 48h
ebr_volume_label:           db 'ranaeOS    '
ebr_system_id:              db 'FAT12   '

start:
    ; setup data segments
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00

    ; some bioses might start at 07C0:0000 instead of 0000:7C00
    push es
    push word .after
    retf

.after:
    ; read something
    mov [ebr_drive_number], dl

    ; loading msg
    mov si, msg_loading
    call puts

    ; read drive params
    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    and cl, 0x3F                        ; remove top 2 bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx     ; sector count

    inc dh
    mov [bdb_heads], dh                 ; head count

    ; compute LBA of root dir = reserved + fats * sectors_per_fat
    ; this section can be hardcoded
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx                              ; ax = (fats * sectors_per_fat)
    add ax, [bdb_reserved_sectors]      ; ax = LBA of root dir
    push ax

    ; compute size of root dir = (32 * number_of_entries) / bytes_per_sector
    mov ax, [bdb_sectors_per_fat]
    shl ax, 5                           ; ax *= 32
    xor dx, dx                          ; dx = 0
    div word [bdb_bytes_per_sector]     ; # of sectors we need to read

    test dx, dx                         ; if dx != 0, add 1
    jz .root_dir_after
    inc ax                              ; division remainder != 0, add 1
                                        ; this means sector is only partially filled with entries
.root_dir_after:
    ; read root dir
    mov cl, al                          ; cl = # sectors to read, size of root dir
    pop ax                              ; ax = LBA of root dir
    mov dl, [ebr_drive_number]          ; dl = drive #
    mov bx, buffer                      ; es:bx = buffer
    call disk_read

    ; search for stage2.bin
    xor bx, bx
    mov di, buffer

.search_stage2:
    mov si, file_stage2_bin
    mov cx, 11                          ; compare up to 11 chars
    push di
    repe cmpsb
    pop di
    je .found_stage2

    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_stage2

    ; no stage2 found
    jmp stage2_not_found_error
    
.found_stage2:
    ; di should have address to entry
    mov ax, [di + 26]                   ; first logical cluster field
    mov [stage2_cluster], ax

    ; load FAT from disk into mem
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    ; read stage2 and process FAT chain
    mov bx, STAGE2_LOAD_SEGMENT
    mov es, bx
    mov bx, STAGE2_LOAD_OFFSET

.load_stage2_loop:
    ; read next cluster
    mov ax, [stage2_cluster]
    add ax, 31                          ; first cluster = (stage2_cluster - 2) * sectors_per_cluster + start_sector
                                        ; start sector = reserved + fats + root dir size

    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]

    ; compute location of next cluster
    mov ax, [stage2_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx                              ; ax = index of entry in FAT, dx = cluster mod 2

    mov si, buffer
    add si, ax
    mov ax, [ds:si]                     ; read entry from FAT table

    or dx, dx
    jz .even

.odd:
    shr ax, 4
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF

.next_cluster_after:
    cmp ax, 0x0FF8                      ; end of chain
    jae .read_finish

    mov [stage2_cluster], ax
    jmp .load_stage2_loop

.read_finish:
    ; jump to stage 2
    mov dl, [ebr_drive_number]          ; boot device in dl
    mov ax, STAGE2_LOAD_SEGMENT         ; set segment registers
    mov ds, ax
    mov es, ax

    jmp STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET

    ; should never happen
    jmp wait_key_and_reboot

    cli
    hlt



; error handling
floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

stage2_not_found_error:
    mov si, msg_stage2_not_found
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h         ; wait for key press
    jmp 0FFFFh:0    ; jumps to beginning of BIOS, reboot

.halt:
    cli             ; disables interrupts
    hlt


; prints string to screen
; @params:
;   - ds:si points to string
puts:
    push si
    push ax

.loop:
    lodsb       ; loads next character in al
    or al, al   ; verify if next char is null
    jz .done

    mov ah, 0x0e
    mov bh, 0
    int 0x10

    jmp .loop

.done:
    pop ax
    pop si
    ret

; disk routines

; converts LBA address to CHS address
; @params:
;   - ax: LBA address
; @returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
lba_to_chs:
    push ax
    push dx

    xor dx, dx                      ; dx = 0
    div word [bdb_sectors_per_track] ; ax = LBA / SectorsPerTrack
                                    ; dx = LBA % SectorsPerTrack

    inc dx                          ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx                      ; cx = sector

    xor dx, dx                      ; dx = 0
    div word [bdb_heads]            ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                    ; dx = (LBA / SectorsPerTrack) % Heads = head
    mov dh, dl                      ; dh = head
    mov ch, al                      ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                       ; put upper 2 bits of cylinder in CL

    pop ax
    mov dl, al                      ; restore DL
    pop ax
    ret

; reads sectors from disk
; @params:
;   - ax: LBA address
;   - cl: # of sectors to read (max 128)
;   - dl: drive number
;   - es:bx: memory address where to store read data
disk_read:
    push ax             ; save registers we will modify
    push bx
    push cx
    push dx
    push di

    push cx             ; temp save CL (# sectors to read)
    call lba_to_chs     ; compute CHS
    pop ax              ; AL = # sectors to read
    
    mov ah, 02h
    mov di, 3           ; retry count

.retry:
    pusha               ; save all registers, in case bios modifies
    stc                 ; set carry flag, some bios don't set it
    int 13h             ; carry flag cleared = success
    jnc .done

    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts fail
    jmp floppy_error

.done:
    popa

    pop di             ; restore modified registers
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; resets disk controller
; @params:
;   dl: drive num
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_loading:            db 'bootloadering..', ENDL, 0
msg_read_failed:        db 'yikes, disk read fail :C', ENDL, 0
msg_stage2_not_found:   db 'no STAGE2.BIN found :C', ENDL, 0
file_stage2_bin:        db 'STAGE2  BIN'
stage2_cluster:         dw 0

STAGE2_LOAD_SEGMENT     equ 0x2000
STAGE2_LOAD_OFFSET      equ 0

times 510-($-$$) db 0
dw 0AA55h

buffer: 