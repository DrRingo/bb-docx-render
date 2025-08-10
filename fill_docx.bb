#!/usr/bin/env bb
(ns fill-docx
  (:require [babashka.fs :as fs]
            [babashka.process :refer [sh]]
            [cheshire.core :as json]
            [clojure.string :as str]))

(defn usage []
  (println "Cách dùng:")
  (println "  bb fill_docx.bb <template.docx> <data.json> [-o output.docx|output-template]")
  (System/exit 1))

(defn find-index [v x]
  (first (keep-indexed (fn [i e] (when (= e x) i)) v)))

(let [argv (vec *command-line-args*)
      idx  (find-index argv "-o")
      output-tmpl (if (nil? idx) "output.docx"
                      (or (get argv (inc idx)) "output.docx"))
      positional (if (nil? idx) argv
                     (vec (concat (subvec argv 0 idx)
                                  (subvec argv (min (count argv) (+ idx 2))))))
      template (get positional 0)
      datafile (get positional 1)]

  (when (or (nil? template) (nil? datafile)) (usage))
  (when-not (fs/exists? template)
    (binding [*out* *err*] (println "Không tìm thấy template:" template))
    (System/exit 2))
  (when-not (fs/exists? datafile)
    (binding [*out* *err*] (println "Không tìm thấy JSON:" datafile))
    (System/exit 3))

  (let [ctx (json/parse-string (slurp datafile) true)
        ;; Để an toàn encoding, giữ pycode ở ASCII + thêm coding cookie
        pycode (str
"# -*- coding: utf-8 -*-\n"
"import sys, json, datetime, re, os\n"
"from docxtpl import DocxTemplate\n"
"from jinja2 import Environment as JEnv\n"
"try:\n"
"    if hasattr(sys.stdout, 'reconfigure'):\n"
"        sys.stdout.reconfigure(encoding='utf-8')\n"
"        sys.stderr.reconfigure(encoding='utf-8')\n"
"except Exception:\n"
"    pass\n"
"os.environ.setdefault('PYTHONIOENCODING','utf-8')\n"
"os.environ.setdefault('PYTHONUTF8','1')\n"
"\n"
"def sanitize_filename(name):\n"
"    name = name.replace(' ', '_')\n"
"    return re.sub(r'[<>:\\\":/\\\\|?*]+', '', name)\n"
"\n"
"def main():\n"
"    if len(sys.argv) < 4:\n"
"        print('Usage: python - <template.docx> <data.json> <output-template>', file=sys.stderr)\n"
"        sys.exit(1)\n"
"    tpl_path, json_path, output_template = sys.argv[1], sys.argv[2], sys.argv[3]\n"
"    with open(json_path, 'r', encoding='utf-8') as f:\n"
"        ctx = json.load(f)\n"
"    now = datetime.datetime.now()\n"
"    ctx.setdefault('_now', now)\n"
"    ctx.setdefault('_today', now.date().isoformat())\n"
"    if '{{' in output_template:\n"
"        output_final = JEnv().from_string(output_template).render(ctx)\n"
"    else:\n"
"        output_final = output_template\n"
"    output_final = sanitize_filename(output_final)\n"
"    tpl = DocxTemplate(tpl_path)\n"
"    tpl.render(ctx)\n"
"    tpl.save(output_final)\n"
"    try:\n"
"        print(output_final)\n"
"    except UnicodeEncodeError:\n"
"        sys.stdout.buffer.write((output_final + '\\n').encode('utf-8'))\n"
"\n"
"if __name__ == '__main__':\n"
"    main()\n")]
    ;; Chạy Python trong Poetry env
    (let [env (merge (into {} (System/getenv))
                     {"PYTHONIOENCODING" "utf-8" "PYTHONUTF8" "1"})
          r (try
              (sh {:in pycode :out :string :err :string :env env}
                  "poetry" "run" "python" "-" template datafile output-tmpl)
              (catch Exception e
                {:exit 127 :err (str e) :out ""}))]
      (if (zero? (:exit r))
        (println "Đã tạo:" (str/trim (:out r)))
        (do
          (binding [*out* *err*]
            (println "Lỗi khi chạy Python trong Poetry env:")
            (println (str/trim (:err r)))
            (println "Hãy đảm bảo bạn đã chạy:")
            (println "  poetry add docxtpl jinja2 python-docx"))
          (System/exit (:exit r)))))))

