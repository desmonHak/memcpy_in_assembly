; Licencia Apache, Versión 2.0 con Modificación
; 
; Copyright 2023 Desmon (David)
; Se concede permiso, de forma gratuita, a cualquier persona que obtenga una copia de este software y archivos
; de documentación asociados (el "Software"), para tratar el Software sin restricciones, incluidos, entre otros,
; los derechos de uso, copia, modificación, fusión, publicación, distribución, sublicencia y/o venta de copias del
; Software, y para permitir a las personas a quienes se les proporcione el Software hacer lo mismo, sujeto a las
; siguientes condiciones:
; El anterior aviso de copyright y este aviso de permiso se incluirán en todas las copias o partes sustanciales del Software.
; EL SOFTWARE SE PROPORCIONA "TAL CUAL", SIN GARANTÍA DE NINGÚN TIPO, EXPRESA O IMPLÍCITA, INCLUYENDO PERO NO
; LIMITADO A LAS GARANTÍAS DE COMERCIABILIDAD, IDONEIDAD PARA UN PROPÓSITO PARTICULAR Y NO INFRACCIÓN. EN
; NINGÚN CASO LOS TITULARES DEL COPYRIGHT O LOS TITULARES DE LOS DERECHOS DE AUTOR SERÁN RESPONSABLES DE
; NINGÚN RECLAMO, DAÑO U OTRA RESPONSABILIDAD, YA SEA EN UNA ACCIÓN DE CONTRATO, AGRAVIO O DE OTRA MANERA, QUE SURJA
; DE, FUERA DE O EN CONEXIÓN CON EL SOFTWARE O EL USO U OTRO TIPO DE ACCIONES EN EL SOFTWARE.
; Además, cualquier modificación realizada por terceros se considerará propiedad del titular original de los derechos
; de autor. Los titulares de derechos de autor originales no se responsabilizan de las modificaciones realizadas por terceros.
; Queda explícitamente establecido que no es obligatorio especificar ni notificar los cambios realizados entre versiones,
; ni revelar porciones específicas de código modificado.

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
