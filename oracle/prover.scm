;; oracle/prover.scm: the Little Prover oracle. Loads the vendored Scheme J-Bob
;; (vendor/j-bob, BSD 2-Clause) and prints every definition in the book's transcript as
;;   name<TAB>result
;; with Scheme's `write`, the form the wat side's ast->source renders.
;; Each transcript definition re-runs every proof before it, as the book's does.
;; Run from the repository root:  guile --no-auto-compile oracle/prover.scm
;;
;; The transcript's names are read BEFORE J-Bob is loaded: j-bob-lang.scm redefines `if` as
;; J-Bob's (only 'nil is false), which would break this script's own tests.
(define here (string-append (getcwd) "/vendor/j-bob/"))

(define transcript-names
  (call-with-input-file (string-append here "little-prover.scm")
    (lambda (port)
      (let loop ((form (read port)) (acc '()))
        (cond ((eof-object? form) (reverse acc))
              ((and (pair? form) (eq? (car form) 'defun)) (loop (read port) (cons (cadr form) acc)))
              (else (loop (read port) acc)))))))

(load (string-append here "j-bob-lang.scm"))
(load (string-append here "j-bob.scm"))
(load (string-append here "little-prover.scm"))

(for-each
  (lambda (name)
    (display name) (display "\t")
    (write ((eval name (interaction-environment))))
    (newline))
  transcript-names)
