# memcpy_in_assembly
Un Memcpy en ensamblador puro para x64 usando las extensiones SEE, AVX y AVX512F para NASM.

----

### memcpy 1:

La subrutina `check_support` comprobara que extensiones admite su CPU, en base a eso, se usara `loop_512`, `loop_256` o `loop_128`, si no se admitiera ninguna de las extesiones, se usaria `small_copy`.
Ademas, en caso de que se admita `AVX512F` solo se procedera a su uso si la cantidad de memoria a copiar, es un bloque mayor de 512 bytes, de caso contrario, se usara las versiones `loop_256` o `loop_128`, o en caso de ser un buffer menor a 128bytes, se usara `small_copy`.

----

### memcpy 2

Esta segunda version se optimizo para que usara instrucciones que esperan que este alineada la memoria, en caso contrario se realiza la alineacion a 16, 32 o 64bytes. Ademas se evitar el llamado reiterado de la subrutina comprobadora de extensiones, y solo se llamara una vez por mas que se ejecute esta funcion memcpy

----
