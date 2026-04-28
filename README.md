# MarkItDown Web Converter

基于 [markitdown](https://github.com/microsoft/markitdown) 的 Web 可视化转换工具，支持将各种文件格式批量转换为 Markdown。

## 环境要求

- **Python 3.10+**（markitdown 官方要求）
- macOS / Linux / Windows

## 快速开始

### macOS / Linux

```bash
git clone https://github.com/0429globetrot/markitdown-web-converter.git
cd markitdown-web-converter
./run.sh
```

### Windows

```cmd
git clone https://github.com/0429globetrot/markitdown-web-converter.git
cd markitdown-web-converter
run.bat
```

或直接双击 `run.bat` 运行。

首次运行时会：
1. 自动检测系统中的 Python 3.10+ 版本（如有多个会提示选择）
2. 创建虚拟环境
3. 安装 markitdown 和 Flask 依赖
4. 启动服务并自动打开浏览器 `http://localhost:5001`

Python 选择结果会保存到 `.env` 文件，下次运行自动使用。如需重新选择，删除 `.env` 后重新运行。

## 功能

- 可视化目录浏览，点击选择源文件夹和输出目录
- 支持单文件或批量转换
- 实时进度显示
- Markdown 在线预览
- 可选递归扫描子文件夹

## 界面说明

### 配置区

| 项目 | 说明 |
|------|------|
| SOURCE（源文件夹） | 点击 Browse 选择要转换的文件所在目录 |
| OUTPUT（输出目录） | 点击 Browse 选择 .md 文件的保存位置，**留空则只在线预览，不写入磁盘** |
| 递归 | 勾选后会扫描源文件夹下所有子文件夹中的文件 |
| SCAN | 扫描源文件夹，列出所有 markitdown 支持的文件 |

### 文件列表区

| 按钮 | 说明 |
|------|------|
| ALL | 全选所有文件 |
| NONE | 取消所有选择 |
| SELECTED | 转换已勾选的文件 |
| ALL（转换） | 转换列表中的全部文件 |

每个文件前有勾选框，可单独选择或取消。

### 结果区

| 项目 | 说明 |
|------|------|
| 绿色圆点 | 转换成功 |
| 红色圆点 | 转换失败，右侧显示错误信息 |
| PREVIEW | 在下方预览区渲染显示 Markdown 内容 |
| SAVED | 文件已保存到输出目录（仅填写 OUTPUT 时显示） |
| DOWNLOAD | 通过浏览器下载 .md 文件（仅未填写 OUTPUT 时显示） |

### 输出目录的区别

- **填写了 OUTPUT**：转换后的 .md 文件自动保存到指定目录，结果显示绿色 SAVED 标签
- **未填写 OUTPUT**：仅在线预览和通过浏览器下载（会保存到浏览器默认的 ~/Downloads），不会写入指定目录

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
# macOS / Linux
rm .env
./run.sh
```

```cmd
# Windows
del .env
run.bat
```
