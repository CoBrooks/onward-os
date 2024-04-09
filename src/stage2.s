;; vim:filetype=fasm

use16
org 0x7E00

jmp _start

drive_num: db 0
kernel_offset: dd 0
kernel_fs_ptr: dd 0
clusters:
  .bin: dw 0
  .fs:  dw 0

_start:
  mov byte [drive_num], dl

  ;; read extended memory map
  mov edi, mmap.buffer
  xor ebx, ebx
  xor eax, eax
  mov eax, 0xE820
  mov edx, 0x534D4150
  mov ecx, 24

@@:
  int 0x15
  mov esi, errors.mmap
  jc error

  add edi, 20
  mov eax, 0xE820

  inc byte [mmap.entries]

  or  ebx, ebx
  jnz @b
@@:

  ;; find place for kernel.bin and kernel.fs to live
  xor ecx, ecx
@@:
  mov  eax, ecx
  imul eax, 0x14

  ; only look at free memory regions
  cmp  dword [mmap.buffer+eax+0x10], 1
  jne .over

  ; only look at memory above 1MB, but below 4GB
  cmp dword [mmap.buffer+eax], 0xFFFFF
  jb .over

  ; only look at memory regions of length >= 1GB
  cmp dword [mmap.buffer+eax+0x8], 0x3FFFFFFF
  ja .done
  ; upper 32 bits
  cmp dword [mmap.buffer+eax+0xC], 0x0
  jz .over

.done:
  mov esi, [mmap.buffer+eax]
  mov [kernel_offset], esi

  jmp @f
.over:
  inc cl
  cmp cl, byte [mmap.entries]
  jb  @b
@@:


  ;; find kernel.bin and kernel.fs in fs

  ; LBA of root dir
  ; = (fat_count * sectors_per_fat) + reserved_sectors
  ; = (2 * 64) + 4
  ; = 132
  mov ax, 132
  
  ; Size of root dir in sectors
  ; = ceil((dir_entries_count * 32) / bytes_per_sector)
  ; = 32
  mov cl, 32

  ; Read root dir
  mov  dl, [drive_num]
  mov  bx, root_dir
  call disk_read
  
  ; Find kernel.bin
  mov  esi, strings.kernel_bin
  mov  edi, root_dir
  call find_file
  mov  esi, errors.file_not_found
  jc   error
  mov  word [clusters.bin], ax
  
  ; Find kernel.fs
  mov  esi, strings.kernel_fs
  mov  edi, root_dir
  call find_file
  mov  esi, errors.file_not_found
  jc   error
  mov  word [clusters.fs], ax

  ;; load 'em into memory
  mov  edi, [kernel_offset]
  mov  ax, word [clusters.bin]
  call load_file

  mov [kernel_fs_ptr], edi

  mov  ax, word [clusters.fs]
  call load_file

  ;; enter protected mode
  ; disable software interrupts + non-maskable interrupts
  cli
  in  al, 0x70
  or  al, 0x8
  out 0x70, al

  lgdt [GDT32.desc]

  mov eax, cr0
  or  eax, 1
  mov cr0, eax

  jmp 0x8:@f

use32
@@:
  mov ax, 0x10
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax

  ;; enter long mode
  ; clear pagination tables
  mov edi, 0x1000
  mov cr3, edi
  xor eax, eax
  mov ecx, 4096
  rep stosd
  mov edi, cr3

  ; create page tables (https://wiki.osdev.org/Setting_Up_Long_Mode#Setting_up_the_Paging)
  mov dword [edi], 0x2003 ; ...3 = page is present + r/w
  add edi, 0x1000
  mov dword [edi], 0x3003
  add edi, 0x1000
  mov dword [edi], 0x4003
  add edi, 0x1000

  ; identity map first 2MB of physical memory
  mov ebx, 0x00000003
  mov ecx, 512
@@:
  mov  dword [edi], ebx
  add  ebx, 0x1000
  add  edi, 8
  loop @b

  ; enable PAE-paging
  mov eax, cr4
  or  eax, 0x20
  mov cr4, eax

  ; enter long mode
  mov ecx, 0xC0000080
  rdmsr
  or eax, 0x100
  wrmsr

  mov eax, cr0
  or  eax, (1 shl 31)
  mov cr0, eax

  lgdt [GDT64.desc]
  jmp 0x8:@f

use64
@@:
  ;; jump to kernel.bin w/ location of kernel.fs in a register
  movsxd rsi, dword [kernel_fs_ptr]
  movsxd rdi, dword [kernel_offset]
  jmp rdi

use16

; https://wiki.osdev.org/GDT_Tutorial#Basics
GDT32: dd 0,0           ; null entry
.code: dw 0xFFFF        ; limit (bits 0-15)
       dw 0x0           ; base (lower 16 bits)
       db 0x0           ; base (upper  8 bits)
       db 10011010b     ; access flags
       db 11001111b     ; more flags + upper limit bits
       db 0x0           ; base
.data: dw 0xFFFF        ; limit (bits 0-15)
       dw 0x0           ; base (lower 16 bits)
       db 0x0           ; base (upper  8 bits)
       db 10010010b     ; access flags
       db 11001111b     ; more flags + upper limit bits
       db 0x0           ; base
.desc: dw $ - GDT32 - 1 ; table size
       dd GDT32         ; table start

PRESENT  equ (1 shl 7)
NOT_SYS  equ (1 shl 4)
EXEC     equ (1 shl 3)
DC       equ (1 shl 2)
RW       equ (1 shl 1)
ACCESSED equ (1 shl 0)

GRAN_4K   equ (1 shl 7)
SZ_32     equ (1 shl 6)
LONG_MODE equ (1 shl 5)

GDT64: dd 0,0                               ; null entry
.code: dw 0xFFFF                            ; limit (bits 0-15)
       dw 0x0                               ; base (lower 16 bits)
       db 0x0                               ; base (upper  8 bits)
       db PRESENT or NOT_SYS or EXEC or RW  ; access flags
       db GRAN_4K or LONG_MODE or 0xF       ; more flags + upper limit bits
       db 0x0                               ; base
.data: dw 0xFFFF                            ; limit (bits 0-15)
       dw 0x0                               ; base (lower 16 bits)
       db 0x0                               ; base (upper  8 bits)
       db PRESENT or NOT_SYS or RW          ; access flags
       db GRAN_4K or SZ_32 or 0xF           ; more flags + upper limit bits
       db 0x0                               ; base
.tss:  dd 0x0
       dd 0x00CF8900
.desc: dw $ - GDT64 - 1                     ; table size
       dd GDT64                             ; table start

strings:
  .kernel_bin: db "KERNEL  BIN"
  .kernel_fs:  db "KERNEL  FS "

;============;
; DISK UTILS ;
;============;

DAP:        db 0x10
            db 0x00
.sectors:   rw 1
.b_offset:  rw 1
.b_segment: rw 1
.lower_lba: rd 1
.upper_lba: dd 0

; Reads sectors from a disk
;
; input:
; - ax: LBA address
; - cl: number of sectors (<128)
; - dl: drive number
; - es:bx: out address
disk_read:
  pusha
  
  mov [DAP.sectors], cx
  mov [DAP.b_offset], bx
  mov [DAP.b_segment], es
  mov word [DAP.lower_lba], ax

  mov si, DAP
  mov ah, 0x42
  mov dl, 0x80
  int 0x13
  
  mov esi, errors.disk_read
  jc error

  popa
  ret

; Finds the cluster containing a given file
; input:
; - esi: filename ptr
; - edi: ptr to FAT
; output:
; - ax: cluster
; error:
; - sets carry flag
find_file:
  push bx
  push cx
  push di

  xor bx, bx
@@:
  mov  cx, 11
  push di
  push si
  repe cmpsb
  pop  si
  pop  di
  je   @f

  add di, 32 ; size of entry
  inc bx
  cmp bx, 0x200 ; dir_entries_count
  jl  @b

  ; not found
  stc
  jmp .done
@@:
  mov ax, [di + 26]
.done:
  pop di
  pop cx
  pop bx
  ret

; Loads a cluster into memory
; input:
; - ax: cluster number
; - edi: addr of destination
; outputs:
; - updates ax with next cluster number
; - increments edi with number of bytes written
load_file:
  push ax

  ; convert cluster to sector
  sub ax, 2
  shl ax, 2
  add ax, 164 ; root_dir_start + root_dir_size = 132 + 32

  ; read sector
  mov cl, 1
  mov dl, [drive_num]
  mov bx, buffer
  call disk_read

  ; copy sector to edi
  xor ecx, ecx
@@:
  mov bl, byte [buffer+ecx]
  mov [es:edi+ecx], bl

  inc cx
  cmp cx, 512
  jb  @b
@@:

  ; get next cluster
  xor edx, edx
  pop ax
  shl ax, 1
  mov cx, 512
  div cx ; ax = sector, dx = offset

  push edx
  add ax, 4 ; add reserved sectors to get FAT start
  mov cx, 1
  mov dl, [drive_num]
  mov bx, buffer
  call disk_read
  pop edx

  add edi, 512

  ; next cluster
  mov ax, word [buffer+edx]
  cmp ax, 0xFF
  jb  load_file

.done:
  ret

;=============;
; DEBUG UTILS ;
;=============;

cursor:
  .x: db 0
  .y: db 0

; Prints a character to the screen at the cursor position (assumes 80x25 display)
; input:
; - ah: CGA color
; - al: ascii character
putc:
  pusha

  cmp al, 10
  jne @f

  inc  byte [cursor.y]
  mov  byte [cursor.x], 0
  jmp .done
@@:
  push ax
  mov   edi, 0xB8000
  movzx ax, byte [cursor.y]
  mov   cx, 160
  mul   cx
  xchg  ax, cx
  movzx ax, byte [cursor.x]
  shl   ax, 1  
  add   ax, cx
  add   di, ax

  pop ax
  mov [edi], ax

  inc byte [cursor.x]

.done:
  popa
  ret

newline:
  pusha
  
  mov  al, 10
  call putc

  popa
  ret

; Prints a string at the cursor position
; input:
; - esi: string ptr
; - ah: CGA color
puts:
  pusha
@@:
  lodsb
  or al, al
  jz @f

  call putc
  jmp @b
@@:
  inc byte [cursor.y]
  mov byte [cursor.x], 0

  popa
  ret

; Prints a hexadecimal number
; input:
; - ebx: number
itoa:
  pusha

  ; "0x" prefix
  mov ah, 0x7
  mov al, '0'
  call putc
  mov al, 'x'
  call putc
  
  mov cx, 8 ; 32 bits / 4
@@:
  rol ebx, 4

  mov al, bl
  and al, 0xF
  
  cmp  al, 0xA
  jl  .num
  sub  al, 0xA
  add  al, 'A'
  jmp .over
.num:
  add al, '0'
.over:
  mov ah, 0x7

  call putc

  loop @b
@@:
  mov al, 10
  call putc
  popa
  ret

;================;
; ERROR HANDLING ;
;================;

errors:
  .todo: db "unimplemented", 0
  .mmap: db "unable to read memory map", 0
  .disk_read: db "unable to read from disk", 0
  .file_not_found: db "unable to find file", 0
  .kernel_load: db "unable to load kernel", 0

error:
  ; prefix
  push esi
  mov esi, error.prefix
  mov ah, 0xC
@@:
  lodsb
  or al, al
  jz @f

  call putc
  jmp @b
@@:
  ;message
  pop esi
  mov ah, 0x7
  call puts
  ; stop program
  cli
  hlt

  .prefix:  db "ERROR: ", 0

;===========;
;  PADDING  ;
;===========;

if ($ - $$) > 1536
  bits = 16
  display "(stage2) Bytes over the 1536 limit: 0x"
  repeat bits/4
    d = '0' + (($ - $$) - 1536) shr (bits-%*4) and 0x0F
    if d > '9'
      d = d + 'A'-'9'-1
    end if
    display d
  end repeat

  assert ($ - $$) <= 1536
else
  bits = 16
  display "(stage2) Bytes to spare: 0x"
  repeat bits/4
    d = '0' + (1536 - ($ - $$)) shr (bits-%*4) and 0x0F
    if d > '9'
      d = d + 'A'-'9'-1
    end if
    display d
  end repeat
end if

times 1536-($-$$) db 0

mmap:
  .buffer:  rb 160
  .entries: rb 1

root_dir: rb 32

buffer:
