#!/usr/bin/env bb
(ns fill-docx
  (:require [babashka.fs :as fs]
            [babashka.process :refer [sh]]
            [cheshire.core :as json]
            [clojure.string :as str]))

(defn usage []
  (println "Cách dùng:")
  (println "  bb fill_docx.bb <template.docx> <data.json> [-o output.docx|output-template]")
  (println "  Ví dụ: -o 'out/{{msnv}}/{{ho_ten}}.docx'")
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

  ;; Truyền template đường dẫn đầu ra trực tiếp cho Python
  (let [;; Python code: render + sanitize + save
        pycode (str
                "# -*- coding: utf-8 -*-\n"
                "import sys, json, datetime, re, os\n"
                "from pathlib import Path\n"
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
                "def sanitize_path(path:str)->str:\n"
                "    p = Path(path)\n"
                "    anchor = p.anchor\n"
                "    parts = p.parts[1:] if anchor else p.parts\n"
                "    sanitized_parts = [sanitize_filename(part) for part in parts if part]\n"
                "    sanitized = Path(anchor).joinpath(*sanitized_parts) if anchor else Path(*sanitized_parts)\n"
                "    return str(sanitized)\n"
                "\n"
                "def main():\n"
                "    # args: <template.docx> <data.json> <output_path_template>\n"
                "    if len(sys.argv) < 4:\n"
                "        print('Usage: python - <template.docx> <data.json> <output_path_template>', file=sys.stderr)\n"
                "        sys.exit(1)\n"
                "    tpl_path, json_path, out_path_tmpl = sys.argv[1], sys.argv[2], sys.argv[3]\n"
                "    with open(json_path, 'r', encoding='utf-8') as f:\n"
                "        ctx = json.load(f)\n"
                "    now = datetime.datetime.now()\n"
                "    ctx.setdefault('_now', now)\n"
                "    ctx.setdefault('_today', now.date().isoformat())\n"
                "    tpl = DocxTemplate(tpl_path)\n"
                "    tpl.init_docx()\n"
                "    xml_ctx = tpl.patch_xml(tpl.get_xml())\n"
                "    module = JEnv().from_string(xml_ctx).make_module(ctx)\n"
                "    for k in dir(module):\n"
                "        if not k.startswith('_'):\n"
                "            ctx.setdefault(k, getattr(module, k))\n"
                "    if '{{' in out_path_tmpl:\n"
                "        out_path_raw = JEnv().from_string(out_path_tmpl).render(ctx)\n"
                "    else:\n"
                "        out_path_raw = out_path_tmpl\n"
                "    out_path = Path(sanitize_path(out_path_raw))\n"
                "    out_path.parent.mkdir(parents=True, exist_ok=True)\n"
                "    tpl.render(ctx)\n"
                "    tpl.save(out_path)\n"
                "    try:\n"
                "        print(out_path)\n"
                "    except UnicodeEncodeError:\n"
                "        sys.stdout.buffer.write((str(out_path) + '\\n').encode('utf-8'))\n"
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
        r (or (let [r (run "uv" "run" "python" "-" template datafile output-tmpl)]
                (when (zero? (:exit r)) r))
              (let [r (run "python3" "-" template datafile output-tmpl)]
                (when (zero? (:exit r)) r))
              (run "python" "-" template datafile output-tmpl))]

    (if (zero? (:exit r))
      (println "Đã tạo:" (str/trim (:out r)))
      (do
        (binding [*out* *err*]
          (println (str/trim (:err r)))
          (println "Gợi ý:")
          (println " - Dùng uv và cài deps: uv add docxtpl jinja2 python-docx, rồi chạy lại.")
          (println " - Hoặc fallback cài pip cho python3: pip3 install --user docxtpl jinja2 python-docx"))
        (System/exit (:exit r))))))
