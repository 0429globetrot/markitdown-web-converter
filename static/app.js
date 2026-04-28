// ========== STATE ==========
const state = {
    files: [],
    selectedFiles: [],
    results: [],
    jobId: null,
    browser: { mode: null, currentPath: '', selectedPath: '' },
};

// ========== DIRECTORY BROWSER ==========

function openBrowser(mode) {
    state.browser.mode = mode;
    state.browser.selectedPath = '';
    const val = mode === 'input'
        ? document.getElementById("inputFolder").value
        : document.getElementById("outputFolder").value;

    document.getElementById("browserTitle").textContent =
        mode === 'input' ? 'SELECT SOURCE' : 'SELECT OUTPUT';
    document.getElementById("browserModal").style.display = "flex";
    navigateTo(val || '');
}

function closeBrowser() {
    document.getElementById("browserModal").style.display = "none";
}

function closeBrowserOnOverlay(e) {
    if (e.target === e.currentTarget) closeBrowser();
}

async function navigateTo(path) {
    const body = document.getElementById("browserBody");
    body.innerHTML = '<div class="browser-empty">Loading...</div>';

    try {
        const resp = await fetch(`/api/browse?path=${encodeURIComponent(path)}`);
        const data = await resp.json();
        if (!resp.ok) {
            body.innerHTML = `<div class="browser-empty">${data.error}</div>`;
            return;
        }

        state.browser.currentPath = data.current;
        state.browser.selectedPath = data.current;
        document.getElementById("browserCurrent").textContent = data.current;

        // Breadcrumbs
        const crumbs = document.getElementById("browserBreadcrumbs");
        crumbs.innerHTML = data.breadcrumbs.map((c, i) => {
            const last = i === data.breadcrumbs.length - 1;
            const name = c.name || '/';
            if (last) return `<span class="crumb-link" style="color:var(--text-dim);cursor:default;">${esc(name)}</span>`;
            return `<button class="crumb-link" onclick="navigateTo('${ep(c.path)}')">${esc(name)}</button><span class="crumb-sep">&#8250;</span>`;
        }).join('');

        // Entries
        let html = '';
        for (const e of data.entries) {
            if (e.is_dir) {
                html += `<div class="browser-row dir" onclick="navigateTo('${ep(e.path)}')"><span class="browser-row-icon">&#128193;</span><span class="browser-row-name">${esc(e.name)}</span></div>`;
            } else {
                html += `<div class="browser-row"><span class="browser-row-icon" style="opacity:0.4">&#128196;</span><span class="browser-row-name" style="color:var(--text-muted)">${esc(e.name)}</span></div>`;
            }
        }
        body.innerHTML = html || '<div class="browser-empty">Empty directory</div>';
    } catch (e) {
        body.innerHTML = `<div class="browser-empty">Error: ${e.message}</div>`;
    }
}

function confirmBrowser() {
    const p = state.browser.selectedPath;
    if (!p) return;
    if (state.browser.mode === 'input') document.getElementById("inputFolder").value = p;
    else document.getElementById("outputFolder").value = p;
    closeBrowser();
}

// ========== FILE LOADING ==========

async function loadFiles() {
    const folder = document.getElementById("inputFolder").value.trim();
    const recursive = document.getElementById("recursiveCheck").checked;
    if (!folder) { alert("Please select a source folder first."); return; }

    const btn = document.getElementById("btnLoad");
    btn.disabled = true;
    btn.innerHTML = '<span>SCANNING...</span>';

    try {
        const resp = await fetch("/api/list-files", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ folder, recursive }),
        });
        const data = await resp.json();
        if (!resp.ok) { alert(data.error); return; }

        state.files = data.files;
        state.selectedFiles = data.files.map(f => f.path);
        renderFileList();
    } catch (e) {
        alert("Request failed: " + e.message);
    } finally {
        btn.disabled = false;
        btn.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"></polygon></svg> SCAN`;
    }
}

function renderFileList() {
    const section = document.getElementById("fileSection");
    const list = document.getElementById("fileList");
    const count = document.getElementById("fileCount");

    if (state.files.length === 0) {
        section.style.display = "none";
        alert("No supported files found.");
        return;
    }

    section.style.display = "";
    count.textContent = state.files.length;

    list.innerHTML = state.files.map(f => `
        <label class="file-item">
            <input type="checkbox" value="${f.path}"
                ${state.selectedFiles.includes(f.path) ? "checked" : ""}
                onchange="toggleFile('${ep(f.path)}')">
            <span class="file-name">${esc(f.name)}</span>
            <span class="file-meta">${f.size_formatted}  ${f.extension}</span>
        </label>
    `).join('');
}

function toggleFile(path) {
    const i = state.selectedFiles.indexOf(path);
    if (i >= 0) state.selectedFiles.splice(i, 1);
    else state.selectedFiles.push(path);
}

function selectAll() {
    state.selectedFiles = state.files.map(f => f.path);
    document.querySelectorAll("#fileList input[type='checkbox']").forEach(c => c.checked = true);
}

function deselectAll() {
    state.selectedFiles = [];
    document.querySelectorAll("#fileList input[type='checkbox']").forEach(c => c.checked = false);
}

// ========== CONVERSION ==========

async function convertSelected() {
    if (!state.selectedFiles.length) { alert("No files selected."); return; }
    await startBatch(state.selectedFiles);
}

async function convertAll() {
    await startBatch(state.files.map(f => f.path));
}

async function startBatch(files) {
    const outputDir = document.getElementById("outputFolder").value.trim();
    state.results = [];
    state.jobId = null;
    document.getElementById("progressIcon").classList.add("spin");
    show("progressSection");
    show("resultsSection");
    hide("previewSection");
    updateProgress(0, files.length);
    document.getElementById("resultsList").innerHTML = "";
    lockBtns(true);

    try {
        const resp = await fetch("/api/batch-convert", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ files, output_dir: outputDir }),
        });
        const data = await resp.json();
        if (!resp.ok) { alert(data.error); lockBtns(false); return; }
        state.jobId = data.job_id;
        poll(data.job_id);
    } catch (e) {
        alert("Request failed: " + e.message);
        lockBtns(false);
    }
}

function poll(jobId) {
    const timer = setInterval(async () => {
        try {
            const resp = await fetch(`/api/job/${jobId}`);
            const data = await resp.json();
            if (!resp.ok) { clearInterval(timer); lockBtns(false); return; }

            updateProgress(data.done, data.total);
            renderResults(data.results);

            if (data.status === "completed") {
                clearInterval(timer);
                lockBtns(false);
                document.getElementById("progressIcon").classList.remove("spin");
                const ok = data.results.filter(r => r.status === "success").length;
                const fail = data.results.length - ok;
                const outDir = document.getElementById("outputFolder").value.trim();
                let msg = `DONE  ${ok} ok / ${fail} fail`;
                if (outDir && ok > 0) msg += `  →  ${outDir}`;
                document.getElementById("progressText").textContent = msg;
            } else {
                const cur = data.results[data.results.length - 1];
                if (cur) document.getElementById("progressText").textContent = cur.filename + '...';
            }
        } catch (e) {
            clearInterval(timer);
            lockBtns(false);
        }
    }, 500);
}

// ========== UI ==========

function updateProgress(done, total) {
    document.getElementById("progressBar").style.width = (total ? (done / total) * 100 : 0) + "%";
    if (done < total) document.getElementById("progressText").textContent = `${done} / ${total}`;
}

function renderResults(results) {
    state.results = results;
    const hasOutput = !!document.getElementById("outputFolder").value.trim();
    document.getElementById("resultsList").innerHTML = results.map((r, i) => {
        if (r.status === "success") {
            const savedPath = r.saved_path ? r.saved_path.replace(/'/g, "\\'") : '';
            const mdName = r.filename ? r.filename.replace(/\.[^.]+$/, ".md") : "output.md";
            return `<div class="result-row">
                <span class="result-dot ok"></span>
                <span class="result-name">${esc(r.filename)}</span>
                <div class="result-btns">
                    <button class="tool-btn" onclick="showPreview(${i})">PREVIEW</button>
                    ${savedPath
                        ? `<span class="saved-tag" title="${esc(r.saved_path)}">SAVED</span>`
                        : `<button class="tool-btn" onclick="downloadFile('${savedPath}','${mdName}')">DOWNLOAD</button>`}
                </div>
            </div>`;
        }
        return `<div class="result-row">
            <span class="result-dot fail"></span>
            <span class="result-name">${esc(r.filename || r.file)}</span>
            <span class="result-err" title="${esc(r.error)}">${esc(r.error)}</span>
        </div>`;
    }).join('');
}

function showPreview(i) {
    const r = state.results[i];
    if (!r?.markdown) return;
    const section = document.getElementById("previewSection");
    document.getElementById("previewFilename").textContent = r.filename || '';
    section.style.display = "";
    const content = document.getElementById("previewContent");
    content.innerHTML = typeof marked !== "undefined" ? marked.parse(r.markdown) : `<pre>${esc(r.markdown)}</pre>`;
    section.scrollIntoView({ behavior: "smooth" });
}

function closePreview() { hide("previewSection"); }

function downloadFile(p, name) {
    const a = document.createElement("a");
    a.href = `/api/download?file=${encodeURIComponent(p)}`;
    a.download = name;
    a.click();
}

// ========== UTILS ==========

function show(id) { document.getElementById(id).style.display = ""; }
function hide(id) { document.getElementById(id).style.display = "none"; }
function esc(t) { const d = document.createElement("div"); d.textContent = t || ""; return d.innerHTML; }
function ep(p) { return (p || "").replace(/\\/g, "\\\\").replace(/'/g, "\\'"); }
function lockBtns(v) {
    document.getElementById("btnConvertSelected").disabled = v;
    document.getElementById("btnConvertAll").disabled = v;
    document.getElementById("btnLoad").disabled = v;
}
