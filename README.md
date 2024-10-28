# memcpy_in_assembly
Un Memcpy en ensamblador puro para x64 usando las extensiones SEE, AVX y AVX512F para NASM.

La subrutina `check_support` comprobara que extensiones admite su CPU, en base a eso, se usara `loop_512`, `loop_256` o `loop_128`, si no se admitiera ninguna de las extesiones, se usaria `small_copy`.
Ademas, en caso de que se admita `AVX512F` solo se procedera a su uso si la cantidad de memoria a copiar, es un bloque mayor de 512 bytes, de caso contrario, se usara las versiones `loop_256` o `loop_128`, o en caso de ser un buffer menor a 128bytes, se usara `small_copy`
