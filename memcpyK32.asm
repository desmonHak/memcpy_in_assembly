; https://www.felixcloutier.com/x86/movs:movsb:movsw:movsd:movsq
; https://stackoverflow.com/questions/8258300/in-memory-copying-in-assembly

; __cdecl void *_memcpyK32(
;     void *dest,       -> [esp+4]
;     const void *src,  -> [esp+8]
;     size_t len        -> [esp+12]
; );
global _memcpyK32

section .text
_memcpyK32:
    push esi
    push edi
    push ebx

    mov edi, [esp+16]  ; dest
    mov esi, [esp+20]  ; src
    mov ecx, [esp+24]  ; len

    mov eax, edi       ; Guardar el puntero de destino original para retornarlo

    cmp ecx, 4
    jb .byte_copy      ; Si len < 4, copiar byte por byte

    ; Alinear el destino a 4 bytes si es necesario
    mov edx, edi
    and edx, 3
    jz .aligned_copy
    neg edx
    add edx, 4
    sub ecx, edx
    .align_loop:
        mov bl, [esi]
        mov [edi], bl
        inc esi
        inc edi
        dec edx
        jnz .align_loop

.aligned_copy:
    mov edx, ecx
    shr ecx, 2         ; ecx = número de dwords a copiar
    and edx, 3         ; edx = bytes restantes
    rep movsd          ; Copiar dwords

    mov ecx, edx       ; Preparar para copiar bytes restantes

.byte_copy:
    rep movsb          ; Copiar bytes restantes

    pop ebx
    pop edi
    pop esi
    ret
