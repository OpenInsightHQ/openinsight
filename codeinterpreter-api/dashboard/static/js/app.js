// Admin Dashboard Application Logic

const state = {
  masterKey: localStorage.getItem("master_api_key") || "",
  activeTab: "overview",
  stats: null,
  keys: [],
  charts: {},
  refreshInterval: null,
  // New metrics state
  selectedPeriod: "day",
  customDateRange: { start: null, end: null },
  selectedApiKey: "",
  apiKeyList: [],
};

// --- Initialization ---

document.addEventListener("DOMContentLoaded", () => {
  initEvents();
  checkAuth();

  // Auto-refresh stats every 30 seconds
  state.refreshInterval = setInterval(() => {
    if (state.masterKey) refreshData();
  }, 30000);
});

function initLucide() {
  if (window.lucide) {
    try {
      window.lucide.createIcons();
    } catch (err) {
      console.error("Lucide error:", err);
    }
  } else {
    console.warn("Lucide library not found.");
  }
}

function formatRateLimits(limits) {
  if (!limits) return '<span class="text-muted">Unlimited</span>';

  const parts = [];
  if (limits.per_second) parts.push(`${limits.per_second}/s`);
  if (limits.per_minute) parts.push(`${limits.per_minute}/m`);
  if (limits.hourly) parts.push(`${limits.hourly}/h`);
  if (limits.daily) parts.push(`${limits.daily}/d`);
  if (limits.monthly) parts.push(`${limits.monthly}/mo`);

  if (parts.length === 0) return '<span class="text-muted">Unlimited</span>';
  return parts.join(" | ");
}

function initEvents() {
  // Tab switching
  document.querySelectorAll(".nav-links li").forEach((li) => {
    li.addEventListener("click", () => switchTab(li.dataset.tab));
  });

  // Top Bar Buttons
  document.getElementById("refresh-btn").addEventListener("click", refreshData);
  document
    .getElementById("setup-auth-btn")
    .addEventListener("click", showAuthModal);

  // Period selector buttons
  document.querySelectorAll(".period-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      document
        .querySelectorAll(".period-btn")
        .forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      state.selectedPeriod = btn.dataset.period;
      state.customDateRange = { start: null, end: null };
      // Clear date inputs
      document.getElementById("start-date").value = "";
      document.getElementById("end-date").value = "";
      fetchDashboardMetrics();
    });
  });

  // Date range picker
  document
    .getElementById("apply-date-range")
    .addEventListener("click", applyDateRange);

  // API key filter
  document.getElementById("api-key-select").addEventListener("change", (e) => {
    state.selectedApiKey = e.target.value;
    fetchDashboardMetrics();
  });

  // Auth Modal
  document.getElementById("login-btn").addEventListener("click", login);
  document
    .getElementById("master-key-input")
    .addEventListener("keypress", (e) => {
      if (e.key === "Enter") login();
    });

  // Create Key Button
  document
    .getElementById("create-key-btn")
    .addEventListener("click", showCreateKeyModal);

  // Event delegation for dynamic buttons (toggle, revoke, copy, close)
  document.addEventListener("click", (e) => {
    const target = e.target.closest("button");
    if (!target) return;

    const action = target.dataset.action;
    if (!action) return;

    if (action === "toggle-key") {
      toggleKey(target.dataset.hash, target.dataset.enabled === "true");
    } else if (action === "revoke-key") {
      revokeKey(target.dataset.hash);
    } else if (action === "edit-key") {
      showEditKeyModal(target.dataset.hash);
    } else if (action === "copy-key") {
      copyToClipboard(target.dataset.value, target);
    } else if (action === "close-modal") {
      closeModal();
    } else if (action === "confirm-create-key") {
      createKey();
    } else if (action === "confirm-edit-key") {
      updateKey(target.dataset.hash);
    }
  });
}

// --- Authentication ---

function checkAuth() {
  const authModal = document.getElementById("auth-modal");
  if (!state.masterKey) {
    authModal.classList.add("active");
  } else {
    authModal.classList.remove("active");
    document.getElementById("master-key-status").textContent = "Authenticated";
    document.getElementById("master-key-status").style.color =
      "var(--accent-green)";
    refreshData();
  }
}

function login() {
  const input = document.getElementById("master-key-input");
  const key = input.value.trim();
  if (key) {
    state.masterKey = key;
    localStorage.setItem("master_api_key", key);
    document.getElementById("auth-modal").classList.remove("active");
    document.getElementById("master-key-status").textContent = "Authenticated";
    document.getElementById("master-key-status").style.color =
      "var(--accent-green)";
    refreshData();
  }
}

function showAuthModal() {
  document.getElementById("auth-modal").classList.add("active");
}

// --- Navigation ---

function switchTab(tabId) {
  state.activeTab = tabId;

  // Update Sidebar
  document.querySelectorAll(".nav-links li").forEach((li) => {
    li.classList.toggle("active", li.dataset.tab === tabId);
  });

  // Update Content
  document.querySelectorAll(".tab-content").forEach((section) => {
    section.classList.toggle("active", section.id === `${tabId}-tab`);
  });

  // Update Title
  const titles = {
    overview: "Overview",
    "api-keys": "API Key Management",
    "system-health": "System Health",
  };
  document.getElementById("page-title").textContent = titles[tabId];

  // Refresh data for the specific tab
  if (tabId === "api-keys") fetchKeys();
  if (tabId === "overview") {
    updateOverviewStats();
    renderCharts();
  }
}

// --- Data Fetching ---

async function apiRequest(endpoint, options = {}) {
  const url = `/api/v1/admin${endpoint}`;
  const headers = {
    "x-api-key": state.masterKey,
    "Content-Type": "application/json",
    ...options.headers,
  };

  try {
    const response = await fetch(url, { ...options, headers });
    if (response.status === 401 || response.status === 403) {
      showAuthModal();
      return null;
    }
    if (!response.ok) throw new Error(`API Error: ${response.status}`);
    return await response.json();
  } catch (err) {
    console.error(`Request to ${endpoint} failed:`, err);
    return null;
  }
}

async function refreshData() {
  const btn = document.getElementById("refresh-btn");
  btn.classList.add("spinning");

  try {
    await Promise.all([fetchStats(), fetchKeys(), fetchDashboardMetrics(), fetchApiKeyList()]);
  } catch (err) {
    console.error("Refresh failed:", err);
  } finally {
    setTimeout(() => btn.classList.remove("spinning"), 500);
  }
}

function applyDateRange() {
  const startDate = document.getElementById("start-date").value;
  const endDate = document.getElementById("end-date").value;

  if (startDate && endDate) {
    state.customDateRange = { start: startDate, end: endDate };
    // Deactivate period buttons when custom range is used
    document
      .querySelectorAll(".period-btn")
      .forEach((b) => b.classList.remove("active"));
    fetchDashboardMetrics();
  }
}

async function fetchApiKeyList() {
  const keys = await metricsRequest("/api-keys");
  if (keys) {
    state.apiKeyList = keys;
    populateApiKeyDropdown();
  }
}

function populateApiKeyDropdown() {
  const select = document.getElementById("api-key-select");
  select.innerHTML =
    '<option value="">All API Keys</option>' +
    state.apiKeyList
      .map((k) => {
        const envIndicator = k.source === "environment" ? " [ENV]" : "";
        return `<option value="${k.key_hash}">${k.name}${envIndicator} (${k.key_prefix}...)</option>`;
      })
      .join("");
}

async function metricsRequest(endpoint, options = {}) {
  const url = `/api/v1/admin/metrics${endpoint}`;
  const headers = {
    "x-api-key": state.masterKey,
    "Content-Type": "application/json",
    ...options.headers,
  };

  try {
    const response = await fetch(url, { ...options, headers });
    if (response.status === 401 || response.status === 403) {
      showAuthModal();
      return null;
    }
    if (!response.ok) throw new Error(`API Error: ${response.status}`);
    return await response.json();
  } catch (err) {
    console.error(`Request to ${endpoint} failed:`, err);
    return null;
  }
}

function buildQueryParams() {
  const params = new URLSearchParams();
  params.set("period", state.selectedPeriod);

  if (state.customDateRange.start) {
    params.set("start_date", new Date(state.customDateRange.start).toISOString());
  }
  if (state.customDateRange.end) {
    params.set("end_date", new Date(state.customDateRange.end).toISOString());
  }
  if (state.selectedApiKey) {
    params.set("api_key_hash", state.selectedApiKey);
  }

  return params.toString();
}

async function fetchDashboardMetrics() {
  if (!state.masterKey) return;

  const params = buildQueryParams();

  const [summary, languages, timeSeries, heatmap] = await Promise.all([
    metricsRequest(`/summary?${params}`),
    metricsRequest(`/languages?${params}&stack_by_api_key=true`),
    metricsRequest(`/time-series?${params}`),
    metricsRequest(`/heatmap?${params}`),
  ]);

  if (summary) updateMetricsSummary(summary);
  if (languages) renderStackedLanguageChart(languages);
  if (timeSeries) renderTimeSeriesChart(timeSeries);
  if (heatmap) renderHeatmap(heatmap);
}

function updateMetricsSummary(summary) {
  document.getElementById("stat-exec-hour").textContent =
    summary.total_executions || 0;
  document.getElementById("stat-success-rate").textContent =
    `${(summary.success_rate || 0).toFixed(1)}%`;
  document.getElementById("stat-avg-time").textContent =
    `${Math.round(summary.avg_execution_time_ms || 0)}ms`;
  document.getElementById("stat-pool-hit").textContent =
    `${(summary.pool_hit_rate || 0).toFixed(1)}%`;
}

// Color palette for stacked charts
const chartColors = [
  "#38bdf8", // blue
  "#4ade80", // green
  "#c084fc", // purple
  "#f59e0b", // amber
  "#f87171", // red
  "#a78bfa", // violet
  "#2dd4bf", // teal
  "#fb923c", // orange
];

function getColorForIndex(idx) {
  return chartColors[idx % chartColors.length];
}

function renderStackedLanguageChart(data) {
  const canvas = document.getElementById("stackedLanguageChart");
  if (!canvas) return;

  const ctx = canvas.getContext("2d");
  if (state.charts.stackedLanguage) state.charts.stackedLanguage.destroy();

  const languages = Object.keys(data.by_language || {});
  const apiKeys = Object.keys(data.by_api_key || {});

  if (languages.length === 0) {
    // No data - show empty chart
    state.charts.stackedLanguage = new Chart(ctx, {
      type: "bar",
      data: { labels: ["No data"], datasets: [] },
      options: { responsive: true, maintainAspectRatio: false },
    });
    return;
  }

  // Build datasets for stacked bar
  const datasets = apiKeys.map((keyHash, idx) => ({
    label: keyHash.slice(0, 8),
    data: languages.map((lang) => data.matrix?.[lang]?.[keyHash] || 0),
    backgroundColor: getColorForIndex(idx),
    borderRadius: 4,
  }));

  // If no API key breakdown, show simple bar
  if (datasets.length === 0 || apiKeys.length === 0) {
    datasets.push({
      label: "Executions",
      data: languages.map((lang) => data.by_language[lang] || 0),
      backgroundColor: "#38bdf8",
      borderRadius: 4,
    });
  }

  state.charts.stackedLanguage = new Chart(ctx, {
    type: "bar",
    data: {
      labels: languages.map((l) => l.toUpperCase()),
      datasets,
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: apiKeys.length > 0,
          position: "top",
          labels: { color: "#94a3b8", boxWidth: 12 },
        },
      },
      scales: {
        x: {
          stacked: true,
          grid: { display: false },
          ticks: { color: "#94a3b8" },
        },
        y: {
          stacked: true,
          beginAtZero: true,
          grid: { color: "rgba(255,255,255,0.1)" },
          ticks: { color: "#94a3b8" },
        },
      },
    },
  });
}

function renderTimeSeriesChart(data) {
  const canvas = document.getElementById("timeSeriesChart");
  if (!canvas) return;

  const ctx = canvas.getContext("2d");
  if (state.charts.timeSeries) state.charts.timeSeries.destroy();

  if (!data.timestamps || data.timestamps.length === 0) {
    state.charts.timeSeries = new Chart(ctx, {
      type: "line",
      data: { labels: ["No data"], datasets: [] },
      options: { responsive: true, maintainAspectRatio: false },
    });
    return;
  }

  state.charts.timeSeries = new Chart(ctx, {
    type: "line",
    data: {
      labels: data.timestamps,
      datasets: [
        {
          label: "Executions",
          data: data.executions,
          borderColor: "#38bdf8",
          backgroundColor: "rgba(56, 189, 248, 0.1)",
          fill: true,
          tension: 0.3,
          yAxisID: "y",
        },
        {
          label: "Success Rate %",
          data: data.success_rate,
          borderColor: "#4ade80",
          borderDash: [5, 5],
          tension: 0.3,
          yAxisID: "y1",
        },
        {
          label: "Avg Duration (ms)",
          data: data.avg_duration,
          borderColor: "#c084fc",
          borderDash: [2, 2],
          tension: 0.3,
          yAxisID: "y2",
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: {
          display: true,
          position: "top",
          labels: { color: "#94a3b8", boxWidth: 12 },
        },
      },
      scales: {
        x: {
          grid: { color: "rgba(255,255,255,0.05)" },
          ticks: { color: "#94a3b8", maxTicksLimit: 12 },
        },
        y: {
          type: "linear",
          display: true,
          position: "left",
          title: { display: true, text: "Executions", color: "#38bdf8" },
          grid: { color: "rgba(255,255,255,0.1)" },
          ticks: { color: "#94a3b8" },
        },
        y1: {
          type: "linear",
          display: true,
          position: "right",
          min: 0,
          max: 100,
          title: { display: true, text: "Success %", color: "#4ade80" },
          grid: { drawOnChartArea: false },
          ticks: { color: "#94a3b8" },
        },
        y2: {
          type: "linear",
          display: false,
          position: "right",
          grid: { drawOnChartArea: false },
        },
      },
    },
  });
}

function renderHeatmap(data) {
  const container = document.getElementById("heatmapContainer");
  if (!container) return;

  const days = data.days || ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  const hours = data.hours || Array.from({ length: 24 }, (_, i) => i);
  const matrix = data.matrix || [];
  const maxValue = data.max_value || 1;

  // Build table HTML
  let html = '<table class="heatmap-table"><thead><tr><th></th>';
  hours.forEach((h) => {
    html += `<th>${h}</th>`;
  });
  html += "</tr></thead><tbody>";

  days.forEach((day, dayIdx) => {
    html += `<tr><td class="day-label">${day}</td>`;
    hours.forEach((hour) => {
      const value = matrix[dayIdx]?.[hour] || 0;
      const intensity = maxValue > 0 ? Math.min(value / maxValue, 1) : 0;
      const alpha = 0.1 + intensity * 0.9;
      const color = `rgba(56, 189, 248, ${alpha.toFixed(2)})`;
      html += `<td class="heatmap-cell" style="background:${color}" title="${day} ${hour}:00 - ${value} executions"></td>`;
    });
    html += "</tr>";
  });

  html += "</tbody></table>";
  container.innerHTML = html;
}

async function fetchStats() {
  const stats = await apiRequest("/stats");
  if (stats) {
    state.stats = stats;
    updateOverviewStats();
    renderCharts();
    renderHealth(stats.health);
  }
}

async function fetchKeys() {
  const keys = await apiRequest("/keys");
  if (keys) {
    state.keys = keys;
    renderKeysTable();
  }
}

// --- Overview ---

function updateOverviewStats() {
  if (!state.stats || !state.stats.summary) return;
  const { summary } = state.stats;

  document.getElementById("stat-exec-hour").textContent =
    summary.total_executions_hour || 0;
  document.getElementById("stat-success-rate").textContent =
    `${(summary.success_rate || 0).toFixed(1)}%`;
  document.getElementById("stat-avg-time").textContent =
    `${Math.round(summary.avg_execution_time_ms || 0)}ms`;
  document.getElementById("stat-pool-hit").textContent =
    `${(summary.pool_hit_rate || 0).toFixed(1)}%`;
}

function renderCharts() {
  const canvas = document.getElementById("languagesChart");
  if (
    !canvas ||
    !state.stats ||
    !state.stats.summary ||
    !state.stats.summary.top_languages
  )
    return;

  if (typeof Chart === "undefined") {
    canvas.parentElement.innerHTML =
      '<p class="text-muted" style="padding: 2rem; text-align: center;">Chart.js library blocked by CSP or failed to load.</p>';
    return;
  }

  try {
    const ctx = canvas.getContext("2d");
    if (state.charts.languages) state.charts.languages.destroy();

    const languages = state.stats.summary.top_languages;
    state.charts.languages = new Chart(ctx, {
      type: "bar",
      data: {
        labels: languages.map((l) => l.language.toUpperCase()),
        datasets: [
          {
            label: "Executions",
            data: languages.map((l) => l.count),
            backgroundColor: "#38bdf8",
            borderRadius: 8,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: { color: "rgba(255,255,255,0.1)" },
            ticks: { color: "#94a3b8" },
          },
          x: { grid: { display: false }, ticks: { color: "#94a3b8" } },
        },
      },
    });
  } catch (err) {
    console.error("Error rendering chart:", err);
  }
}

// --- API Keys Table ---

function renderKeysTable() {
  const tbody = document.getElementById("keys-tbody");
  if (!tbody) return;

  if (state.keys.length === 0) {
    tbody.innerHTML =
      '<tr><td colspan="7" style="text-align: center; color: var(--text-muted); padding: 3rem;">No API keys found.</td></tr>';
    return;
  }

  tbody.innerHTML = state.keys
    .map((key) => {
      const isEnvKey = key.source === "environment";
      const statusBadge = isEnvKey
        ? '<span class="badge badge-warning">Environment</span>'
        : `<span class="badge ${key.enabled ? "badge-success" : "badge-danger"}">${key.enabled ? "Active" : "Disabled"}</span>`;

      const actionsHtml = isEnvKey
        ? '<span class="text-muted" style="font-size: 0.75rem;">Read-only</span>'
        : `
                <button class="btn btn-sm" data-action="edit-key" data-hash="${key.key_hash}" title="Edit">
                    <i data-lucide="edit-2" style="width: 14px;"></i>
                </button>
                <button class="btn btn-sm" data-action="toggle-key" data-hash="${key.key_hash}" data-enabled="${key.enabled}" title="${key.enabled ? "Pause" : "Activate"}">
                    <i data-lucide="${key.enabled ? "pause" : "play"}" style="width: 14px;"></i>
                </button>
                <button class="btn btn-sm btn-danger" data-action="revoke-key" data-hash="${key.key_hash}" title="Revoke">
                    <i data-lucide="trash-2" style="width: 14px;"></i>
                </button>`;

      return `
        <tr${isEnvKey ? ' style="background: rgba(251, 191, 36, 0.05);"' : ""}>
            <td>${key.name || "Unnamed"}</td>
            <td><code>${key.key_prefix || "---"}...</code></td>
            <td>${statusBadge}</td>
            <td>${new Date(key.created_at).toLocaleDateString()}</td>
            <td>${key.usage_count || 0}</td>
            <td>${formatRateLimits(key.rate_limits)}</td>
            <td class="actions-cell">${actionsHtml}</td>
        </tr>`;
    })
    .join("");

  initLucide();
}

async function toggleKey(hash, currentlyEnabled) {
  const success = await apiRequest(`/keys/${hash}`, {
    method: "PATCH",
    body: JSON.stringify({ enabled: !currentlyEnabled }),
  });
  if (success) fetchKeys();
}

async function revokeKey(hash) {
  if (
    !confirm(
      "Are you sure you want to revoke this API key? This action cannot be undone.",
    )
  )
    return;
  const success = await apiRequest(`/keys/${hash}`, {
    method: "DELETE",
  });
  if (success) fetchKeys();
}

// --- Key Creation & Modals ---

function showCreateKeyModal() {
  const modalHtml = `
        <div class="modal modal-wide">
            <div class="modal-header"><h2>Create New API Key</h2></div>
            <div class="modal-body">
                <div class="form-group">
                    <label for="new-key-name">Key Name</label>
                    <input type="text" id="new-key-name" placeholder="e.g. Production Frontend">
                </div>
                <h4 style="margin: 1.5rem 0 0.75rem; color: var(--text-muted);">Rate Limits (leave empty for unlimited)</h4>
                <div class="rate-limits-grid">
                    <div class="form-group">
                        <label for="limit-per-second">Per Second</label>
                        <input type="number" id="limit-per-second" placeholder="e.g. 10" min="1">
                    </div>
                    <div class="form-group">
                        <label for="limit-per-minute">Per Minute</label>
                        <input type="number" id="limit-per-minute" placeholder="e.g. 100" min="1">
                    </div>
                    <div class="form-group">
                        <label for="limit-hourly">Hourly</label>
                        <input type="number" id="limit-hourly" placeholder="e.g. 1000" min="1">
                    </div>
                    <div class="form-group">
                        <label for="limit-daily">Daily</label>
                        <input type="number" id="limit-daily" placeholder="e.g. 10000" min="1">
                    </div>
                    <div class="form-group">
                        <label for="limit-monthly">Monthly</label>
                        <input type="number" id="limit-monthly" placeholder="e.g. 100000" min="1">
                    </div>
                </div>
            </div>
            <div class="modal-footer">
                <button class="btn" data-action="close-modal">Cancel</button>
                <button class="btn btn-success" data-action="confirm-create-key">Create Key</button>
            </div>
        </div>
    `;
  const container = document.getElementById("modal-container");
  container.innerHTML = modalHtml;
  container.classList.add("active");
}

async function createKey() {
  const input = document.getElementById("new-key-name");
  if (!input) return;
  const name = input.value.trim();
  if (!name) return alert("Please enter a key name.");

  // Collect rate limits (empty string or 0 becomes null)
  const getLimit = (id) => {
    const val = parseInt(document.getElementById(id)?.value);
    return val > 0 ? val : null;
  };

  const rateLimits = {
    per_second: getLimit("limit-per-second"),
    per_minute: getLimit("limit-per-minute"),
    hourly: getLimit("limit-hourly"),
    daily: getLimit("limit-daily"),
    monthly: getLimit("limit-monthly"),
  };

  // Only include rate_limits if at least one is set
  const hasLimits = Object.values(rateLimits).some((v) => v !== null);

  const result = await apiRequest("/keys", {
    method: "POST",
    body: JSON.stringify({
      name,
      rate_limits: hasLimits ? rateLimits : null,
    }),
  });

  if (result) {
    closeModal();
    showKeyDetails(result.api_key, result.record.name);
    fetchKeys();
  }
}

function showKeyDetails(key, name) {
  const modalHtml = `
        <div class="modal">
            <div class="modal-header"><h2>Key Created: ${name}</h2></div>
            <div class="modal-body">
                <p style="color: var(--accent-red); font-weight: bold; margin-bottom: 1rem;">
                    SAVE THIS KEY NOW! It will never be shown again.
                </p>
                <div class="form-group">
                    <label>Full API Key</label>
                    <div style="display: flex; gap: 0.5rem;">
                        <input type="text" value="${key}" readonly id="new-key-value" style="flex-grow: 1;">
                        <button class="btn btn-icon" data-action="copy-key" data-value="${key}">
                            <i data-lucide="copy"></i>
                        </button>
                    </div>
                </div>
            </div>
            <div class="modal-footer">
                <button class="btn btn-primary" data-action="close-modal">Done</button>
            </div>
        </div>
    `;
  const container = document.getElementById("modal-container");
  container.innerHTML = modalHtml;
  container.classList.add("active");
  initLucide();
}

function closeModal() {
  document.getElementById("modal-container").classList.remove("active");
}

function showEditKeyModal(keyHash) {
  const key = state.keys.find((k) => k.key_hash === keyHash);
  if (!key) return;

  const limits = key.rate_limits || {};
  const modalHtml = `
        <div class="modal modal-wide">
            <div class="modal-header"><h2>Edit Key: ${key.name}</h2></div>
            <div class="modal-body">
                <div class="form-group">
                    <label for="edit-key-name">Key Name</label>
                    <input type="text" id="edit-key-name" value="${key.name || ""}">
                </div>
                <h4 style="margin: 1.5rem 0 0.75rem; color: var(--text-muted);">Rate Limits (leave empty for unlimited)</h4>
                <div class="rate-limits-grid">
                    <div class="form-group">
                        <label for="edit-limit-per-second">Per Second</label>
                        <input type="number" id="edit-limit-per-second" value="${limits.per_second || ""}" min="1">
                    </div>
                    <div class="form-group">
                        <label for="edit-limit-per-minute">Per Minute</label>
                        <input type="number" id="edit-limit-per-minute" value="${limits.per_minute || ""}" min="1">
                    </div>
                    <div class="form-group">
                        <label for="edit-limit-hourly">Hourly</label>
                        <input type="number" id="edit-limit-hourly" value="${limits.hourly || ""}" min="1">
                    </div>
                    <div class="form-group">
                        <label for="edit-limit-daily">Daily</label>
                        <input type="number" id="edit-limit-daily" value="${limits.daily || ""}" min="1">
                    </div>
                    <div class="form-group">
                        <label for="edit-limit-monthly">Monthly</label>
                        <input type="number" id="edit-limit-monthly" value="${limits.monthly || ""}" min="1">
                    </div>
                </div>
            </div>
            <div class="modal-footer">
                <button class="btn" data-action="close-modal">Cancel</button>
                <button class="btn btn-primary" data-action="confirm-edit-key" data-hash="${keyHash}">Save Changes</button>
            </div>
        </div>
    `;
  const container = document.getElementById("modal-container");
  container.innerHTML = modalHtml;
  container.classList.add("active");
}

async function updateKey(keyHash) {
  const name = document.getElementById("edit-key-name")?.value.trim();

  // Collect rate limits (empty string or 0 becomes null)
  const getLimit = (id) => {
    const val = parseInt(document.getElementById(id)?.value);
    return val > 0 ? val : null;
  };

  const rateLimits = {
    per_second: getLimit("edit-limit-per-second"),
    per_minute: getLimit("edit-limit-per-minute"),
    hourly: getLimit("edit-limit-hourly"),
    daily: getLimit("edit-limit-daily"),
    monthly: getLimit("edit-limit-monthly"),
  };

  const result = await apiRequest(`/keys/${keyHash}`, {
    method: "PATCH",
    body: JSON.stringify({
      name,
      rate_limits: rateLimits,
    }),
  });

  if (result) {
    closeModal();
    fetchKeys();
  }
}

function copyToClipboard(text, btn) {
  navigator.clipboard.writeText(text).then(() => {
    if (btn) {
      const originalIcon = btn.innerHTML;
      btn.innerHTML =
        '<i data-lucide="check" style="color: var(--accent-green)"></i>';
      initLucide();
      setTimeout(() => {
        btn.innerHTML = originalIcon;
        initLucide();
      }, 2000);
    }
  });
}

// --- System Health ---

function renderHealth(health) {
  const grid = document.getElementById("health-grid");
  if (!grid || !health) return;

  const services = health.services || health;

  grid.innerHTML = Object.entries(services)
    .map(([service, data]) => {
      const isHealthy = data.status === "healthy";
      return `
            <div class="stat-card">
                <div class="stat-icon ${isHealthy ? "success" : "danger"}">
                    <i data-lucide="${getHealthIcon(service)}"></i>
                </div>
                <div class="stat-info">
                    <span class="stat-label">${service.toUpperCase()}</span>
                    <span class="stat-value">${data.status}</span>
                    <small class="text-muted" style="display: block; margin-top: 0.25rem;">
                        ${data.response_time_ms ? Math.round(data.response_time_ms) + "ms" : "---"}
                    </small>
                </div>
            </div>
        `;
    })
    .join("");

  initLucide();
}

function getHealthIcon(service) {
  switch (service.toLowerCase()) {
    case "redis":
      return "database";
    case "docker":
      return "box";
    case "minio":
      return "hard-drive";
    case "container_pool":
      return "layers";
    default:
      return "activity";
  }
}
