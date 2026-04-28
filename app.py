import argparse
import os
import threading
import uuid
from pathlib import Path

from flask import Flask, jsonify, request, send_from_directory
from markitdown import MarkItDown

# 确保工作目录为脚本所在目录
os.chdir(os.path.dirname(os.path.abspath(__file__)))

app = Flask(__name__, static_folder="static", static_url_path="")

# markitdown 支持的文件扩展名
SUPPORTED_EXTENSIONS = {
    ".pdf", ".docx", ".pptx", ".xlsx", ".xls", ".epub", ".msg",
    ".ipynb", ".html", ".htm", ".rss", ".atom", ".csv", ".json",
    ".jsonl", ".txt", ".text", ".md", ".markdown",
    ".jpg", ".jpeg", ".png", ".gif", ".bmp",
    ".mp3", ".wav", ".flac", ".m4a",
    ".zip",
}

# 批量任务存储: {job_id: {status, total, done, results, files}}
_jobs = {}

md_converter = MarkItDown()


def _format_size(size_bytes):
    """格式化文件大小"""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    else:
        return f"{size_bytes / (1024 * 1024):.1f} MB"


def _convert_single(file_path: str, output_dir: str | None = None):
    """转换单个文件，返回 (markdown, title, saved_path, error)"""
    try:
        result = md_converter.convert(file_path)
        markdown = result.markdown
        title = result.title

        saved_path = None
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)
            stem = Path(file_path).stem
            saved_path = os.path.join(output_dir, f"{stem}.md")
            with open(saved_path, "w", encoding="utf-8") as f:
                f.write(markdown)

        return markdown, title, saved_path, None
    except Exception as e:
        return None, None, None, str(e)


def _batch_worker(job_id: str, files: list[str], output_dir: str | None):
    """批量转换工作线程"""
    job = _jobs[job_id]
    for file_path in files:
        markdown, title, saved_path, error = _convert_single(file_path, output_dir)
        result = {
            "file": file_path,
            "filename": os.path.basename(file_path),
            "status": "success" if error is None else "error",
            "markdown": markdown,
            "title": title,
            "saved_path": saved_path,
            "error": error,
        }
        job["results"].append(result)
        job["done"] += 1
    job["status"] = "completed"


# ---------- 路由 ----------


@app.route("/")
def index():
    return send_from_directory("static", "index.html")


@app.route("/api/browse")
def browse():
    """浏览目录结构，返回子目录和文件列表"""
    path = request.args.get("path", "").strip()
    if not path:
        path = str(Path.home())  # 默认从用户主目录开始

    dir_path = Path(path)
    if not dir_path.is_dir():
        return jsonify({"error": f"目录不存在: {path}"}), 400

    try:
        entries = []
        for item in sorted(dir_path.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower())):
            if item.name.startswith("."):
                continue  # 跳过隐藏文件/目录
            try:
                entries.append({
                    "name": item.name,
                    "path": str(item),
                    "is_dir": item.is_dir(),
                })
            except PermissionError:
                continue

        # 面包屑导航
        parts = []
        current = dir_path.resolve()
        while True:
            parts.insert(0, {"name": current.name or str(current), "path": str(current)})
            parent = current.parent
            if parent == current:
                break
            current = parent

        return jsonify({
            "current": str(dir_path.resolve()),
            "breadcrumbs": parts,
            "entries": entries,
        })
    except PermissionError:
        return jsonify({"error": "没有权限访问该目录"}), 403


@app.route("/api/list-files", methods=["POST"])
def list_files():
    """扫描文件夹，返回支持的文件列表"""
    data = request.get_json() or {}
    folder = data.get("folder", "").strip()
    recursive = data.get("recursive", False)

    if not folder:
        return jsonify({"error": "请输入文件夹路径"}), 400

    folder_path = Path(folder)
    if not folder_path.is_dir():
        return jsonify({"error": f"文件夹不存在: {folder}"}), 400

    files = []
    pattern_func = folder_path.rglob if recursive else folder_path.glob
    for f in pattern_func("*"):
        if f.is_file() and f.suffix.lower() in SUPPORTED_EXTENSIONS:
            stat = f.stat()
            files.append({
                "path": str(f),
                "name": f.name,
                "extension": f.suffix.lower(),
                "size": stat.st_size,
                "size_formatted": _format_size(stat.st_size),
            })

    files.sort(key=lambda x: x["name"])
    return jsonify({"files": files, "total": len(files)})


@app.route("/api/convert", methods=["POST"])
def convert():
    """转换单个文件"""
    data = request.get_json() or {}
    file_path = data.get("file", "").strip()
    output_dir = data.get("output_dir", "").strip() or None

    if not file_path:
        return jsonify({"error": "请指定文件路径"}), 400

    if not os.path.isfile(file_path):
        return jsonify({"error": f"文件不存在: {file_path}"}), 400

    markdown, title, saved_path, error = _convert_single(file_path, output_dir)

    if error:
        return jsonify({"error": "转换失败", "detail": error}), 500

    return jsonify({
        "markdown": markdown,
        "title": title,
        "saved_path": saved_path,
        "filename": os.path.basename(file_path),
    })


@app.route("/api/batch-convert", methods=["POST"])
def batch_convert():
    """启动批量转换任务"""
    data = request.get_json() or {}
    files = data.get("files", [])
    output_dir = data.get("output_dir", "").strip() or None

    if not files:
        return jsonify({"error": "请选择要转换的文件"}), 400

    job_id = str(uuid.uuid4())
    _jobs[job_id] = {
        "status": "running",
        "total": len(files),
        "done": 0,
        "results": [],
        "files": files,
    }

    thread = threading.Thread(
        target=_batch_worker, args=(job_id, files, output_dir), daemon=True
    )
    thread.start()

    return jsonify({"job_id": job_id, "total": len(files)})


@app.route("/api/job/<job_id>")
def job_progress(job_id):
    """查询批量任务进度"""
    job = _jobs.get(job_id)
    if not job:
        return jsonify({"error": "任务不存在"}), 404

    return jsonify({
        "status": job["status"],
        "total": job["total"],
        "done": job["done"],
        "results": job["results"],
    })


@app.route("/api/preview")
def preview():
    """读取已保存的 .md 文件"""
    file_path = request.args.get("file", "").strip()
    if not file_path or not os.path.isfile(file_path):
        return jsonify({"error": "文件不存在"}), 400

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    return jsonify({"content": content, "file": file_path})


@app.route("/api/download")
def download():
    """下载已保存的 .md 文件"""
    file_path = request.args.get("file", "").strip()
    if not file_path or not os.path.isfile(file_path):
        return jsonify({"error": "文件不存在"}), 400

    directory = os.path.dirname(file_path)
    filename = os.path.basename(file_path)
    return send_from_directory(directory, filename, as_attachment=True)


@app.errorhandler(Exception)
def handle_error(e):
    return jsonify({"error": "服务器错误", "detail": str(e)}), 500


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="MarkItDown Web Converter")
    parser.add_argument("--port", type=int, default=5001, help="端口号")
    parser.add_argument("--host", default="127.0.0.1", help="监听地址")
    args = parser.parse_args()

    app.run(host=args.host, port=args.port, debug=False)
