;; oracle/euler/p22-names-scores.clj: the expected answers for euler/p22-names-scores.wat.
;;
;; Our own Clojure on Project Euler's names-scores problem: sort the names alphabetically, give
;; each name the sum of its letters' alphabetical values (A=1 … Z=26), and multiply that by the
;; name's 1-based position in the sorted list. The answer is the total over every name.
;;
;; Project Euler's problem statement is not reproduced, and neither is its names.txt, which is
;; not redistributable. The names in euler/input/p22-names.txt are ours, generated
;; deterministically, in the same shape: quoted, comma-separated, unsorted on disk.
;;
;; This problem was chosen to press on F-062: wat has no character access, so the wat solution
;; must find each letter's value by a subs scan, at about 16.7 us a character. Here that is one
;; line of Clojure.
;;
;; Every line printed after "=> " is an answer the wat solution must print, in order.
;;
;; Run: tools/euler-oracle.sh p22-names-scores

(def alphabet "ABCDEFGHIJKLMNOPQRSTUVWXYZ")

(defn names []
  (->> (slurp "euler/input/p22-names.txt")
       (re-seq #"\"([^\"]*)\"")
       (map second)))

(defn letter-value [c]
  (inc (.indexOf alphabet (int c))))

(defn name-value [s]
  (reduce + (map letter-value s)))

(defn total [ns]
  (reduce + (map-indexed (fn [i n] (* (inc i) (name-value n))) ns)))

(defn say [x] (println "=>" x))

(let [ns     (names)
      sorted (sort ns)]
  ;; how many names were read, so a misparsed file says so immediately
  (say (count ns))
  ;; the sort, at both ends
  (say (first sorted))
  (say (last sorted))
  ;; a single name's value, and the smallest and largest
  (say (name-value "COLIN"))
  (say (apply min (map name-value sorted)))
  (say (apply max (map name-value sorted)))
  ;; the first name's score, the second's, and the whole total
  (say (* 1 (name-value (nth sorted 0))))
  (say (* 2 (name-value (nth sorted 1))))
  (say (total sorted)))
