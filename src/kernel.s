;; vim:filetype=fasm

use64

jmp _start

; Copied from https://wiki.osdev.org/Setting_Up_Long_Mode#Sample
; to prove that everything works as expected
_start:
  cli                           ; Clear the interrupt flag.
  mov ax, 0x10                  ; Set the A-register to the data descriptor.
  mov ds, ax                    ; Set the data segment to the A-register.
  mov es, ax                    ; Set the extra segment to the A-register.
  mov fs, ax                    ; Set the F-segment to the A-register.
  mov gs, ax                    ; Set the G-segment to the A-register.
  mov ss, ax                    ; Set the stack segment to the A-register.
  mov edi, 0xB8000              ; Set the destination index to 0xB8000.
  mov rax, 0x1F201F201F201F20   ; Set the A-register to 0x1F201F201F201F20.
  mov ecx, 500                  ; Set the C-register to 500.
  rep stosq                     ; Clear the screen.
  hlt                           ; Halt the processor.
