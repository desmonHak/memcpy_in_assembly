; Licencia Apache, Versión 2.0 con Modificación
; 
; Copyright 2023 Desmon (David)
; 
; Se concede permiso, de forma gratuita, a cualquier persona que obtenga una copia de este 
; software y archivos de documentación asociados (el "Software"), para tratar el Software 
; sin restricciones, incluidos, entre otros, los derechos de uso, copia, modificación, 
; fusión, publicación, distribución, sublicencia y/o venta de copias del Software, y para 
; permitir a las personas a quienes se les proporcione el Software hacer lo mismo, sujeto 
; a las siguientes condiciones:
; El anterior aviso de copyright y este aviso de permiso se incluirán en todas las copias 
; o partes sustanciales del Software.
; EL SOFTWARE SE PROPORCIONA "TAL CUAL", SIN GARANTÍA DE NINGÚN TIPO, EXPRESA O IMPLÍCITA, 
; INCLUYENDO PERO NO LIMITADO A LAS GARANTÍAS DE COMERCIABILIDAD, IDONEIDAD PARA UN PROPÓSITO 
; PARTICULAR Y NO INFRACCIÓN. EN NINGÚN CASO LOS TITULARES DEL COPYRIGHT O LOS TITULARES DE 
; LOS DERECHOS DE AUTOR SERÁN RESPONSABLES DE NINGÚN RECLAMO, DAÑO U OTRA RESPONSABILIDAD, 
; YA SEA EN UNA ACCIÓN DE CONTRATO, AGRAVIO O DE OTRA MANERA, QUE SURJA DE, FUERA DE O EN 
; CONEXIÓN CON EL SOFTWARE O EL USO U OTRO TIPO DE ACCIONES EN EL SOFTWARE.
; Además, cualquier modificación realizada por terceros se considerará propiedad del titular 
; original de los derechos de autor. Los titulares de derechos de autor originales no se 
; responsabilizan de las modificaciones realizadas por terceros.
; Queda explícitamente establecido que no es obligatorio especificar ni notificar los cambios 
; realizados entre versiones, ni revelar porciones específicas de código modificado.
;
; __attribute__ ((
;     access(write_only, 1), 
;     access(read_only, 2),
;     hot
; )) __fastcall void* FuncArch(memcpyK, 64) (
;     void *dest,       -> rcx
;     const void *src,  -> rdx
;     size_t len        -> r8
; );

global memcpyK64

%define AVX512F_SUPPORT 3
%define AVX_SUPPORT     2
%define SEE_SUPPORT     1

section .text
check_support:
    ; para bloques de 128, 256 y 512 bytes usar: https://www.felixcloutier.com/x86/movups
    ; para bloques menores de 128bytes usar: https://www.felixcloutier.com/x86/movs:movsb:movsw:movsd:movsq
    ; movaps espera que la memoria este alineada, en caso contrario usar movups 
    push rbp
    mov rbp, rsp
    
    ; https://xem.github.io/minix86/manual/intel-x86-and-64-manual-vol1/o_7281d5ea06a5b67a-371.html
    ;
    ; se proporciona la siguiente secuencia. Se recomienda enfáticamente seguir esta secuencia.
    ; 1) Detectar CPUID.1:ECX.OSXSAVE[bit 27] = 1 (XGETBV habilitado para uso de la aplicación).
    ; 2) Ejecutar XGETBV y verificar que XCR0[7:5] = ‘111b’ (estado OPMASK, los 256 bits superiores de ZMM0-ZMM15 y
    ; estado ZMM16-ZMM31 están habilitados por el SO) y que XCR0[2:1] = ‘11b’ (estado XMM y estado YMM están habilitados por el SO).
    ; 3) Verifique que CPUID.0x7.0:EBX.AVX512F[bit 16] = 1, CPUID.0x7.0:EBX.AVX512CD[bit 28] = 1 y
    ; CPUID.0x7.0:EBX.AVX512VL[bit 31] = 1
    mov eax, 1
    bt ecx, 27
       jnc .no_avx512_support

    ; Paso 2: Ejecutar XGETBV y verificar XCR0
    xor ecx, ecx    ; ecx = 0, selecciona XCR0
    xgetbv
    and eax, 0b11100110  ; Máscara para bits 7:5 y 2:1
    cmp eax, 0b11100110  ; Verifica si los bits requeridos están establecidos
    jne .no_avx512_support

    ; Paso 3: Verificar soporte de AVX512F, AVX512CD y AVX512VL
    mov eax, 7
    xor ecx, ecx
    cpuid

    ; comprovar que extensiones AVX512 estan soportadas
    bt ecx, 28              ; AVX512CD
    jnc .no_AVX512CD_support
    bt ebx, 31              ; AVX512VL
    jnc .no_AVX512VL_support
    bt ebx, 16              ; AVX512F
    jnc .no_AVX512F_support

    ; Si llegamos aquí, AVX-512 está soportado
    mov eax, AVX512F_SUPPORT
    jmp next_code

    .no_avx512_support:
        .no_AVX512F_support:
            mov r10, 1 ; devolver 1 como code error
        .no_AVX512CD_support:
            mov r10, 2 ; devolver 2 como code error
        .no_AVX512VL_support:
            mov r10, 3 ; devolver 3 como code error

    ; si AVX512F no se admite loop_512 no se puede usar
    ; comprobar si se soporta AVX
    mov eax, 1
    xor ecx, ecx
    cpuid

    ; avxSupportted = cpuinfo[2] & (1 << 28) || false;
	; bool osxsaveSupported = cpuinfo[2] & (1 << 27) || false;
    bt ecx, 28
    jnc .no_AVX_support    ; AVX no es admitido
    bt ecx, 27             
    jnc .no_AVX_support    ; OSXSAVE / XGETBV no es admitido (necesario para saber si el SO lo admite)

    xor ecx, ecx
    xgetbv
    and eax, 6
    cmp eax, 6
    jne .no_AVX_support   ; el SO no soporta AVX

    mov eax, AVX_SUPPORT ; AVX512 no soportado, pero se admite AVX
    jmp next_code        ; salir de aqui y trabajar con AVX

    ; si no se admite AVX se comprueba si se soporta SEE
    .no_AVX_support:
        mov r10, 4            ; devolver 4 como code error

	; sseSupportted		= cpuinfo[3] & (1 << 25) || false;
	; sse2Supportted    = cpuinfo[3] & (1 << 26) || false;
	; sse3Supportted    = cpuinfo[2] & (1 << 0) || false;
	; ssse3Supportted   = cpuinfo[2] & (1 << 9) || false;
	; sse4_1Supportted	= cpuinfo[2] & (1 << 19) || false;
	; sse4_2Supportted	= cpuinfo[2] & (1 << 20) || false;
    ; :"=a" (cpuinfo[0]), "=D" (cpuinfo[1]), "=c" (cpuinfo[2]), "=d" (cpuinfo[3])
    bt edx, 25            
    jnc .no_SEE_support   ; no se soporta SEE
    bt edx, 24
    jnc .no_SEE_support   ; Bit 24 de EDX indica soporte para FXSAVE/FXRSTOR, si 0 saltar

    mov eax, SEE_SUPPORT ; AVX512 ni AVX soportado, pero se admite SEE
    jmp next_code        ; salir de aqui y trabajar con SEE

    .no_SEE_support:
        mov r10, 5            ; devolver 5 como code error

    next_code:    
    mov r10, rax ; obtener la extension de soporte mas alta
    ; Guardar el puntero de destino original
    mov rsp, rbp
    pop rbp
    ret

memcpyK64:
    push rcx
    push rdx
    push r8
    call check_support
    pop r8
    pop rdx
    pop rcx
    push rcx

    cmp r8, 128     ; Comprobar si len es menor que 128 bytes
    jb small_copy

    ; Ahora puedes usar [rbp-8] para la primera variable local de 8 bytes
    ; y [rbp-16] para la segunda variable local de 8 bytes

    push rbp
    mov rbp, rsp
    sub rsp, 48  ; Reserva 48 bytes para variables locales (6 variables de 8 bytes)

    ; Definir las variables locales
    mov qword [rbp-8],  1 << (SEE_SUPPORT+3)
    mov qword [rbp-16], 0b1111
    mov qword [rbp-24], 1 << (AVX_SUPPORT+3)
    mov qword [rbp-32], 0b11111
    mov qword [rbp-40], 1 << (AVX512F_SUPPORT+3)
    mov qword [rbp-48], 0b111111

    xor r11, r11  ; Limpiar r11
    xor r12, r12  ; Limpiar r12

    cmp r10, AVX512F_SUPPORT
    cmove r11, [rbp-8]
    cmove r12, [rbp-16]
    cmp r10, AVX_SUPPORT
    cmove r11, [rbp-24]
    cmove r12, [rbp-32]
    cmp r10, SEE_SUPPORT
    cmove r11, [rbp-40]
    cmove r12, [rbp-48]

    mov rsp, rbp
    pop rbp

    .large_copy:
        ; Alinear el destino a 16 bytes si es necesario
        mov rax, rcx         
        and rax, r12      ; obtiene un nibble de 4 bits el cual indica que memoria falta por alinear
        jz .aligned_copy     ; si ZF = 1, entonces rax es un múltiplo de 16
        
        neg rax              ; vuelve rax en un valor negativo
        add rax, r11         ; Suma 16 al valor negado en rax.
                             ; Si rax era 0 (ya alineado), ahora será 16.
                             ; Si rax era, por ejemplo, -1 (faltaba 1 byte para alineación), ahora será 15.

        sub r8, rax          ; se resta el valor resultante de r8, este sera el contador de bytes para .aligned_copy
                             ; el valor rax se usara como contador de bytes para .align_loop
        
    ; Copiar bytes para alinear
    .align_loop:            
        mov dl, [rdx]
        mov [rcx], dl
        inc rcx
        inc rdx
        dec rax
        jnz .align_loop

    .aligned_copy:
        cmp r10, AVX512F_SUPPORT
        jnz .test_loop_AVX_text1 ; si no se soporta AVX512F, saltar a AVX
        cmp r8, 512
        jge .loop_512    ; comprobar si es mayor que 512 bytes

        .test_loop_AVX_text1:
            cmp r10, AVX_SUPPORT
            jnz .test_loop_SEE_text1 ; si no se soporta AVX, saltar a SEE
            ;cmp r8, 256     
            ;jge .loop_256    ; comprobar si es mayor que 256 bytes
                             ; sino len esta entre 256 y 128 bytes, se aplica loop_128
            jmp .loop_256 ; si se soporta AVX, saltar a loop_256

        .test_loop_SEE_text1:
            cmp r10, SEE_SUPPORT
            jnz small_copy ; si no se soporta SEE, saltar a byte a byte
            jmp .loop_128 ; si se soporta SEE, saltar a loop_128

        

        ; Copiar bloques de 128 bytes
        .loop_128: ; requiere SEE
            prefetchnta [rdx + 256]
            ; La instrucción prefetchnta [rdx + 256] es una instrucción de prefetch (precarga) que se utiliza para optimizar 
            ; el rendimiento de la memoria en operaciones de copia o acceso a datos.
            ; Aquí está lo que hace específicamente:
            ;  - prefetchnta: Esta es una variante de la instrucción de prefetch que significa "prefetch non-temporal aligned".
            ;       "Non-temporal" sugiere que los datos probablemente no se mantendrán en la caché por mucho tiempo.
            ;       "Aligned" indica que la dirección de memoria debería estar alineada para un rendimiento óptimo.
            ; [rdx + 256]: Esta parte especifica la dirección de memoria que se va a precargar. 
            ;           Es la dirección contenida en el registro rdx más un desplazamiento de 256 bytes.
            ; Lo que hace esta instrucción:
            ; Inicia la carga de una línea de caché desde la dirección de memoria [rdx + 256] a la caché del procesador.
            ; Sugiere al procesador que estos datos probablemente se usarán pronto, pero que no es necesario mantenerlos en la caché por mucho tiempo después de su uso.
            ; No bloquea la ejecución. El procesador continúa ejecutando las siguientes instrucciones mientras se realiza la precarga en segundo plano.
            ; No genera excepciones si la dirección no es válida o accesible.
            ; El propósito de usar prefetchnta en este contexto es:
            ;  - Reducir la latencia de acceso a memoria al precargar datos que se necesitarán pronto.
            ;  - Optimizar el uso de la caché al sugerir que estos datos no necesitan permanecer en la caché por mucho tiempo, lo cual es útil en 
            ;       operaciones de copia de grandes bloques de memoria.
            ;  - En el caso específico de una función de copia de memoria, precargar datos adelantados 
            ;       (256 bytes en este caso) puede ayudar a que los datos estén disponibles en la caché cuando se necesiten, 
            ;       reduciendo los tiempos de espera por acceso a memoria principal.
            ;  - Esta técnica es especialmente útil en operaciones de copia de grandes bloques de memoria, donde puede mejorar 
            ;       significativamente el rendimiento al reducir los tiempos de espera por acceso a memoria.
            ; 
            ; Anticipación:
            ;       Al precargar datos 256 bytes por delante, estamos anticipando las próximas iteraciones del bucle.
            ;       Esto significa que mientras el procesador está trabajando en el bloque actual de 128 bytes, ya está cargando datos para las próximas iteraciones.
            ; Latencia de memoria:
            ;       La carga de datos desde la memoria principal a la caché puede tomar varios ciclos de reloj.
            ;       Al iniciar la carga con anticipación, se reduce la probabilidad de que el procesador tenga que esperar por los datos en futuras iteraciones.
            ; Paralelismo:
            ;       Los procesadores modernos pueden realizar múltiples operaciones simultáneamente.
            ;       Mientras se están copiando los 128 bytes actuales, el procesador puede estar precargando los siguientes 256 bytes en paralelo.
            ; Tamaño de línea de caché:
            ;       Muchos procesadores tienen líneas de caché de 64 bytes.
            ;       Precargar 256 bytes asegura que se están cargando varias líneas de caché completas.
            ; Optimización para bucles:
            ;       En un bucle que copia 128 bytes por iteración, precargar 256 bytes significa que estamos preparando datos para las próximas dos iteraciones.
            ; Equilibrio entre anticipación y uso de caché:
            ;       Precargar demasiado lejos podría desplazar datos útiles de la caché.
            ;       256 bytes es un compromiso razonable entre anticipación y eficiencia en el uso de la caché.
            ; Flexibilidad para diferentes tamaños de copia:
            ;       Aunque el bucle copia 128 bytes por vez, el tamaño total a copiar podría no ser un múltiplo exacto de 128.
            ;       Precargar 256 bytes proporciona un margen adicional para estos casos.


            movups xmm0, [rdx]
            movups xmm1, [rdx + 16]
            movups xmm2, [rdx + 32]
            movups xmm3, [rdx + 48]
            movups xmm4, [rdx + 64]
            movups xmm5, [rdx + 80]
            movups xmm6, [rdx + 96]
            movups xmm7, [rdx + 112]
            
            movups [rcx],       xmm0 ; 128bits  = 16bytes
            movups [rcx + 16],  xmm1 ; 256bits  = 32bytes
            movups [rcx + 32],  xmm2 ; 384bits  = 48bytes
            movups [rcx + 48],  xmm3 ; 512bits  = 64bytes
            movups [rcx + 64],  xmm4 ; 640bits  = 80bytes
            movups [rcx + 80],  xmm5 ; 768bits  = 96bytes
            movups [rcx + 96],  xmm6 ; 896bits  = 112bytes
            movups [rcx + 112], xmm7 ; 1024bits = 128bytes
            
            add rcx, 128
            add rdx, 128
            sub r8, 128
            cmp r8, 128
            jae .loop_128
            jmp small_copy

    .loop_256: ; requiere AVX
        prefetchnta [rdx + 512]
            vmovups ymm0, [rdx]
            vmovups ymm1, [rdx + 32]
            vmovups ymm2, [rdx + 64]
            vmovups ymm3, [rdx + 96]
            vmovups ymm4, [rdx + 128]
            vmovups ymm5, [rdx + 160]
            vmovups ymm6, [rdx + 192]
            vmovups ymm7, [rdx + 224] ; 4.2048bits = 256bytes
            
            vmovups [rcx],       ymm0 ; 
            vmovups [rcx + 32],  ymm1 ; 
            vmovups [rcx + 64],  ymm2 ; 
            vmovups [rcx + 96],  ymm3 ; 
            vmovups [rcx + 128], ymm4 ; 
            vmovups [rcx + 160], ymm5 ; 
            vmovups [rcx + 192], ymm6 ; 
            vmovups [rcx + 224], ymm7 ; 2048bits = 256bytes
            
            add rcx, 256
            add rdx, 256
            sub r8, 256
            cmp r8, 256
            jae .loop_256
            jmp small_copy

    .loop_512: ; requiere AVX512F
        prefetchnta [rdx + 256]
            vmovups zmm0, [rdx]
            vmovups zmm1, [rdx + 64]
            vmovups zmm2, [rdx + 128]
            vmovups zmm3, [rdx + 192]
            vmovups zmm4, [rdx + 256]
            vmovups zmm5, [rdx + 320]
            vmovups zmm6, [rdx + 384]
            vmovups zmm7, [rdx + 448] ; 4.096bits = 512bytes
            
            vmovups [rcx],       zmm0 ; 
            vmovups [rcx + 64],  zmm1 ; 
            vmovups [rcx + 128], zmm2 ; 
            vmovups [rcx + 192], zmm3 ; 
            vmovups [rcx + 256], zmm4 ; 
            vmovups [rcx + 320], zmm5 ; 
            vmovups [rcx + 384], zmm6 ; 
            vmovups [rcx + 448], zmm7 ; 4.096bits = 512bytes
            
            add rcx, 512
            add rdx, 512
            sub r8, 512
            cmp r8, 512
            jae .loop_512

    small_copy:
        ; Copiar bytes restantes
        mov     rdi, rcx   ; memoria a poner a 0
        mov     rcx, r8    ; decrementador
        mov     rax, rdx   ; valor que escribir
        rep movsb


        ; Restaurar el puntero de destino original y devolverlo
        pop rax

        ret
