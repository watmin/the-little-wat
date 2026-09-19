;; Why a bump allocator can free, and the program that proves it has to.
;;
;; Each level allocates a 32-byte string, asks its length, and THROWS THE STRING AWAY. Fifty
;; thousand levels is 50000 * 48 = 2.4 MB of allocation against a heap of 1 MiB -- so before the
;; compiler learned to release, this program ran off the end of the mmap'd region and died with
;; a segmentation fault (exit 139) while the interpreter printed 50000 and exited 0.
;;
;; The fix is eight bytes of code per statement. A sequence's last form is its value; every form
;; before it has its value thrown away, so whatever it allocated is garbage the moment it
;; finishes -- and with a bump allocator, freeing all of it is putting r15 back:
;;
;;   push r15 ; push r15        mark   (twice, to keep the frame 16-byte aligned)
;;   <the statement>
;;   pop r15 ; pop r15          release
;;
;; The marks live on the stack, so it nests with no bookkeeping at all. See elf/compile.wat for
;; where the soundness argument stops -- `poke`, and anything whose allocation escapes upward.
;;
;; Run both ways; they must agree.

(wat.core/defn user/churn [n :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= n 0) acc
    (wat.core/do
      (wat.string/length (wat.string/concat "aaaaaaaaaaaaaaaa" "bbbbbbbbbbbbbbbb"))
      (user/churn (wat.core/- n 1) (wat.core/+ acc 1)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/churn 50000 0)))
