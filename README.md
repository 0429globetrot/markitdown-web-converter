# MarkItDown Web Converter

基于 [markitdown](https://github.com/microsoft/markitdown) 的 Web 可视化转换工具，支持将各种文件格式批量转换为 Markdown。

## 快速开始

```bash
git clone https://github.com/YOUR_USERNAME/markitdown-web-converter.git
cd markitdown-web-converter
chmod +x run.sh
./run.sh
```

首次运行会自动创建虚拟环境并安装依赖，然后自动打开浏览器 `http://localhost:5001`。

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
