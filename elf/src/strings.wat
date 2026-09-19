;; Strings, compiled. A String value is one machine word -- the address of [len:8][bytes...] --
;; so it rides in rax like everything else. Literals live in the read-only data tail; anything
;; `wat.string/concat` builds lives in the megabyte the entry stub mmaps, bump-allocated in r15.
;;
;; This file runs BOTH ways: `wat elf/src/strings.wat` and `elf/out/strings.elf` must print the
;; same bytes. That is the point of it -- printing a String means reproducing wat's EDN escaping
;; in machine code, and the differential test is the only thing that says the reproduction is
;; right.

(wat.core/defn user/greet [who :- wat.type/String] :- wat.type/String
  (wat.string/concat "hello, " who "!"))

(wat.core/defn user/stars [n :- wat.type/i64 acc :- wat.type/String] :- wat.type/String
  (wat.core/if (wat.core/= n 0) acc
    (user/stars (wat.core/- n 1) (wat.string/concat acc "*"))))

(wat.core/defn user/main [] :- wat.type/nil
  ;; a parameter of type String, and a String returned
  (wat.kernel/println (user/greet "world"))

  ;; let-bound strings, and a length
  (wat.core/let [a (wat.string/concat "x" "y")
                 b (wat.string/concat a a a)]
    (wat.kernel/println b)
    (wat.kernel/println (wat.string/length b)))

  ;; a branch whose arms are strings
  (wat.kernel/println (wat.core/if (wat.core/> 3 2) (user/greet "then") (user/greet "else")))

  ;; forty allocations, to prove the bump pointer moves
  (wat.kernel/println (user/stars 40 ""))
  (wat.kernel/println (wat.string/length (user/stars 40 "")))

  ;; every escape println has to put back: quote, backslash, newline, tab, carriage return
  (wat.kernel/println (wat.string/concat "q\" b\\ " "n\n t\t r\r ." )))
