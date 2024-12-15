# memcpy_in_assembly
Un Memcpy en ensamblador puro para x64 usando las extensiones SEE, AVX y AVX512F para NASM.

----

### memcpy 1:

La subrutina `check_support` comprobara que extensiones admite su CPU, en base a eso, se usara `loop_512`, `loop_256` o `loop_128`, si no se admitiera ninguna de las extesiones, se usaria `small_copy`.
Ademas, en caso de que se admita `AVX512F` solo se procedera a su uso si la cantidad de memoria a copiar, es un bloque mayor de 512 bytes, de caso contrario, se usara las versiones `loop_256` o `loop_128`, o en caso de ser un buffer menor a 128bytes, se usara `small_copy`.

----

### memcpy 2

Esta segunda version se optimizo para que usara instrucciones que esperan que este alineada la memoria, en caso contrario se realiza la alineacion a 16, 32 o 64bytes. Ademas se evitar el llamado reiterado de la subrutina comprobadora de extensiones, y solo se llamara una vez por mas que se ejecute esta funcion memcpy.

Esta funcion da mejor rendimiento en que el memcpy de C, en Windows.
Se testeo esto usando el compilador TDM. con el siguiente hardware:

```c
Socket 1			ID = 0
	Number of cores		16 (max 16)
	Number of threads	24 (max 24)
	Hybrid			  yes, 2 coresets
	Core Set 0		P-Cores, 8 cores, 16 threads
	Core Set 1		E-Cores, 8 cores, 8 threads
	Manufacturer		GenuineIntel
	Name                    Intel Core i7 13700KF
	Codename                Raptor Lake
	Specification		13th Gen Intel(R) Core(TM) i7-13700KF
	Package (platform ID)	Socket 1700 LGA (0x1)
	CPUID                   6.7.1
	Extended CPUID          6.B7
	Core Stepping           B0
	Technology              10 nm
	TDP Limit               125.0 Watts
	Tjmax                   100.0 �C
	Core Speed              2593.7 MHz
	Multiplier x Bus Speed	26.0 x 99.8 MHz
	Base frequency (cores)	99.8 MHz
	Base frequency (mem.)	99.8 MHz
	Instructions sets	MMX, SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, EM64T, AES, AVX, AVX2, FMA3, SHA
	Microcode Revision	0x123
	L1 Data cache           8 x 48 KB (12-way, 64-byte line) + 8 x 48 KB (12-way, 64-byte line)
	L1 Instruction cache	8 x 32 KB (8-way, 64-byte line) + 8 x 32 KB (8-way, 64-byte line)
	L2 cache                8 x 2 MB (16-way, 64-byte line) + 2 x 2 MB (16-way, 64-byte line)
	L3 cache                30 MB (12-way, 64-byte line)
	Preferred cores         2 (#4, #5)
	Max CPUID level         0000001Fh
	Max CPUID ext. level	80000008h
	FID/VID Control		yes

```

Puede usar la flag `-D` para especificar para que plataforma quiere compiar: `WIN64-WIN32-ELF64-ELF32`, para compilar para windows use `-DWIN64` y asi con cada una.

Le version de 32bits no hace distincion entre `WIN64-WIN32-ELF64-ELF32`.

----
