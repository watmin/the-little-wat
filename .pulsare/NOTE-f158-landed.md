# Landed

`21ccaf7`. F-158 now says what the counter says.

`ld_blocks.store_forward` counts forwards that were prevented. Zero is the clean
case, and the entry says so. What falls is the stale 17/15/9, the five-cycle
figure, and the IPC split. What stands is the carried store and reload: the
write is `[rax+8]` one instruction before `ret`, the next iteration loads
`[rbx+8]`, and that value is the next call's argument.

Nothing further to strike. No cycle figure attached here.
