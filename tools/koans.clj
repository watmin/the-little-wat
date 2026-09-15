;; tools/koans.clj: the Clojure Koans' topics as an acceptance test of wat's Clojure spelling.
;;
;; koans/src/NN-topic.clj holds our own filled-in koans, one per topic of the Clojure Koans
;; (functional-koans/clojure-koans): plain Clojure, one form per blank-line-separated chunk,
;; each true in Clojure. For every row:
;;   1. the oracle: Clojure evaluates the row, which must be true;
;;   2. the literal port: the row with every clojure.core name spelled wat.core/… (and
;;      clojure.string's spelled wat.string/…) runs as its own wat program, printing its value
;;      as EDN. Nothing else changes, so the port is what a codemod would produce;
;;   3. the verdict: literal (wat prints true), wrong (wat prints something else), refused (the
;;      program never starts: parse or check), or died (a runtime error), with wat's message.
;; Results go to koans/literal/NN-topic.tsv, and a summary per topic is printed.
;;
;; Run from the repository root:   clojure -M tools/koans.clj [NN-topic ...]
;; WAT overrides the wat binary (default ../wat-rs/target/release/wat); KOAN_TMP the directory
;; the per-row programs are written to (default: the JVM's temp directory).

(require '[clojure.string :as str]
         '[clojure.java.io :as io]
         '[clojure.java.shell :as sh])
(require '[clojure.string :as string]    ; the aliases rows use, as the koans do
         '[clojure.set :as set])

(def wat (or (System/getenv "WAT") "../wat-rs/target/release/wat"))

;; ---- rows

(defn rows [text]
  (->> (str/split text #"\n[ \t]*\n")
       (map (fn [chunk]
              (->> (str/split-lines chunk)
                   (remove #(str/starts-with? (str/trim %) ";"))
                   (str/join "\n")
                   str/trim)))
       (remove str/blank?)))

;; ---- the literal port: clojure.core names get wat's namespace, nothing else changes

(def sym-chars #"[A-Za-z0-9*+!\-_?<>=/.&%$|#:']")

(defn sym-char? [c] (boolean (re-matches sym-chars (str c))))

(defn tok-end [s i]
  (loop [j i] (if (and (< j (count s)) (sym-char? (.charAt s j))) (recur (inc j)) j)))

(defn string-end [s i]   ; i at the opening quote
  (loop [j (inc i)]
    (case (.charAt s j)
      \\ (recur (+ j 2))
      \" (inc j)
      (recur (inc j)))))

(defn char-end [s i]     ; i at the backslash
  (loop [j (+ i 2)]
    (if (and (< j (count s)) (Character/isLetter (.charAt s j))) (recur (inc j)) j)))

(defn form-end [s i]     ; the end of the form starting at i
  (let [c (.charAt s i)]
    (cond
      (#{\( \[ \{} c)
      (loop [j (inc i) depth 1]
        (if (zero? depth) j
          (let [d (.charAt s j)]
            (cond (= d \") (recur (string-end s j) depth)
                  (= d \\) (recur (char-end s j) depth)
                  (#{\( \[ \{} d) (recur (inc j) (inc depth))
                  (#{\) \] \}} d) (recur (inc j) (dec depth))
                  :else (recur (inc j) depth)))))
      (= c \") (string-end s i)
      :else (tok-end s i))))

(defn core-name? [tok]
  (and (not= tok "&")
       (or (special-symbol? (symbol tok))
           (try (var? (ns-resolve 'clojure.core (symbol tok))) (catch Exception _ false)))))

;; SPELLING=keyword ports to wat's keyword spelling (:wat::core::x) instead of its Clojure one
;; (wat.core/x), so the same rows show what the checker catches in each (F-014).
(def spelling (or (System/getenv "SPELLING") "clojure"))

(def out-dir (if (= spelling "keyword") "koans/keyword" "koans/literal"))

(defn qualify [ns n]
  (if (= spelling "keyword") (str ":wat::" ns "::" n) (str "wat." ns "/" n)))

(defn wat-name [tok]
  (cond
    (= tok "/") (qualify "core" "/")
    (and (str/includes? tok "/") (not (str/starts-with? tok "/")))
    (let [[ns n] (str/split tok #"/" 2)]
      (case ns
        ("string" "clojure.string") (qualify "string" n)
        ("set" "clojure.set") (qualify "set" n)
        "clojure.core" (qualify "core" n)
        tok))
    (core-name? tok) (qualify "core" tok)
    :else tok))

(defn translate [s]
  (let [n (count s) sb (StringBuilder.)]
    (loop [i 0]
      (if (>= i n)
        (str sb)
        (let [c (.charAt s i)
              copy (fn [j] (.append sb (subs s i j)) j)]
          (cond
            (= c \") (recur (copy (string-end s i)))
            (= c \\) (recur (copy (char-end s i)))
            (= c \') (recur (copy (form-end s (inc i))))     ; quoted data stays as written
            (= c \:) (recur (copy (tok-end s i)))
            (or (Character/isDigit c)
                (and (#{\+ \-} c) (< (inc i) n) (Character/isDigit (.charAt s (inc i)))))
            (recur (copy (tok-end s i)))
            (re-matches #"[A-Za-z*+!\-_?<>=/.&%$|]" (str c))
            (let [j (tok-end s i)] (.append sb (wat-name (subs s i j))) (recur j))
            :else (do (.append sb c) (recur (inc i)))))))))

;; A setup row defines something (a defn, as the koans' own files do before their meditations);
;; each later koan that names it gets its definition, ported the same way, ahead of main.
(defn setup? [row]
  (boolean (re-find #"^\((def|defn|defmacro|defrecord|defprotocol|deftype|defmulti|defmethod)\s" row)))

(defn defined-name [row] (second (re-find #"^\(\S+\s+([^\s()\[\]]+)" row)))

(defn program [setups row]
  (str ";; generated by tools/koans.clj: one koan, ported literally\n"
       (apply str (map #(str (translate %) "\n\n") setups))
       "(wat.core/defn user/main [] :- wat.type/nil\n"
       "  (wat.kernel/println (wat.edn/write\n"
       (translate row)
       ")))\n"))

;; ---- running and judging

;; wat's failure record, shortened to its innermost error: kind and message, or the
;; unresolved names
(defn message [text]
  (let [t (str/replace text "\\\"" "\"")   ; one level of escaping off
        kinds (re-seq #"#wat\.[a-z]+/([A-Za-z]+) \{:message \"([^\"]*)\"" t)
        paths (distinct (map second (re-seq #":path \"([^\"]+)\"" t)))
        [_ kind msg] (last kinds)
        s (cond (seq paths) (str "unresolved: " (str/join " " paths))
                kind (str kind ": " msg)
                :else (str/trim text))
        s (str/replace s #"\s+" " ")]
    (subs s 0 (min 300 (count s)))))

(defn judge [{:keys [exit out err]}]
  (let [first-line (first (str/split-lines (str out)))]
    (cond
      (and (= exit 0) (= first-line "\"true\"")) ["literal" ""]
      (= exit 0) ["wrong" (str "printed " first-line)]
      (= exit 3) ["refused" (message (str out err))]
      (= exit 1) ["died" (message (str out err))]
      :else [(str "exit-" exit) (message (str out err))])))

(defn oracle [row]
  (try (pr-str (binding [*ns* (find-ns 'user)] (eval (read-string row))))
       (catch Throwable t (str "THROW " (.getMessage t)))))

(defn one-line [s] (str/replace s #"\s+" " "))

(defn uses? [row setup]
  (boolean (re-find (re-pattern (str "(?<![\\w\\-*?!])" (java.util.regex.Pattern/quote (defined-name setup))
                                     "(?![\\w\\-*?!])"))
                    row)))

(defn run-topic [tmp topic]
  (let [all-rows (vec (rows (slurp (str "koans/src/" topic ".clj"))))
        _ (doseq [s (filter setup? all-rows)] (binding [*ns* (find-ns 'user)] (eval (read-string s))))
        koans (vec (keep-indexed (fn [i row]
                                   (when-not (setup? row)
                                     {:row row
                                      :setups (filter #(uses? row %) (filter setup? (subvec all-rows 0 i)))}))
                                 all-rows))
        results (doall
                  (pmap (fn [k {:keys [row setups]}]
                          (let [clj (oracle row)
                                f (io/file tmp (format "%s-%s-%02d.wat" spelling topic (inc k)))]
                            (spit f (program setups row))
                            (let [[v detail] (judge (sh/sh "timeout" "-s" "KILL" "60" wat (.getPath f)))]
                              {:k (inc k) :verdict v :clj clj :detail detail :row row})))
                        (range) koans))]
    (with-open [w (io/writer (str out-dir "/" topic ".tsv"))]
      (.write w "row\tverdict\tclojure\twat said\tkoan\n")
      (doseq [{:keys [k verdict clj detail row]} results]
        (.write w (str/join "\t" [k verdict clj (one-line detail) (one-line row)]))
        (.write w "\n")))
    (let [bad-oracle (remove #(= "true" (:clj %)) results)
          freq (frequencies (map :verdict results))]
      (doseq [{:keys [k clj]} bad-oracle]
        (println (format "  ORACLE: %s row %d is not true in Clojure: %s" topic k clj)))
      (println (format "%-28s %3d rows  %s" topic (count results)
                       (str/join "  " (for [v ["literal" "wrong" "refused" "died"]
                                            :let [c (get freq v 0)] :when (pos? c)]
                                        (str v " " c)))))
      {:rows (count results) :freq freq :oracle-ok (empty? bad-oracle)})))

(let [topics (or (seq *command-line-args*)
                 (->> (.listFiles (io/file "koans/src"))
                      (map #(.getName %))
                      (filter #(str/ends-with? % ".clj"))
                      sort
                      (map #(str/replace % #"\.clj$" ""))))
      tmp (doto (io/file (or (System/getenv "KOAN_TMP") (System/getProperty "java.io.tmpdir")) "koans")
            .mkdirs)]
  (.mkdirs (io/file out-dir))
  (let [all (mapv #(run-topic tmp %) topics)
        freq (apply merge-with + (map :freq all))]
    (println "---")
    (println (format "%d rows: %s" (reduce + (map :rows all))
                     (str/join ", " (for [[v c] (sort-by key freq)] (str c " " v)))))
    (shutdown-agents)
    (System/exit (if (every? :oracle-ok all) 0 1))))
