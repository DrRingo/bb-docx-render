#!/usr/bin/env bb
(ns fill-docx
  (:require [babashka.fs :as fs]
            [babashka.process :refer [shell]]
            [clojure.string :as str]))

;; Thư mục chứa script này — dùng chung cho resolve-render-py và uv --project
(def script-dir
  (str (fs/parent (System/getProperty "babashka.file"))))

(defn usage []
  (println "Cách dùng:")
  (println "  bb fill_docx.bb <template.docx> <data.json|data.yaml|data.toml> [-o output.docx|output-template]")
  (println "  Ví dụ: -o 'out/{{msnv}}/{{ho_ten}}.docx'")
  (System/exit 1))

(defn find-index [v x]
  (first (keep-indexed (fn [i e] (when (= e x) i)) v)))

(defn resolve-render-py
  "Tìm render.py theo thứ tự ưu tiên:
   1. Thư mục chứa script này (khi chạy trực tiếp, qua bbin, brew, scoop)
   2. Thư mục làm việc hiện tại (fallback thủ công)"
  []
  (let [candidates [(str (fs/path script-dir "render.py"))
                    "render.py"]]
    (first (filter fs/exists? candidates))))

(let [argv        (vec *command-line-args*)
      idx         (find-index argv "-o")
      output-tmpl (if (nil? idx) "output.docx"
                      (or (get argv (inc idx)) "output.docx"))
      positional  (if (nil? idx) argv
                      (vec (concat (subvec argv 0 idx)
                                   (subvec argv (min (count argv) (+ idx 2))))))
      template    (get positional 0)
      datafile    (get positional 1)]

  (when (or (nil? template) (nil? datafile)) (usage))
  (when-not (fs/exists? template)
    (binding [*out* *err*] (println "Không tìm thấy template:" template))
    (System/exit 2))
  (when-not (fs/exists? datafile)
    (binding [*out* *err*] (println "Không tìm thấy data file:" datafile))
    (System/exit 3))

  (let [render-py (resolve-render-py)]
    (when (nil? render-py)
      (binding [*out* *err*]
        (println "Không tìm thấy render.py bên cạnh script hoặc trong thư mục hiện tại."))
      (System/exit 4))

    (let [env (merge (into {} (System/getenv))
                     {"PYTHONIOENCODING" "utf-8" "PYTHONUTF8" "1"})
          run (fn [& cmd]
                (try
                  (apply shell {:out :string :err :string :env env :continue true} cmd)
                  (catch Exception _ {:exit 127 :out "" :err ""})))
          ;; Gọi render.py trực tiếp bằng file path (tránh pipe stdin trên Windows).
          ;; --project script-dir đảm bảo uv luôn tìm đúng pyproject.toml.
          r   (or (let [r (run "uv" "run" "--project" script-dir
                               "python" render-py template datafile output-tmpl)]
                    (when (zero? (:exit r)) r))
                  (let [r (run "python3" render-py template datafile output-tmpl)]
                    (when (zero? (:exit r)) r))
                  (run "python" render-py template datafile output-tmpl))]

      (if (zero? (:exit r))
        (println "Đã tạo:" (str/trim (:out r)))
        (do
          (binding [*out* *err*]
            (println (str/trim (:err r)))
            (println "Gợi ý:")
            (println " - Dùng uv và cài deps: uv add docxtpl jinja2 python-docx pyyaml, rồi chạy lại.")
            (println " - Hoặc fallback: pip3 install --user docxtpl jinja2 python-docx pyyaml"))
          (System/exit (:exit r)))))))
