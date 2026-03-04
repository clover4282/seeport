import Foundation

enum HTMLTemplate {
    static let page = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>seeport</title>
    <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
        font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
        background: #1a1a1e; color: #e5e5e7;
        min-height: 100vh;
    }
    .container { max-width: 720px; margin: 0 auto; padding: 24px 16px; }
    header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
    header h1 { font-size: 24px; font-weight: 700; }
    header h1 span { color: #3b82f6; }
    .meta { font-size: 12px; color: #888; }
    .search-bar {
        display: flex; align-items: center; gap: 8px;
        background: #2a2a2e; border-radius: 10px; padding: 10px 14px; margin-bottom: 16px;
    }
    .search-bar svg { width: 16px; height: 16px; fill: #888; flex-shrink: 0; }
    .search-bar input {
        flex: 1; background: none; border: none; outline: none;
        color: #e5e5e7; font-size: 14px;
    }
    .search-bar input::placeholder { color: #666; }
    .tabs { display: flex; gap: 6px; margin-bottom: 16px; }
    .tab {
        padding: 6px 14px; border-radius: 8px; font-size: 13px; cursor: pointer;
        background: transparent; border: none; color: #888; transition: all 0.2s;
    }
    .tab:hover { background: #2a2a2e; }
    .tab.active { background: rgba(59,130,246,0.15); color: #3b82f6; font-weight: 600; }
    .tab .count {
        display: inline-block; font-size: 11px; padding: 1px 6px; border-radius: 4px;
        margin-left: 4px; background: rgba(255,255,255,0.08);
    }
    .tab.active .count { background: rgba(59,130,246,0.25); }
    .category-header {
        display: flex; align-items: center; gap: 8px;
        padding: 12px 0 6px; font-size: 12px; font-weight: 600; color: #888;
        text-transform: uppercase; letter-spacing: 0.5px;
    }
    .category-header .dot { width: 8px; height: 8px; border-radius: 50%; }
    .category-header .cat-count {
        font-size: 10px; padding: 1px 6px; border-radius: 3px;
        background: rgba(255,255,255,0.06);
    }
    .port-row {
        display: flex; align-items: center; gap: 14px;
        padding: 10px 12px; border-radius: 10px; transition: background 0.15s; cursor: pointer;
    }
    .port-row:hover { background: #26262a; }
    .port-num { font-size: 20px; font-weight: 700; font-family: 'SF Mono', monospace; min-width: 60px; }
    .port-info { flex: 1; min-width: 0; }
    .port-info .name-row { display: flex; align-items: center; gap: 8px; }
    .port-info .pname { font-size: 14px; font-weight: 500; }
    .docker-badge {
        font-size: 10px; font-weight: 600; padding: 2px 8px; border-radius: 4px;
        background: rgba(0,200,255,0.12); color: #00c8ff;
    }
    .port-info .details { font-size: 11px; color: #666; margin-top: 2px; }
    .actions { display: flex; gap: 6px; opacity: 0; transition: opacity 0.15s; }
    .port-row:hover .actions { opacity: 1; }
    .actions button {
        width: 30px; height: 30px; border-radius: 6px; border: none;
        background: rgba(255,255,255,0.06); cursor: pointer;
        display: flex; align-items: center; justify-content: center;
        transition: background 0.15s; font-size: 14px;
    }
    .actions button:hover { background: rgba(255,255,255,0.12); }
    .actions .kill-btn:hover { background: rgba(255,59,48,0.2); }
    .fav-btn.active { color: #fbbf24; }
    .status-bar {
        display: flex; justify-content: space-between; align-items: center;
        padding: 12px 0; margin-top: 12px; border-top: 1px solid #2a2a2e;
        font-size: 12px; color: #666;
    }
    .status-bar .dot { display: inline-block; width: 7px; height: 7px; border-radius: 50%; background: #22c55e; margin-right: 6px; }
    .empty { text-align: center; padding: 60px 0; color: #666; }
    .empty svg { width: 48px; height: 48px; fill: #444; margin-bottom: 12px; }
    .cat-frontend { color: #3b82f6; }
    .cat-backend { color: #22c55e; }
    .cat-database { color: #f59e0b; }
    .cat-docker { color: #00c8ff; }
    .cat-system { color: #888; }
    .cat-other { color: #aaa; }
    .dot-frontend { background: #3b82f6; }
    .dot-backend { background: #22c55e; }
    .dot-database { background: #f59e0b; }
    .dot-docker { background: #00c8ff; }
    .dot-system { background: #888; }
    .dot-other { background: #aaa; }
    </style>
    </head>
    <body>
    <div class="container">
        <header>
            <div>
                <h1>see<span>port</span></h1>
                <div class="meta" id="lastScan">Scanning...</div>
            </div>
            <button onclick="refresh()" style="background:none;border:none;cursor:pointer;font-size:20px;color:#888" id="refreshBtn">&#x21bb;</button>
        </header>

        <div class="search-bar">
            <svg viewBox="0 0 20 20"><path d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z"/></svg>
            <input type="text" id="search" placeholder="Search ports, processes, containers..." oninput="render()">
        </div>

        <div class="tabs" id="tabs"></div>
        <div id="portList"></div>
        <div class="status-bar">
            <div><span class="dot"></span><span id="statusText">Ready</span> &middot; <span id="portCount">0</span> ports</div>
            <div>Auto-refresh: <span id="interval">5</span>s</div>
        </div>
    </div>
    <script>
    let allPorts = [];
    let activeTab = 'all';
    const TABS = [{id:'all',label:'All'},{id:'favorites',label:'Favorites'},{id:'dev',label:'Dev First'}];
    const CAT_ORDER = ['FRONTEND','BACKEND','DATABASE','DOCKER','SYSTEM','OTHER'];

    async function fetchPorts() {
        try {
            const r = await fetch('/api/ports');
            allPorts = await r.json();
        } catch(e) { console.error(e); }
        render();
    }

    function render() {
        const q = document.getElementById('search').value.toLowerCase();
        let ports = allPorts;
        if (activeTab === 'favorites') ports = ports.filter(p => p.isFavorite);
        if (activeTab === 'dev') ports = ports.filter(p => ['FRONTEND','BACKEND','DATABASE','DOCKER'].includes(p.category));
        if (q) ports = ports.filter(p =>
            String(p.port).includes(q) ||
            p.process.name.toLowerCase().includes(q) ||
            p.category.toLowerCase().includes(q) ||
            (p.docker && p.docker.name.toLowerCase().includes(q))
        );

        // Tabs
        const tabCounts = {
            all: allPorts.length,
            favorites: allPorts.filter(p => p.isFavorite).length,
            dev: allPorts.filter(p => ['FRONTEND','BACKEND','DATABASE','DOCKER'].includes(p.category)).length
        };
        document.getElementById('tabs').innerHTML = TABS.map(t =>
            `<button class="tab ${activeTab===t.id?'active':''}" onclick="activeTab='${t.id}';render()">${t.label}<span class="count">${tabCounts[t.id]}</span></button>`
        ).join('');

        // Group by category
        const grouped = {};
        ports.forEach(p => { (grouped[p.category] = grouped[p.category] || []).push(p); });

        let html = '';
        CAT_ORDER.forEach(cat => {
            if (!grouped[cat]) return;
            const items = grouped[cat].sort((a,b) => a.port - b.port);
            const cl = cat.toLowerCase();
            html += `<div class="category-header"><div class="dot dot-${cl}"></div>${cat}<span class="cat-count">${items.length}</span></div>`;
            items.forEach(p => {
                const docker = p.docker ? `<span class="docker-badge">Docker</span>` : '';
                const dockerDetail = p.docker ? ` &middot; ${p.docker.id.slice(0,8)}` : '';
                html += `<div class="port-row" onclick="openPort(${p.port})"
                    <div class="port-num cat-${cl}">${p.port}</div>
                    <div class="port-info">
                        <div class="name-row"><span class="pname">${esc(p.process.name)}</span>${docker}</div>
                        <div class="details">PID: ${p.process.pid} &middot; ${esc(p.process.user)}${dockerDetail}</div>
                    </div>
                    <div class="actions">
                        <button class="fav-btn ${p.isFavorite?'active':''}" onclick="event.stopPropagation();toggleFav(${p.port})">${p.isFavorite?'\\u2605':'\\u2606'}</button>
                        <button class="kill-btn" onclick="event.stopPropagation();killProc(${p.process.pid})" title="Kill process">\\u2715</button>
                    </div>
                </div>`;
            });
        });

        if (!html) html = '<div class="empty"><div style="font-size:32px;margin-bottom:8px">&#x1F50C;</div><div>No ports found</div></div>';
        document.getElementById('portList').innerHTML = html;
        document.getElementById('portCount').textContent = ports.length;
        document.getElementById('lastScan').textContent = 'Last scan: ' + new Date().toLocaleTimeString();
    }

    async function toggleFav(port) {
        await fetch('/api/favorite/' + port, {method:'POST'});
        await fetchPorts();
    }

    async function killProc(pid) {
        if (!confirm('Kill process ' + pid + '?')) return;
        await fetch('/api/kill/' + pid, {method:'POST'});
        setTimeout(fetchPorts, 500);
    }

    function refresh() {
        document.getElementById('refreshBtn').style.transform = 'rotate(360deg)';
        setTimeout(() => document.getElementById('refreshBtn').style.transform = '', 500);
        fetchPorts();
    }

    function openPort(port) { window.open('http://localhost:' + port, '_blank'); }

    function esc(s) { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }

    fetchPorts();
    setInterval(fetchPorts, 5000);
    </script>
    </body>
    </html>
    """
}
