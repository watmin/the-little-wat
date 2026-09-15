# The Clojure Koans, in wat

This is the first acceptance test after the books (NEXT.md): is wat, written in its Clojure
spelling, a Clojure dialect? The Clojure Koans (functional-koans/clojure-koans, EPL) teach
Clojure in 27 files of small assertions. `src/` holds our own filled-in koans, 229 rows in
one file per topic. Each row is an expression that Clojure evaluates to true. The rows follow
the koans' topics, but they are written for this repository, not copied from the koans.

## How a row is judged

`tools/koans.clj` does the judging. Run it from the repository root with
`clojure -M tools/koans.clj [NN-topic …]`.

1. **The oracle.** Clojure 1.12 evaluates the row, which must be true.
2. **The literal port.** Every `clojure.core` name gets wat's namespace, `wat.core/…`
   (`clojure.string`'s names get `wat.string/…`), and nothing else changes. That is what a
   codemod from Clojure would produce. Any definitions the row uses (`defn`, `defmacro`,
   `defrecord` …) are ported the same way and placed ahead of `main`.
3. **The run.** The port runs as its own wat program, which prints the row's value as EDN.
   The verdict is one of:
   - **literal**: wat prints `true`;
   - **wrong**: wat prints something else;
   - **refused**: the program never starts (parse or check), and wat gives its reason;
   - **died**: the program starts and fails at runtime.

`SPELLING=keyword` ports to wat's keyword spelling (`:wat::core::=`) instead. The rows are
the same, so the two runs differ only in what wat's checker sees (F-014).

## Results (2026-09-15, wat-rs `a3218644d`)

| 229 rows | literal | wrong | refused | died |
|---|---|---|---|---|
| Clojure spelling (`literal/`) | 29 | 2 | 147 | 51 |
| keyword spelling (`keyword/`) | 29 | 0 | 187 | 13 |

- **29 of 229 rows (13%) port literally.** They cover equality, `count`, `conj`,
  `assoc`/`dissoc`, `contains?`, `nth`, quoting, and `->`.
- **In the Clojure spelling, 51 rows die at runtime.** 38 of them are refused at startup in
  the keyword spelling. The errors are arity, types, and malformed special forms (an `if`
  with no else, a `fn` without types), and the checker catches them only when a call is
  spelled with a keyword (F-014).
- **2 rows answer wrong, silently.** A `wat.core/defmacro` defines nothing, so
  `macroexpand` hands back the form unchanged (F-022).
- **13 rows die in both spellings.** These are checker gaps of their own; see the Clojure
  Koans section of FINDINGS.md.
- **Most refusals are names wat doesn't have.** FINDINGS.md lists them, with the rows each
  one blocks.

Each topic has a table in `literal/NN-topic.tsv` and `keyword/NN-topic.tsv`. Its columns are
the row number, the verdict, Clojure's answer, wat's message, and the koan.
