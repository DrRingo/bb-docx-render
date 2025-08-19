#!/usr/bin/env bb
(ns fill-docx
  (:require [babashka.fs :as fs]
            [babashka.process :refer [sh]]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def original-cwd (or (System/getenv "BB_DOCX_RENDER_CWD") "."))

(defn ->absolute-path [path]
  (when path
    (if (fs/absolute? path)
      path
      (str (fs/path original-cwd path)))))

(defn usage []
  (println "Cách dùng:")
  (println "  bb fill_docx.bb <template.docx> <data.json> [-o output.docx|output-template]")
  (println "  Ví dụ: -o 'out/{{ho_ten}} - {{ngay_sinh}}.docx'")
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
      ;; Resolve all paths relative to the original working directory
      template (-> (get positional 0) ->absolute-path)
      datafile (-> (get positional 1) ->absolute-path)
      output-tmpl (->absolute-path output-tmpl)]

  (when (or (nil? template) (nil? datafile)) (usage))
  (when-not (fs/exists? template)
    (binding [*out* *err*] (println "Không tìm thấy template:" template))
    (System/exit 2))
  (when-not (fs/exists? datafile)
    (binding [*out* *err*] (println "Không tìm thấy JSON:" datafile))
    (System/exit 3))

  ;; Tách thư mục và phần template tên file để bảo toàn path
  (let [out-dir  (some-> output-tmpl fs/parent str) ; có thể là nil nếu không có thư mục
        out-name (fs/file-name output-tmpl)
        ;; Python code: render + sanitize + save
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
                "def sanitize_filename(name:str)->str:\n"
                "    name = name.replace(' ', '_')\n"
                "    return re.sub(r'[<>:\\\":/\\\\|?*]+', '', name)\n"
                "\n"
                "def main():\n"
                "    # args: <template.docx> <data.json> <output_dir> <output_name_template>\n"
                "    if len(sys.argv) < 5:\n"
                "        print('Usage: python - <template.docx> <data.json> <output_dir> <output_name_template>', file=sys.stderr)\n"
                "        sys.exit(1)\n"
                "    tpl_path, json_path, out_dir, out_name_tmpl = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]\n"
                "    with open(json_path, 'r', encoding='utf-8') as f:\n"
                "        ctx = json.load(f)\n"
                "    now = datetime.datetime.now()\n"
                "    ctx.setdefault('_now', now)\n"
                "    ctx.setdefault('_today', now.date().isoformat())\n"
                "    # render file name (only the base name)\n"
                "    if '{{' in out_name_tmpl:\n"
                "        out_name = JEnv().from_string(out_name_tmpl).render(ctx)\n"
                "    else:\n"
                "        out_name = out_name_tmpl\n"
                "    out_name = sanitize_filename(out_name)\n"
                "    # full path\n"
                "    if out_dir and len(out_dir.strip())>0:\n"
                "        os.makedirs(out_dir, exist_ok=True)\n"
                "        out_path = os.path.join(out_dir, out_name)\n"
                "    else:\n"
                "        out_path = out_name\n"
                "    # render docx\n"
                "    tpl = DocxTemplate(tpl_path)\n"
                "    tpl.render(ctx)\n"
                "    tpl.save(out_path)\n"
                "    try:\n"
                "        print(out_path)\n"
                "    except UnicodeEncodeError:\n"
                "        sys.stdout.buffer.write((out_path + '\\n').encode('utf-8'))\n"
                "\n"
                "if __name__ == '__main__':\n"
                "    main()\n")
        env (merge (into {} (System/getenv))
                   {"PYTHONIOENCODING" "utf-8" "PYTHONUTF8" "1"})
        run (fn [& cmd]
              (try
                (apply sh {:in pycode :out :string :err :string :env env} cmd)
                (catch Exception _ {:exit 127 :out "" :err ""})))
        ;; Ưu tiên uv; nếu fail, fallback python3 -> python
        r (or (let [r (run "uv" "run" "python" "-" template datafile (or out-dir "") out-name)]
                (when (zero? (:exit r)) r))
              (let [r (run "python3" "-" template datafile (or out-dir "") out-name)]
                (when (zero? (:exit r)) r))
              (run "python" "-" template datafile (or out-dir "") out-name))]

    (if (zero? (:exit r))
      (println "Đã tạo:" (str/trim (:out r)))
      (do
        (binding [*out* *err*]
          (println (str/trim (:err r)))
          (println "Gợi ý:")
          (println " - Dùng uv và cài deps: uv add docxtpl jinja2 python-docx, rồi chạy lại.")
          (println " - Hoặc fallback cài pip cho python3: pip3 install --user docxtpl jinja2 python-docx"))
        (System/exit (:exit r))))))
