global memcpyK64

default rel  ; direcionamiento relativo
section .data
    support db 0x0

section .text

; Constantes para los niveles de soporte
%define NO_SUPPORT 0
%define SSE_SUPPORT 1
%define AVX_SUPPORT 2
%define AVX512F_SUPPORT 3

not_call_detect_cpu_features:
    mov r9, [support]
    jmp detect_cpu_features_continuue

memcpyK64:
    push rbp
    mov rbp, rsp
    push rsi
    push rdi

    %ifdef WIN64
    ; Guardar argumentos
    mov rdi, rcx  ; dest
    mov rsi, rdx  ; src
    mov rdx, r8   ; len
    %elifdef WIN32
    %error "No se admite la arquitectura de 32 bits"
    %elifdef ELF64
    ; para linux:
    %elifdef ELF32
        %error "No se admite la arquitectura de 32 bits"
    %else 
        %error "No se declaro WIN64-WIN32-ELF64-ELF32"
    %endif



    ; Detectar soporte de instrucciones
    mov rax, [support]
    cmp rax, 0
    jnz not_call_detect_cpu_features ; si ya se llamo a detect_cpu_features
    call detect_cpu_features
    mov r9, rax   ; Guardar el nivel de soporte en r9
    mov [support], r9
    detect_cpu_features_continuue:
    

    ; Alinear el destino a 16 bytes si es necesario
    mov rcx, rdi
    and rcx, 15
    jz .aligned_copy
    neg rcx
    add rcx, 16
    sub rdx, rcx
    rep movsb

.aligned_copy:
    cmp rdx, 128
    jb .small_copy

    ; Elegir el método de copia basado en el soporte de CPU
    cmp r9, AVX512F_SUPPORT
    je .avx512f_copy
    cmp r9, AVX_SUPPORT
    je .avx_copy
    cmp r9, SSE_SUPPORT
    je .sse_copy
    jmp .small_copy

.avx512f_copy:
    cmp rdx, 512
    jb .avx_copy
    ; Alinear el destino a 64 bytes si es necesario
    mov rcx, rdi
    and rcx, 63
    jz .avx_loop
    neg rcx
    add rcx, 64
    sub rdx, rcx
    rep movsb
.avx512f_loop:
    prefetchnta [rsi + 1024]
    vmovdqa64 zmm0, [rsi]
    vmovdqa64 zmm1, [rsi+64]
    vmovdqa64 zmm2, [rsi+128]
    vmovdqa64 zmm3, [rsi+192]
    vmovdqa64 zmm4, [rsi+256]
    vmovdqa64 zmm5, [rsi+320]
    vmovdqa64 zmm6, [rsi+384]
    vmovdqa64 zmm7, [rsi+448]
    vmovdqa64 [rdi], zmm0
    vmovdqa64 [rdi+64], zmm1
    vmovdqa64 [rdi+128], zmm2
    vmovdqa64 [rdi+192], zmm3
    vmovdqa64 [rdi+256], zmm4
    vmovdqa64 [rdi+320], zmm5
    vmovdqa64 [rdi+384], zmm6
    vmovdqa64 [rdi+448], zmm7
    add rsi, 512
    add rdi, 512
    sub rdx, 512
    cmp rdx, 512
    jae .avx512f_loop
    jmp .small_copy

.avx_copy:
    cmp rdx, 256
    jb .sse_copy
    ; Alinear el destino a 32 bytes si es necesario
    mov rcx, rdi
    and rcx, 31
    jz .avx_loop
    neg rcx
    add rcx, 32
    sub rdx, rcx
    rep movsb
.avx_loop:
    prefetchnta [rsi + 512]
    vmovdqa ymm0, [rsi]
    vmovdqa ymm1, [rsi+32]
    vmovdqa ymm2, [rsi+64]
    vmovdqa ymm3, [rsi+96]
    vmovdqa ymm4, [rsi+128]
    vmovdqa ymm5, [rsi+160]
    vmovdqa ymm6, [rsi+192]
    vmovdqa ymm7, [rsi+224]
    vmovdqa [rdi], ymm0
    vmovdqa [rdi+32], ymm1
    vmovdqa [rdi+64], ymm2
    vmovdqa [rdi+96], ymm3
    vmovdqa [rdi+128], ymm4
    vmovdqa [rdi+160], ymm5
    vmovdqa [rdi+192], ymm6
    vmovdqa [rdi+224], ymm7
    add rsi, 256
    add rdi, 256
    sub rdx, 256
    cmp rdx, 256
    jae .avx_loop
    vzeroupper
    jmp .small_copy

.sse_copy:
    cmp rdx, 128
    jb .small_copy
    ; Alinear el destino a 16 bytes si es necesario
    mov rcx, rdi
    and rcx, 15
    jz .sse_loop
    neg rcx
    add rcx, 16
    sub rdx, rcx
    rep movsb
.sse_loop:
    prefetchnta [rsi + 256]
    movdqa xmm0, [rsi]
    movdqa xmm1, [rsi+16]
    movdqa xmm2, [rsi+32]
    movdqa xmm3, [rsi+48]
    movdqa xmm4, [rsi+64]
    movdqa xmm5, [rsi+80]
    movdqa xmm6, [rsi+96]
    movdqa xmm7, [rsi+112]
    movdqa [rdi], xmm0
    movdqa [rdi+16], xmm1
    movdqa [rdi+32], xmm2
    movdqa [rdi+48], xmm3
    movdqa [rdi+64], xmm4
    movdqa [rdi+80], xmm5
    movdqa [rdi+96], xmm6
    movdqa [rdi+112], xmm7
    add rsi, 128
    add rdi, 128
    sub rdx, 128
    cmp rdx, 128
    jae .sse_loop

.small_copy:
    mov rcx, rdx
    rep movsb

    pop rdi
    pop rsi
    mov rsp, rbp
    pop rbp
    ret

detect_cpu_features:
    push rbx

    ; Comprobar soporte de CPUID
    pushfq
    pop rax
    mov rbx, rax
    xor rax, 1 << 21
    push rax
    popfq
    pushfq
    pop rax
    push rbx
    popfq
    xor rax, rbx
    jz .no_cpuid

    ; Comprobar soporte de AVX512F
    mov eax, 7
    xor ecx, ecx
    cpuid
    test ebx, 1 << 16
    jz .check_avx

    ; Comprobar si el OS soporta AVX512
    xor ecx, ecx
    xgetbv
    and eax, 0b11100110
    cmp eax, 0b11100110
    jne .check_avx
    mov eax, AVX512F_SUPPORT
    jmp .done

.check_avx:
    ; Comprobar soporte de AVX
    mov eax, 1
    cpuid
    test ecx, 1 << 28
    jz .check_sse

    ; Comprobar si el OS soporta AVX
    xor ecx, ecx
    xgetbv
    and eax, 6
    cmp eax, 6
    jne .check_sse
    mov eax, AVX_SUPPORT
    jmp .done

.check_sse:
    ; Comprobar soporte de SSE
    mov eax, 1
    cpuid
    test edx, 1 << 25
    jz .no_support
    mov eax, SSE_SUPPORT
    jmp .done

.no_cpuid:
.no_support:
    xor eax, eax

.done:
    pop rbx
    ret
