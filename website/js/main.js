
function toggleTheme() {
  const html = document.documentElement;
  const next = html.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
  html.setAttribute('data-theme', next);
  localStorage.setItem('bz-theme', next);
  const icon = document.getElementById('themeIcon');
  const label = document.getElementById('themeLabel');
  if(icon) icon.textContent = next === 'light' ? '☾' : '☀';
  if(label) label.textContent = next === 'light' ? 'Dark' : 'Light';
}

function switchTab(groupId, lang) {
  const group = document.getElementById(groupId);
  if (!group) return;
  const btns = group.querySelectorAll('.tab-btn');
  const contents = group.querySelectorAll('.tab-content');
  
  btns.forEach(b => {
    if (b.dataset.lang === lang) b.classList.add('active');
    else b.classList.remove('active');
  });
  
  contents.forEach(c => {
    if (c.dataset.lang === lang) c.classList.add('active');
    else c.classList.remove('active');
  });
}

// Search Logic
let searchIndex = [];
function openSearch() {
  document.getElementById('searchModal').classList.add('active');
  document.getElementById('searchInput').focus();
}
function closeSearch(e) {
  if (e.target.id === 'searchModal') {
    document.getElementById('searchModal').classList.remove('active');
  }
}
function handleSearch(e) {
  const query = e.target.value.toLowerCase();
  const resultsContainer = document.getElementById('searchResults');
  resultsContainer.innerHTML = '';
  
  if (query.length < 2) return;
  
  const matches = searchIndex.filter(item => 
    item.title.toLowerCase().includes(query) || 
    item.content.toLowerCase().includes(query)
  ).slice(0, 8); // Limit to top 8
  
  matches.forEach(m => {
    const el = document.createElement('a');
    el.href = m.url;
    el.className = 'search-result-item';
    
    // Create a small snippet highlighting the query
    const idx = m.content.toLowerCase().indexOf(query);
    let snippet = m.content.substring(Math.max(0, idx - 60), idx + 100);
    
    // Extract exact match string for text-fragment highlighting
    let exactMatch = m.content.substring(idx, idx + query.length + 15).trim();
    if (exactMatch && exactMatch.length > 5) {
      el.href = m.url + '#:~:text=' + encodeURIComponent(exactMatch);
    }
    
    if (idx > 0) snippet = '...' + snippet;
    
    el.innerHTML = `
      <div class="search-result-title">${m.title}</div>
      <div class="search-result-snippet">${snippet}</div>
    `;
    el.addEventListener('click', () => { document.getElementById('searchModal').classList.remove('active'); });
    resultsContainer.appendChild(el);
  });
}

(function(){
  const stored = localStorage.getItem('bz-theme');
  const sys = window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
  const theme = stored || sys;
  document.documentElement.setAttribute('data-theme', theme);
  
  window.addEventListener('DOMContentLoaded', () => {
    const icon = document.getElementById('themeIcon');
    const label = document.getElementById('themeLabel');
    if(icon) icon.textContent = theme === 'light' ? '☾' : '☀';
    if(label) label.textContent = theme === 'light' ? 'Dark' : 'Light';
    
    // Load search index from script tag embedded at build time
    if (window.__BZ_SEARCH_INDEX__) {
      searchIndex = window.__BZ_SEARCH_INDEX__;
    }
  });
})();
