# MarkItDown Web Converter

基于 [markitdown](https://github.com/microsoft/markitdown) 的 Web 可视化转换工具，支持将各种文件格式批量转换为 Markdown。

## 环境要求

- **Python 3.10+**（markitdown 官方要求）
- macOS / Linux

## 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/0429globetrot/markitdown-web-converter.git

# 2. 进入目录
cd markitdown-web-converter

# 3. 一键启动
chmod +x run.sh
./run.sh
```

首次运行时会：
1. 自动检测系统中的 Python 3.10+ 版本（如有多个会提示选择）
2. 创建虚拟环境
3. 安装 markitdown 和 Flask 依赖
4. 启动服务并打开浏览器 `http://localhost:5001`

Python 选择结果会保存到 `.env` 文件，下次运行自动使用。

## 功能

- 可视化目录浏览，点击选择源文件夹和输出目录
- 支持单文件或批量转换
- 实时进度显示
- Markdown 在线预览
- 可选递归扫描子文件夹

## 支持的格式

| 类型 | 格式 |
|------|------|
| 文档 | PDF, DOCX, EPUB, MSG |
| 表格 | XLSX, XLS, CSV |
| 演示 | PPTX |
| 代码 | Jupyter Notebook, JSON |
| 网页 | HTML, RSS, Atom |
| 文本 | TXT, MD |
| 图片 | JPG, PNG（需配置 LLM） |
| 音频 | MP3, WAV, FLAC（语音转文字） |
| 压缩 | ZIP |

## 自定义端口

```bash
PORT=8080 ./run.sh
```

## 重新选择 Python 版本

删除 `.env` 文件后重新运行：

```bash
rm .env
./run.sh
```
