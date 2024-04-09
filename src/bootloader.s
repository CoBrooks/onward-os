;; vim:filetype=fasm

use16
org 0x7C00

ERROR_DISK_INFO        equ byte '0'
ERROR_DISK_READ        equ byte '1'
ERROR_KERNEL_NOT_FOUND equ byte '2'
ERROR_DISK_INFO        equ byte '0'

BPB:
  jmp short _start
  nop

.oem:                   db "ABCDEFGH"
.bytes_per_sector:      dw 512
.sectors_per_cluster:   db 4
.reserved_sectors:      dw 4
.fat_count:             db 2
.dir_entries_count:     dw 0x200
.total_sectors:         dw 65504
.media_descriptor_type: db 0xF8
.sectors_per_fat:       dw 64
.sectors_per_track:     dw 32
.heads:                 dw 4
.hidden_sectors:        dd 0
.large_sectors:         dd 0

EBR:
.drive_number:          db 0
                        db 0
.signature:             db 0x29
.volume_id:             db 0x12, 0x34, 0x56, 0x78
.volume_label:          db "FOOBAR     "
.system_id:             db "FAT16   "

;=========;
; STAGE 1 ;
;=========;

_start:
  jmp 0x0:boot
boot:
  ; Setup segment registers
  xor ax, ax
  mov ds, ax
  mov es, ax
  mov ss, ax

  ; Setup stack
  mov bp, $$
  mov sp, bp

  ; Clear direction bit for str ops
  cld

  ; Save drive number
  mov [EBR.drive_number], dl

  ; Set video mode
  mov ax, 0x3
  int 0x10

  ; enable A20
  mov ax, 0x2401
  int 0x15
  
  ; Enable 32 bit protected mode
  cli
  push ds
  push es

  ; Load GDT
  lgdt [GDT.desc]

  ; Enter protected mode
  mov eax, cr0
  or  al, 1
  mov cr0, eax

  mov bx, 0x10
  mov ds, bx
  mov es, bx

  ; Unreal mode
  and al, 0xFE
  mov cr0, eax

  pop es
  pop ds
  sti
  
  ; Check if int 0x13 extensions are supported
  mov ah, 0x41
  mov bx, 0x55AA
  int 0x13
  mov [error.code], ERROR_DISK_READ
  jc  error

  mov bx, 0x0f01
  mov eax, 0xB8000
  mov word [ds:eax], bx

  ; Read stage 2 into memory
  mov si, DAP
  mov ah, 0x42
  int 0x13
  mov [error.code], ERROR_DISK_READ
  jc  error
  or  ah, ah
  jnz error

  jmp 0x7E00
  jmp error

DAP:      db 0x10
          db 0x0
          dw 0x3
.offset:  dw 0x7E00
.segment: dw 0x0
          dd 0x1
          dd 0x0

GDT:   dd 0,0           ; null entry
.code: dw 0xFFFF        ; limit (bits 0-15)
       dw 0x0           ; base (lower 16 bits)
       db 0x0           ; base (upper  8 bits)
       db 10011010b     ; access flags (= present, code, executable, read/write)
       db 10001111b     ; more flags (= byte granularity, 4KiB blocks, 32bit protected mode, limit bits)
       db 0x0           ; base
.data: dw 0xFFFF        ; limit (bits 0-15)
       dw 0x0           ; base (lower 16 bits)
       db 0x0           ; base (upper 16 bits)
       db 10010010b     ; access flags (= present, code, read/write)
       db 11001111b     ; more flags (= byte granularity, 4KiB blocks, 32bit protected mode, limit bits)
       db 0x0           ; base
.desc: dw $ - GDT - 1   ; table size
       dd GDT           ; table start

;================;
; ERROR HANDLING ;
;================;

error:
  mov si, error.message
  mov ah, 0xE
  mov bh, 0
@@:
  lodsb
  or al, al
  jz @f
  int 0x10
  jmp @b
@@:
  cli
  hlt

  .message: db "ERROR: 0x"
  .code:    db "?", 0
  .length:  db $ - error.message

;===========;
;  PADDING  ;
;===========;

if ($ - $$) > 510
  bits = 16
  display "Bytes over the 510 limit: 0x"
  repeat bits/4
    d = '0' + (($ - $$) - 510) shr (bits-%*4) and 0x0F
    if d > '9'
      d = d + 'A'-'9'-1
    end if
    display d
  end repeat

  assert ($ - $$) <= 510
else
  bits = 16
  display "Bytes to spare: 0x"
  repeat bits/4
    d = '0' + (510 - ($ - $$)) shr (bits-%*4) and 0x0F
    if d > '9'
      d = d + 'A'-'9'-1
    end if
    display d
  end repeat
end if

times 510-($-$$) db 0
dw 0xAA55
