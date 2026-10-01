;; excursus 008 stone 3b-1 (round 2). `:c::eval-seq` deferred a write-head call's first
;; argument ("kid 1", `conj`/`assoc`/`concat`'s "box") to the END of its walk, unconditionally
;; -- correct when kid 1 IS the box, a bare Symbol, but wrong when kid 1 is a COMPOUND
;; expression with a name buried inside it: `:c::concat`'s own generator always compiles kid 1
;; FIRST, not last, so deferring its walk drags every name nested inside it (here, `s`, used
;; via `user/mklen` inside kid 1) to be recorded as the function's LAST mention one occurrence
;; too early. The true last mention -- `s` used again, nested, in the THIRD argument -- then
;; finds it already dropped. Found tracing `elf/lib/runtime.wat`'s `:c::rt-tree-push`, whose
;; `child` binding has this exact shape with `kid`: a compound first argument containing one
;; use, a bare direct use, and a THIRD nested use, all of the same name. Under
;; `WAT_DROP_CHECK=1` this doubles a drop and stops: `wat: reference count underflow`.
(wat.core/defn user/mklen [s :- wat.type/String] :- wat.type/i64
  (wat.string/length s))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let
    [s (wat.string/concat "ab" "cd")
     r (wat.string/concat
         (wat.i64/to-string (user/mklen s))
         s
         (wat.i64/to-string (user/mklen s))
         "!")]
    (wat.kernel/println r)))
