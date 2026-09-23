;; Every shape the per-function register convention has to get right, in one program.
;; Arity 1, 2 and 3 leaves; a call-free leaf with a self tail call; a String parameter that
;; has to be SHARED before it is placed; a call site whose argument is itself a call, which
;; forces the push-and-pop-into-registers path; and a function whose ADDRESS is taken, which
;; must stay on the stack convention because `call *rax` cannot know an arity.
(wat.core/defn user/neg [a :- wat.type/i64] :- wat.type/i64 (wat.core/- 0 a))
(wat.core/defn user/sub [a :- wat.type/i64 b :- wat.type/i64] :- wat.type/i64 (wat.core/- a b))
(wat.core/defn user/mix3 [a :- wat.type/i64 b :- wat.type/i64 c :- wat.type/i64] :- wat.type/i64
  (wat.core/+ (wat.core/* a 100) (wat.core/+ (wat.core/* b 10) c)))

;; call-free and tail-recursive: the back edge has to write rdi and rsi, not rbx and r12
(wat.core/defn user/down [n :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/<= n 0) acc (user/down (wat.core/- n 1) (wat.core/+ acc n))))

;; the arguments are not in parameter order, so the tail call takes the stack path
(wat.core/defn user/swapper [a :- wat.type/i64 b :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= a 4) b (user/swapper b (wat.core/+ a 1))))

;; a String parameter: it is a pointer, so placing it in rdi has to keep the share
(wat.core/defn user/len2 [s :- wat.type/String t :- wat.type/String] :- wat.type/i64
  (wat.core/+ (wat.string/length s) (wat.string/length t)))

;; address taken -- stays on the stack convention
(wat.core/defn user/add2 [a :- wat.type/i64 b :- wat.type/i64] :- wat.type/i64 (wat.core/+ a b))
(wat.core/defn user/apply2 [op :- [wat.type/i64 wat.type/i64 :-> wat.type/i64]] :- wat.type/i64
  (op 20 3))

;; a caller with several calls in one expression, one of them nested in an argument
(wat.core/defn user/drive [s :- wat.type/String n :- wat.type/i64] :- wat.type/i64
  (wat.core/+ (user/sub (user/mix3 1 2 3) (user/neg n))
    (wat.core/+ (user/len2 s s)
      (wat.core/+ (user/down n 0)
        (wat.core/+ (user/swapper 0 n) (user/apply2 user/add2))))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (user/neg 7))
    (wat.kernel/println (user/sub 9 4))
    (wat.kernel/println (user/mix3 4 5 6))
    (wat.kernel/println (user/down 10 0))
    (wat.kernel/println (user/swapper 0 9))
    (wat.kernel/println (user/len2 "abc" "de"))
    (wat.kernel/println (user/apply2 user/add2))
    (wat.kernel/println (user/drive "hello" 6))))
