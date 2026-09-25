# BRIEF — excursus 007 stone 1: a keyword's string is how it is written; its name is `name`

> The builder, 2026-09-25: *"is keyword to string dropping the leading colon logical?... that feels
> completely unwanted and like a latent flaw... (wat.keyword/to-string :foo) ;; :=> ":foo" that's what
> i would expect"* -- and on Clojure's `name`: *"that feels good. I accept that 4 YES derivation"*.

## FIRST — park excursus 006 on its own branch

Your 006 strike is uncommitted in `wat-rs` on `the-little-wat`. 006's re-strike will be written
against this stone's verbs, so this lands first.

`git switch -c the-little-wat-006-macro-returns`, commit the 006 work as it stands ("WIP excursus
006 stone 1 -- parked for 007"), `git push -u origin` it, `git switch the-little-wat` -- clean.

## YOU ARE NEW TO THIS — read first

1. `the-little-wat/FINDINGS.md` — `### F-207` (this stone), then `### F-206` (why it surfaced)
2. `wat-rs/src/intrinsic/keyword.rs` — `to-string` and `from-string`, their docs and examples, and
   the `crate::runtime::eval_keyword_to_string` / `eval_keyword_from_string` they call
3. `wat-rs/src/check.rs:~19360` — where their schemes are registered

## THE CONTRACT — two pairs, one meaning each, each round-tripping

| verb | meaning | example |
|---|---|---|
| `:wat::keyword::to-string` | the keyword as WRITTEN -- agrees with `str` and with how it prints | `:foo` → `":foo"`; `:wat::core::i64` → `":wat::core::i64"` |
| `:wat::keyword::from-string` | the inverse: REQUIRES the leading colon, refuses text without it | `":foo"` → `:foo` |
| `:wat::keyword::name` | the keyword's name, no colon (Clojure's `name`) | `:foo` → `"foo"`; `:wat::core::i64` → `"wat::core::i64"` |
| `:wat::keyword::from-name` | the inverse: REFUSES a leading colon (Clojure's `keyword`) | `"foo"` → `:foo` |

`(from-string (to-string k)) == k` and `(from-name (name k)) == k` for every keyword; the SAME
refusal shape (a diagnostic naming the input) for the wrong spelling on either constructor.

## THE WORK — in this order, because a name must never silently change meaning inside a commit

1. **Add `name` and `from-name`** with today's colon-free behaviour — full doc blocks in the
   register's shape (`@Purity`, `@ExpandTime Legal`, `@example`, `@see` each other), schemes,
   expand-time rulings as their siblings have.
2. **Rename every caller by meaning**: every `to-string` call in wat-rs and the-little-wat becomes
   `name`, every `from-string` call becomes `from-name` (49 and 168 today; both spellings,
   `:wat::keyword::…` and `wat.keyword/…`; `.wat`, `.rs` string literals, docs' `@example`s).
   A surgical codemod, deleted before commit. After this step nothing behaves differently.
3. **Only then** give `to-string` / `from-string` the written-form meaning, with new examples and
   tests: `(to-string :foo)` is `":foo"`, equal to `(str :foo)`; `(from-string "foo")` refuses.
4. **Tests**: each verb's examples as assertions; both round-trips; both refusals; `to-string`
   equals `str` for a sample of keywords (bare, namespaced, variant `:E.V`).

## STOP TRIGGERS

- **STOP-1 — a caller that needs the WRITTEN form was using `to-string` plus a hand-added colon**
  (`(concat ":" (to-string k))`) — list them; each becomes `to-string` alone, but show the list.
- **STOP-2 — a floor red** other than F-197's two lint reds. Capture the arm; never re-run it.

## OUT OF SCOPE

`to-symbol` / `to-type-form` / `to-type-form-colon` · 006's macro work (parked) · repositories other
than wat-rs and the-little-wat (the builder is told; the SCORE lists none it touched).

## METHOD

`timeout -s KILL` on every wat run; your own `CARGO_TARGET_DIR`; the floor
`NEXTEST_TEST_THREADS=4 scripts/floor.sh` with nothing else building there; assert every text
replacement; the codemod leaves every other byte untouched (read the diff). Commit NOTHING on
`the-little-wat` (the parked 006 branch is this stone's one commit). Write
`the-little-wat/docs/excursus/2026/09/007-a-keyword-is-written-with-its-colon/SCORE-stone-1-name-and-written-form.md`.
