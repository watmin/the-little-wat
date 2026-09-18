;; Advent of Code's inclusion-exclusion shape, in wat: overlapping boxes switched on and off.
;;
;; Each line turns a box of cubes on or off. The space is far too large to hold a cube per
;; coordinate -- the boxes run to ±90000 on each axis, which is 5.8 x 10^15 cubes -- so the count
;; is kept by INCLUSION AND EXCLUSION: every new box is intersected with each signed box already
;; recorded, and the intersection is recorded with the opposite sign.
;;
;; Part one: how many cubes are on, counting only instructions entirely within -50..50.
;; Part two: how many are on, counting every instruction.
;;
;; **Parsing is the wat-shaped part, again for F-061's reason.** The reference matches one regular
;; expression against `on x=-54..11,y=-20..3,z=-17..5` and gets seven groups. Here the line is
;; split on a space, then on a comma, then each piece on `=`, then on `..` -- four splits and an
;; index per field, because `matches?` answers a bool and there is no way to ask what matched.
;;
;; The arithmetic is the other half: a single box can hold 2.7 x 10^13 cubes and the answer is
;; 1.0 x 10^14, so every volume is an i64 product of three differences. day10 showed that wat
;; TRAPS on overflow rather than wrapping, which is the property that makes this safe to write
;; without checking.
;;
;; The puzzle and its input are ours (aoc/input/day22-cuboids.txt); Advent of Code's own texts
;; and inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day22-cuboids.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day22-cuboids.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defrecord :aoc::Box
  [s <- :wat::core::i64
   x1 <- :wat::core::i64  x2 <- :wat::core::i64
   y1 <- :wat::core::i64  y2 <- :wat::core::i64
   z1 <- :wat::core::i64  z2 <- :wat::core::i64])

(:wat::core::typealias :aoc::Boxes (:wat::core::Vector :- [:aoc::Box]))

(:wat::core::defrecord :aoc::Step [on <- :wat::core::bool  box <- :aoc::Box])
(:wat::core::typealias :aoc::Steps (:wat::core::Vector :- [:aoc::Step]))

(:wat::core::defn :aoc::imax [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> a b) a b))
(:wat::core::defn :aoc::imin [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a b) a b))

;; F-061: four splits where the reference writes one pattern
(:wat::core::defn :aoc::range-of [field <- :wat::core::String] -> :aoc::Lines
  (:wat::string::split (:wat::core::nth (:wat::string::split field "=") 1) ".."))

(:wat::core::defn :aoc::parse-step [l <- :wat::core::String] -> :aoc::Step
  (:wat::core::let
    [halves (:wat::string::split l " ")
     fields (:wat::string::split (:wat::core::nth halves 1) ",")
     xs (:aoc::range-of (:wat::core::nth fields 0))
     ys (:aoc::range-of (:wat::core::nth fields 1))
     zs (:aoc::range-of (:wat::core::nth fields 2))]
    (:aoc::Step :on (:wat::core::= (:wat::core::nth halves 0) "on")
                :box (:aoc::Box :s 1
                       :x1 (:aoc::to-int (:wat::core::nth xs 0)) :x2 (:aoc::to-int (:wat::core::nth xs 1))
                       :y1 (:aoc::to-int (:wat::core::nth ys 0)) :y2 (:aoc::to-int (:wat::core::nth ys 1))
                       :z1 (:aoc::to-int (:wat::core::nth zs 0)) :z2 (:aoc::to-int (:wat::core::nth zs 1))))))

(:wat::core::defn :aoc::parse [ls <- :aoc::Lines i <- :wat::core::i64 acc <- :aoc::Steps] -> :aoc::Steps
  (:wat::core::if (:wat::core::>= i (:wat::core::length ls)) acc
    (:aoc::parse ls (:wat::core::+ i 1) (:wat::core::conj acc (:aoc::parse-step (:wat::core::nth ls i))))))

;; the overlap of an existing box with the new one, carrying the OPPOSITE sign
(:wat::core::defn :aoc::overlaps [cubes <- :aoc::Boxes b <- :aoc::Box i <- :wat::core::i64
                                  acc <- :aoc::Boxes] -> :aoc::Boxes
  (:wat::core::if (:wat::core::>= i (:wat::core::length cubes)) acc
    (:wat::core::let
      [c (:wat::core::nth cubes i)
       ia (:aoc::imax (:aoc::Box/x1 c) (:aoc::Box/x1 b))
       ib (:aoc::imin (:aoc::Box/x2 c) (:aoc::Box/x2 b))
       ic (:aoc::imax (:aoc::Box/y1 c) (:aoc::Box/y1 b))
       id (:aoc::imin (:aoc::Box/y2 c) (:aoc::Box/y2 b))
       ie (:aoc::imax (:aoc::Box/z1 c) (:aoc::Box/z1 b))
       if- (:aoc::imin (:aoc::Box/z2 c) (:aoc::Box/z2 b))]
      (:aoc::overlaps cubes b (:wat::core::+ i 1)
        (:wat::core::if (:wat::core::and (:wat::core::<= ia ib)
                          (:wat::core::and (:wat::core::<= ic id) (:wat::core::<= ie if-)))
          (:wat::core::conj acc (:aoc::Box :s (:wat::core::- 0 (:aoc::Box/s c))
                                           :x1 ia :x2 ib :y1 ic :y2 id :z1 ie :z2 if-))
          acc)))))

(:wat::core::defn :aoc::apply-step [cubes <- :aoc::Boxes st <- :aoc::Step] -> :aoc::Boxes
  (:wat::core::let [add (:aoc::overlaps cubes (:aoc::Step/box st) 0 (:wat::core::Vector :- [:aoc::Box]))]
    (:wat::core::concat cubes
      (:wat::core::if (:aoc::Step/on st) (:wat::core::conj add (:aoc::Step/box st)) add))))

(:wat::core::defn :aoc::run [sts <- :aoc::Steps i <- :wat::core::i64 small? <- :wat::core::bool
                             cubes <- :aoc::Boxes] -> :aoc::Boxes
  (:wat::core::if (:wat::core::>= i (:wat::core::length sts)) cubes
    (:wat::core::let [st (:wat::core::nth sts i)]
      (:aoc::run sts (:wat::core::+ i 1) small?
        (:wat::core::if (:wat::core::and small? (:wat::core::not (:aoc::small? (:aoc::Step/box st))))
          cubes
          (:aoc::apply-step cubes st))))))

(:wat::core::defn :aoc::within? [a <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::and (:wat::core::>= a -50) (:wat::core::<= a 50)))

(:wat::core::defn :aoc::small? [b <- :aoc::Box] -> :wat::core::bool
  (:wat::core::and (:aoc::within? (:aoc::Box/x1 b))
    (:wat::core::and (:aoc::within? (:aoc::Box/x2 b))
      (:wat::core::and (:aoc::within? (:aoc::Box/y1 b))
        (:wat::core::and (:aoc::within? (:aoc::Box/y2 b))
          (:wat::core::and (:aoc::within? (:aoc::Box/z1 b)) (:aoc::within? (:aoc::Box/z2 b))))))))

(:wat::core::defn :aoc::total [cubes <- :aoc::Boxes i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length cubes)) acc
    (:wat::core::let [c (:wat::core::nth cubes i)]
      (:aoc::total cubes (:wat::core::+ i 1)
        (:wat::core::+ acc
          (:wat::core::* (:aoc::Box/s c)
            (:wat::core::* (:wat::core::+ (:wat::core::- (:aoc::Box/x2 c) (:aoc::Box/x1 c)) 1)
              (:wat::core::* (:wat::core::+ (:wat::core::- (:aoc::Box/y2 c) (:aoc::Box/y1 c)) 1)
                             (:wat::core::+ (:wat::core::- (:aoc::Box/z2 c) (:aoc::Box/z1 c)) 1)))))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [sts (:aoc::parse (:aoc::lines "aoc/input/day22-cuboids.txt") 0 (:wat::core::Vector :- [:aoc::Step]))
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day22-cuboids.expected"
                         "aoc day22 cuboids"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::total (:aoc::run sts 0 true (:wat::core::Vector :- [:aoc::Box])) 0 0))
                           (int (:aoc::total (:aoc::run sts 0 false (:wat::core::Vector :- [:aoc::Box])) 0 0))))))
