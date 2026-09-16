;; probes/fix/convert.wat: run wat's own wat-to-wat converter and print the result.
;;
;; wat/fix.wat calls itself "THE PROVING POINT: wat writes wat" -- `fix-source` rewrites a form
;; tree from the rust-scheme surface into the faithful-Clojure dialect, and `fix-text` does the
;; same over raw text via span edits so surrounding whitespace survives.
;;
;; The only test that means anything for a codemod is SEMANTIC PRESERVATION: convert a program,
;; run both, and compare what they print. tools/fix-roundtrip.sh does that with this file.
;;
;; Run: wat probes/fix/convert.wat <path>     (defaults to probes/fix/subject.wat)

(:wat::core::defn :user::main [] -> :wat::core::nil
  ;; :wat::runtime::argv is [binary script ...user args] -- so a user argument is at index 2.
  ;; It is named zero times in any user-facing page, and it lives in :wat::runtime::, a namespace
  ;; of 85 verbs this repository had used exactly once before today.
  (:wat::core::let [args (:wat::runtime::argv)
                    path (:wat::core::if (:wat::core::> (:wat::core::length args) 2)
                           (:wat::core::nth args 2)
                           "probes/fix/subject.wat")]
    (:wat::kernel::println (:wat::fix::fix-text (:wat::io::read-file path)))))
