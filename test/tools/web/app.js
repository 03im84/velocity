"use strict";

const state = {
  csrf: "",
  app: {},
  tests: [],
  suites: [],
  execution: {},
  delivery: {},
  settings: {},
  environment: {},
  server: {},
  roadmap: {},
  activeTab: "tests",
  eventSource: null,
  eventCursor: 0,
};

let deliveryPromptActive = false;

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => Array.from(document.querySelectorAll(selector));
const MAX_TERMINAL_CHARS = 1_500_000;
const TRIMMED_TERMINAL_CHARS = 1_000_000;
const outputQueues = new Map();

async function api(path, options = {}) {
  const request = {
    credentials: "same-origin",
    headers: { "Content-Type": "application/json" },
    ...options,
  };
  if (request.method && request.method !== "GET") {
    request.headers["X-VTD-CSRF"] = state.csrf;
  }
  const response = await fetch(path, request);
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload.error || `HTTP ${response.status}`);
  }
  return payload;
}

function setStatus(text, kind = "") {
  const line = $("#status-line");
  line.textContent = text;
  line.className = `status-line ${kind}`;
}

function applyTheme(theme, persist = true) {
  if (!["light", "dark", "reading"].includes(theme)) return;
  document.documentElement.dataset.theme = theme;
  $("#theme-select").value = theme;
  $("#settings-theme").value = theme;
  if (persist) localStorage.setItem("vtd-theme", theme);
}

function switchTab(tabName) {
  state.activeTab = tabName;
  $$(".tab").forEach((button) => {
    button.classList.toggle("active", button.dataset.tab === tabName);
  });
  $$(".panel-view").forEach((panel) => {
    panel.classList.toggle("active", panel.id === `${tabName}-panel`);
  });
}

function renderTests() {
  const suiteSelect = $("#suite-select");
  const previousSuite = suiteSelect.value || "All";
  suiteSelect.replaceChildren();
  state.suites.forEach((suite) => {
    const option = document.createElement("option");
    option.value = suite;
    option.textContent = suite;
    suiteSelect.append(option);
  });
  suiteSelect.value = state.suites.includes(previousSuite)
    ? previousSuite
    : "All";
  renderTestOptions();
}

function renderTestOptions() {
  const search = $("#test-search").value.trim().toLowerCase();
  const suite = $("#suite-select").value || "All";
  const select = $("#test-select");
  const previous = select.value;
  select.replaceChildren();
  state.tests
    .filter((test) => suite === "All" || test.suite === suite)
    .filter((test) => {
      const haystack = `${test.name} ${test.relative_path}`.toLowerCase();
      return !search || haystack.includes(search);
    })
    .forEach((test) => {
      const option = document.createElement("option");
      option.value = test.resource_path;
      option.textContent = `${test.name} · ${test.suite}`;
      select.append(option);
    });
  if (Array.from(select.options).some((option) => option.value === previous)) {
    select.value = previous;
  }
}

function renderExecution() {
  const execution = state.execution || {};
  const summary = execution.summary || {};
  const results = execution.results || [];
  $("#execution-badge").textContent = execution.running ? "RUNNING" : "IDLE";
  $("#plan-label").textContent = execution.label || "ningún plan";
  const checklist = $("#plan-checklist");
  checklist.replaceChildren();
  results.forEach((result) => {
    const item = document.createElement("li");
    item.className = statusClass(result.status);
    item.textContent = `${statusMark(result.status)} ${result.test.name}`;
    checklist.append(item);
  });

  const planned = Number(summary.planned || 0);
  const completed = Number(summary.completed || 0);
  const percent = planned ? Math.round((completed / planned) * 100) : 0;
  $("#progress-bar").style.width = `${percent}%`;
  $("#progress-text").textContent = `${completed} / ${planned} · ${percent}%`;
  $("#metric-checks").textContent = summary.checks || 0;
  $("#metric-failures").textContent = summary.check_failures || 0;
  $("#metric-missing").textContent = summary.missing_metrics || 0;
  $("#header-summary").textContent = execution.running
    ? `${completed}/${planned} · ${summary.checks || 0} checks`
    : "idle";

  const finalSummary = $("#final-summary");
  const finalText = formatExecutionSummary(execution);
  finalSummary.textContent = finalText;
  finalSummary.classList.toggle("hidden", !finalText);

  const body = $("#results-table tbody");
  body.replaceChildren();
  results.forEach((result) => {
    const row = document.createElement("tr");
    [
      result.test.name,
      result.status,
      result.checks || "—",
      result.check_failures || "—",
      result.duration_seconds ? `${result.duration_seconds.toFixed(2)}s` : "—",
    ].forEach((value, index) => {
      const cell = document.createElement("td");
      cell.textContent = String(value);
      if (index === 1) cell.className = statusClass(result.status);
      row.append(cell);
    });
    body.append(row);
  });
  updateActionStates();
}

function renderDelivery() {
  const delivery = state.delivery || {};
  $("#delivery-badge").textContent = delivery.operation || "IDLE";
  $("#package-path").textContent = delivery.selected_package || "ninguno";
  $("#package-path").title = delivery.selected_package || "";
  $("#receipt-state").textContent = delivery.receipt_state || "none";
  $("#env-delivery").textContent = delivery.delivery_id || "none";
  $("#env-delivery").title = delivery.delivery_id || "";
  updateActionStates();
}

function renderEnvironment() {
  $("#env-version").textContent = state.app.version || "—";
  $("#env-project").textContent = state.environment.project_root || "—";
  $("#env-project").title = state.environment.project_root || "";
  $("#env-server").textContent = state.server.url || "—";
  $("#env-python").textContent = state.environment.python || "—";
}

function renderRoadmap() {
  const roadmap = state.roadmap || {};
  const milestones = roadmap.milestones || [];
  const phaseCount = Number(roadmap.phase_count || 1);
  const currentId = roadmap.current_milestone || "";
  const targetId = roadmap.target || "";
  const current = milestones.find((item) => item.id === currentId);
  const target = milestones.find((item) => item.id === targetId);
  $("#roadmap-target").textContent = target ? target.name : targetId || "—";
  $("#roadmap-current-name").textContent = current ? current.name : currentId || "—";
  $("#roadmap-completed").textContent = `${milestones.filter((item) => item.status === "completed").length} / ${milestones.length}`;

  const grid = $("#gantt-grid");
  grid.replaceChildren();
  grid.style.gridTemplateColumns = `240px repeat(${phaseCount}, minmax(34px, 1fr))`;

  const corner = document.createElement("div");
  corner.className = "gantt-label label";
  corner.textContent = "milestone / phase";
  corner.style.gridRow = "1";
  corner.style.gridColumn = "1";
  grid.append(corner);

  for (let phase = 1; phase <= phaseCount; phase += 1) {
    const header = document.createElement("div");
    header.className = "gantt-cell gantt-phase";
    header.textContent = `P${phase}`;
    header.style.gridRow = "1";
    header.style.gridColumn = String(phase + 1);
    grid.append(header);
  }

  milestones.forEach((milestone, index) => {
    const row = index + 2;
    const label = document.createElement("div");
    label.className = `gantt-label${milestone.id === currentId ? " current" : ""}`;
    label.textContent = `${milestone.group} · ${milestone.name}`;
    label.title = milestone.name;
    label.style.gridRow = String(row);
    label.style.gridColumn = "1";
    grid.append(label);

    for (let phase = 1; phase <= phaseCount; phase += 1) {
      const cell = document.createElement("div");
      cell.className = "gantt-cell";
      cell.style.gridRow = String(row);
      cell.style.gridColumn = String(phase + 1);
      grid.append(cell);
    }

    const bar = document.createElement("button");
    bar.className = `gantt-bar ${milestone.status}`;
    bar.textContent = `${milestone.progress}% ${milestone.id === currentId ? "· YOU ARE HERE" : ""}`;
    bar.style.gridRow = String(row);
    bar.style.gridColumn = `${Number(milestone.phase) + 1} / span ${Number(milestone.duration)}`;
    bar.addEventListener("click", () => renderMilestoneDetail(milestone, milestones));
    grid.append(bar);
  });

  if (current) renderMilestoneDetail(current, milestones);
}

function renderMilestoneDetail(milestone, milestones) {
  const detail = $("#milestone-detail");
  detail.replaceChildren();
  const title = document.createElement("h2");
  title.textContent = `${milestone.name}${milestone.id === state.roadmap.current_milestone ? " · YOU ARE HERE" : ""}`;
  detail.append(title);
  const grid = document.createElement("div");
  grid.className = "detail-grid";

  const rows = [
    ["status", milestone.status],
    ["progress", `${milestone.progress}%`],
    ["phase", `P${milestone.phase} · duration ${milestone.duration}`],
    ["purpose", milestone.purpose || "—"],
    ["dependencies", (milestone.dependencies || []).map((id) => milestones.find((item) => item.id === id)?.name || id).join(", ") || "none"],
    ["commit", milestone.commit || "pending"],
  ];
  rows.forEach(([name, value]) => {
    const key = document.createElement("div");
    key.className = "label";
    key.textContent = name;
    const content = document.createElement("div");
    content.textContent = value;
    grid.append(key, content);
  });
  detail.append(grid);

  [["deliverables", milestone.deliverables], ["acceptance", milestone.acceptance]].forEach(([heading, values]) => {
    const subtitle = document.createElement("div");
    subtitle.className = "label";
    subtitle.textContent = heading;
    const list = document.createElement("ul");
    list.className = "detail-list";
    (values || []).forEach((value) => {
      const item = document.createElement("li");
      item.textContent = value;
      list.append(item);
    });
    detail.append(subtitle, list);
  });
}

function renderSettings() {
  const settings = state.settings;
  const browser = settings.browser || {};
  const server = settings.server || {};
  applyTheme(settings.theme || "dark", false);
  $("#browser-select").value = browser.mode || "system_default";
  $("#window-mode").value = browser.window_mode || "tab";
  $("#browser-path").value = browser.executable || "";
  $("#server-port").value = Number(server.port || 0);
  $("#godot-path").value = settings.godot_console || "";
  $("#repeat-input").value = Number(settings.repeat || 1);
  $("#timeout-input").value = Number(settings.timeout_seconds || 10);
  updateCustomBrowserVisibility();
}

function updateActionStates() {
  const testBusy = Boolean(state.execution && state.execution.running);
  const deliveryBusy = Boolean(state.delivery && state.delivery.busy);
  const blocked = testBusy || deliveryBusy;
  $("#run-selected").disabled = blocked || !$("#test-select").value;
  $("#run-suite").disabled = blocked;
  $("#run-all").disabled = blocked;
  $("#pause-plan").disabled = !testBusy;
  $("#resume-plan").disabled = blocked;
  $("#stop-plan").disabled = !testBusy;
  $("#refresh-tests").disabled = blocked;
  $("#select-package").disabled = blocked;
  $("#install-package").disabled = blocked || !state.delivery.selected_package;
  $("#prepare-submit").disabled = blocked || state.delivery.receipt_state === "none";
  $("#rollback-delivery").disabled = blocked || state.delivery.receipt_state !== "installed";
  $("#shutdown-button").disabled = deliveryBusy;
}

function appendOutput(selector, text) {
  let queue = outputQueues.get(selector);
  if (!queue) {
    queue = { chunks: [], scheduled: false };
    outputQueues.set(selector, queue);
  }
  queue.chunks.push(text);
  if (queue.scheduled) return;
  queue.scheduled = true;
  setTimeout(() => flushOutput(selector), 50);
}

function flushOutput(selector) {
  const queue = outputQueues.get(selector);
  if (!queue) return;
  queue.scheduled = false;
  if (!queue.chunks.length) return;
  const terminal = $(selector);
  const chunk = queue.chunks.join("");
  queue.chunks.length = 0;
  terminal.append(document.createTextNode(chunk));
  if (terminal.textContent.length > MAX_TERMINAL_CHARS) {
    terminal.textContent = terminal.textContent.slice(-TRIMMED_TERMINAL_CHARS);
  }
  if (state.settings.auto_scroll !== false) {
    terminal.scrollTop = terminal.scrollHeight;
  }
}

function clearTerminal(selector) {
  const queue = outputQueues.get(selector);
  if (queue) queue.chunks.length = 0;
  $(selector).replaceChildren();
}

function addHistory(text, kind = "") {
  const list = $("#history-list");
  const empty = list.querySelector(".muted");
  if (empty) empty.remove();
  const item = document.createElement("div");
  item.className = `history-entry ${kind}`;
  item.textContent = `${new Date().toLocaleTimeString()} · ${text}`;
  list.prepend(item);
}

function statusClass(status = "") {
  return String(status).toLowerCase().replaceAll(" ", "_");
}

function statusMark(status) {
  if (status === "PASS") return "✓";
  if (["FAIL", "ENGINE_ERROR", "CONFIG_ERROR"].includes(status)) return "×";
  if (status === "RUNNING") return "›";
  return "·";
}

function formatExecutionSummary(execution) {
  if (!execution || execution.running) return "";
  const status = execution.final_status || "IDLE";
  if (["IDLE", "RUNNING"].includes(status)) return "";
  const summary = execution.summary || {};
  const exitCode = summary.plan_exit_code === null
    || summary.plan_exit_code === undefined
    ? "N/A"
    : String(summary.plan_exit_code);
  return [
    "DASHBOARD EXECUTION PLAN SUMMARY",
    "================================",
    `Plan: ${execution.label || "—"}`,
    `Planned: ${summary.planned || 0}`,
    `Completed: ${summary.completed || 0}`,
    `Passed: ${summary.passed || 0}`,
    `Failed: ${summary.failed || 0}`,
    `Timeout: ${summary.timeout || 0}`,
    `Engine Error: ${summary.engine_error || 0}`,
    `Not Run: ${summary.not_run || 0}`,
    `Total Runs: ${summary.total_runs || 0}`,
    `Checks: ${summary.checks || 0}`,
    `Check Failures: ${summary.check_failures || 0}`,
    `Missing Metrics: ${summary.missing_metrics || 0}`,
    `Plan ExitCode: ${exitCode}`,
    `RESULT: ${summary.result || status}`,
  ].join("\n");
}

async function handleDeliveryPrompt(data) {
  const promptText = data.prompt || "";
  if (!promptText || deliveryPromptActive) return;

  deliveryPromptActive = true;
  try {
    const snapshot = await api("/api/state");
    const currentDelivery = snapshot.delivery || {};
    state.delivery = currentDelivery;
    renderDelivery();
    if (currentDelivery.pending_prompt !== promptText) return;

    let answer = "";
    if (promptText.includes("ROLLBACK")) {
      answer = window.prompt(promptText) || "";
    } else if (promptText.includes("SUBMIT")) {
      answer = window.prompt(promptText) || "";
    } else if (promptText.toLowerCase().includes("delete")) {
      answer = window.confirm(promptText) ? "y" : "n";
    } else if (promptText.includes("PUSH")) {
      answer = window.prompt(promptText) || "";
    }
    await post("/api/delivery/answer", { answer });
  } finally {
    deliveryPromptActive = false;
  }
}

function connectEvents(afterEventId = 0) {
  if (state.eventSource) state.eventSource.close();
  const cursor = Math.max(0, Number(afterEventId) || 0);
  const source = new EventSource(`/api/events?after=${encodeURIComponent(cursor)}`);
  state.eventSource = source;

  source.addEventListener("output", (event) => {
    const data = JSON.parse(event.data);
    appendOutput("#test-output", data.text || "");
  });
  source.addEventListener("test_started", (event) => {
    const data = JSON.parse(event.data);
    state.execution = data.plan;
    renderExecution();
    addHistory(`inició ${data.result.test.name}`);
  });
  source.addEventListener("test_finished", (event) => {
    const data = JSON.parse(event.data);
    state.execution = data.plan;
    renderExecution();
    addHistory(`${data.result.test.name}: ${data.result.status}`, statusClass(data.result.status));
  });
  source.addEventListener("plan_started", (event) => {
    state.execution = JSON.parse(event.data);
    clearTerminal("#test-output");
    renderExecution();
  });
  source.addEventListener("plan_state", (event) => {
    state.execution = JSON.parse(event.data);
    renderExecution();
  });
  source.addEventListener("plan_finished", (event) => {
    state.execution = JSON.parse(event.data);
    renderExecution();
    const summary = formatExecutionSummary(state.execution);
    if (summary) {
      appendOutput(
        "#test-output",
        `\n============================================================\n${summary}\n============================================================\n`,
      );
    }
    addHistory(
      `plan finalizado: ${state.execution.label} · ${state.execution.final_status}`,
      statusClass(state.execution.final_status),
    );
  });
  source.addEventListener("tests_refreshed", (event) => {
    const data = JSON.parse(event.data);
    state.tests = data.tests;
    state.suites = data.suites;
    renderTests();
  });
  source.addEventListener("roadmap_updated", (event) => {
    state.roadmap = JSON.parse(event.data);
    renderRoadmap();
  });
  source.addEventListener("delivery_output", (event) => {
    const data = JSON.parse(event.data);
    appendOutput("#delivery-output", data.text || "");
  });
  source.addEventListener("delivery_state", (event) => {
    state.delivery = JSON.parse(event.data);
    renderDelivery();
  });
  source.addEventListener("delivery_prompt", (event) => {
    void handleDeliveryPrompt(JSON.parse(event.data));
  });
  source.addEventListener("settings_changed", (event) => {
    const data = JSON.parse(event.data);
    state.settings = data.settings;
    renderSettings();
  });
  source.addEventListener("shutdown", (event) => {
    const data = JSON.parse(event.data);
    setStatus("apagando servidor…", "warning");
    setTimeout(() => window.close(), Math.min(150, data.delay_ms || 750));
  });
  source.onerror = () => setStatus("conexión con backend interrumpida", "warning");
}

async function post(path, body = {}) {
  try {
    const result = await api(path, {
      method: "POST",
      body: JSON.stringify(body),
    });
    setStatus("operación aceptada", "pass");
    return result;
  } catch (error) {
    setStatus(error.message, "fail");
    throw error;
  }
}

function updateCustomBrowserVisibility() {
  const custom = $("#browser-select").value === "custom";
  $("#custom-browser-row").classList.toggle("hidden", !custom);
}

function settingsPayload() {
  return {
    theme: $("#settings-theme").value,
    godot_console: $("#godot-path").value.trim(),
    repeat: Number($("#repeat-input").value || 1),
    timeout_seconds: Number($("#timeout-input").value || 10),
    browser: {
      mode: $("#browser-select").value,
      executable: $("#browser-path").value.trim(),
      window_mode: $("#window-mode").value,
    },
    server: {
      host: "127.0.0.1",
      port: Number($("#server-port").value || 0),
      shutdown_delay_ms: Number(state.settings.server.shutdown_delay_ms || 750),
    },
  };
}

async function waitForExecutionStop() {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    const snapshot = await api("/api/state");
    state.execution = snapshot.execution;
    renderExecution();
    if (!state.execution.running) return;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("El runner no se detuvo a tiempo.");
}

async function shutdownDashboard() {
  if (state.execution && state.execution.running) {
    const stop = window.confirm("Hay un plan activo. ¿Detenerlo y apagar VTD?");
    if (!stop) return;
    await post("/api/run/stop");
    await waitForExecutionStop();
  } else if (!window.confirm("¿Apagar Velocity Tooling Dashboard?")) {
    return;
  }

  const result = await post("/api/shutdown/request");
  setStatus("apagando…", "warning");
  setTimeout(() => window.close(), Math.min(150, result.delay_ms || 750));
}

function bindActions() {
  $$(".tab").forEach((button) => {
    button.addEventListener("click", () => switchTab(button.dataset.tab));
  });
  $("#theme-select").addEventListener("change", (event) => applyTheme(event.target.value));
  $("#settings-theme").addEventListener("change", (event) => applyTheme(event.target.value));
  $("#clear-test-output").addEventListener("click", () => clearTerminal("#test-output"));
  $("#clear-delivery-output").addEventListener("click", () => clearTerminal("#delivery-output"));
  $("#clear-history").addEventListener("click", () => {
    if (!window.confirm("¿Borrar el historial visual de esta sesión?")) return;
    $("#history-list").replaceChildren();
  });
  $("#suite-select").addEventListener("change", renderTestOptions);
  $("#test-search").addEventListener("input", renderTestOptions);
  $("#test-select").addEventListener("change", updateActionStates);

  $("#run-selected").addEventListener("click", () => post("/api/run", {
    mode: "selected",
    resource_path: $("#test-select").value,
    repeat: Number($("#repeat-input").value || 1),
    timeout_seconds: Number($("#timeout-input").value || 10),
  }));
  $("#run-suite").addEventListener("click", () => post("/api/run", {
    mode: "suite",
    suite: $("#suite-select").value,
    repeat: Number($("#repeat-input").value || 1),
    timeout_seconds: Number($("#timeout-input").value || 10),
  }));
  $("#run-all").addEventListener("click", () => post("/api/run", {
    mode: "all",
    repeat: Number($("#repeat-input").value || 1),
    timeout_seconds: Number($("#timeout-input").value || 10),
  }));
  $("#pause-plan").addEventListener("click", () => post("/api/run/pause"));
  $("#resume-plan").addEventListener("click", () => post("/api/run/resume"));
  $("#stop-plan").addEventListener("click", () => post("/api/run/stop"));
  $("#refresh-tests").addEventListener("click", () => post("/api/tests/refresh"));

  $("#select-package").addEventListener("click", async () => {
    const result = await post("/api/delivery/select");
    state.delivery = result.delivery;
    renderDelivery();
  });
  $("#install-package").addEventListener("click", () => post("/api/delivery/install"));
  $("#prepare-submit").addEventListener("click", () => post("/api/delivery/prepare-submit"));
  $("#rollback-delivery").addEventListener("click", () => post("/api/delivery/rollback"));

  $("#browser-select").addEventListener("change", updateCustomBrowserVisibility);
  $("#browse-browser").addEventListener("click", async () => {
    const result = await post("/api/browser/select");
    if (result.executable) {
      $("#browser-path").value = result.executable;
      $("#browser-select").value = "custom";
      updateCustomBrowserVisibility();
    }
  });
  $("#test-browser").addEventListener("click", async () => {
    const saved = await post("/api/settings", settingsPayload());
    state.settings = saved.settings;
    await post("/api/browser/test");
  });
  $("#save-settings").addEventListener("click", async () => {
    const result = await post("/api/settings", settingsPayload());
    state.settings = result.settings;
    renderSettings();
    $("#settings-message").textContent = result.restart_required
      ? "guardado · reinicia VTD para aplicar el puerto"
      : "guardado";
  });

  $("#shutdown-button").addEventListener("click", async () => {
    try {
      await shutdownDashboard();
    } catch (_) {
      // Status line already contains the safe backend rejection.
    }
  });
}

async function bootstrap() {
  const storedTheme = localStorage.getItem("vtd-theme");
  if (storedTheme) applyTheme(storedTheme, false);
  bindActions();
  try {
    const data = await api("/api/bootstrap");
    state.csrf = data.csrf_token;
    state.app = data.app;
    state.tests = data.tests;
    state.suites = data.suites;
    state.execution = data.execution;
    state.delivery = data.delivery;
    state.settings = data.settings;
    state.environment = data.environment;
    state.server = data.server;
    state.roadmap = data.roadmap;
    state.eventCursor = Number(data.event_cursor || 0);
    renderTests();
    renderExecution();
    renderDelivery();
    renderRoadmap();
    renderSettings();
    renderEnvironment();
    connectEvents(state.eventCursor);
    if (state.delivery.pending_prompt) {
      void handleDeliveryPrompt({
        prompt: state.delivery.pending_prompt,
      });
    }
    setStatus("sesión lista", "pass");
  } catch (error) {
    setStatus(error.message, "fail");
  }
}

bootstrap();
