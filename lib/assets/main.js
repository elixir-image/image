// Client for the `Image: transform` smart cell.
//
// This file knows nothing about any particular image operation. The server
// sends a catalogue describing each operation and its parameters, and the
// only operation-aware code here is the mapping from a parameter's type to
// a widget. Adding an operation is therefore an Elixir-only change.
//
// Field edits are pushed to the server without re-rendering, because
// rebuilding an input while someone is typing in it takes their focus and
// their cursor position with it. Only structural changes — adding,
// removing or moving an operation — re-render.

export function init(ctx, payload) {
  ctx.importCSS("main.css");

  const state = {
    fields: payload.fields,
    variables: payload.variables || [],
    catalogue: payload.catalogue || [],
  };

  const specs = new Map(state.catalogue.map((spec) => [spec.name, spec]));

  ctx.root.innerHTML = `
    <div class="app">
      <div class="header">
        <span class="title">IMAGE</span>
        <div class="row" data-source></div>
      </div>
      <div class="body">
        <div class="operations" data-operations></div>
        <div class="row add">
          <select data-add-operation>
            <option value="">Add an operation…</option>
            ${state.catalogue
              .map((spec) => `<option value="${spec.name}">${escapeHtml(spec.label)}</option>`)
              .join("")}
          </select>
        </div>
      </div>
    </div>
  `;

  const sourceEl = ctx.root.querySelector("[data-source]");
  const operationsEl = ctx.root.querySelector("[data-operations]");
  const addEl = ctx.root.querySelector("[data-add-operation]");

  addEl.addEventListener("change", (event) => {
    const name = event.target.value;
    if (name) ctx.pushEvent("add_operation", { name });
    event.target.value = "";
  });

  renderSource();
  renderOperations();

  ctx.handleEvent("update", ({ fields }) => {
    Object.assign(state.fields, fields);
    // A source change alters which inputs are relevant, so re-render it.
    if ("source_type" in fields) renderSource();
  });

  ctx.handleEvent("operations", ({ operations }) => {
    state.fields.operations = operations;
    renderOperations();
  });

  ctx.handleEvent("variables", ({ variables }) => {
    state.variables = variables;
    renderSource();
  });

  function renderSource() {
    const fields = state.fields;
    const fromVariable = fields.source_type === "variable";

    sourceEl.innerHTML = `
      <label class="inline">
        <span>Source</span>
        <select data-field="source_type">
          <option value="path"${fromVariable ? "" : " selected"}>File</option>
          <option value="variable"${fromVariable ? " selected" : ""}>Variable</option>
        </select>
      </label>
      ${
        fromVariable
          ? `<label class="inline grow">
               <span>Variable</span>
               <select data-field="source_variable">
                 ${
                   state.variables.length
                     ? state.variables
                         .map(
                           (name) =>
                             `<option value="${name}"${
                               name === fields.source_variable ? " selected" : ""
                             }>${escapeHtml(name)}</option>`
                         )
                         .join("")
                     : `<option value="">No image variables in scope</option>`
                 }
               </select>
             </label>`
          : `<label class="inline grow">
               <span>Path</span>
               <input type="text" data-field="source_path"
                      value="${escapeHtml(fields.source_path || "")}"
                      placeholder="path/to/image.jpg" />
             </label>`
      }
      <label class="inline">
        <span>Assign to</span>
        <input type="text" data-field="to_variable"
               value="${escapeHtml(fields.to_variable || "")}" />
      </label>
    `;

    bindFields(sourceEl);
  }

  function renderOperations() {
    const operations = state.fields.operations || [];

    if (operations.length === 0) {
      operationsEl.innerHTML = `<div class="empty">No operations yet. The source image is shown unchanged.</div>`;
      return;
    }

    operationsEl.innerHTML = operations
      .map((operation, index) => {
        const spec = specs.get(operation.name);
        if (!spec) return "";

        const params = spec.params
          .map((param) => widget(param, operation.params[param.key], index))
          .join("");

        return `
          <div class="operation" data-index="${index}">
            <div class="operation-header">
              <span class="operation-label" title="${escapeHtml(spec.doc)}">${escapeHtml(spec.label)}</span>
              <span class="spacer"></span>
              <button class="icon" data-move="${index}" data-to="${index - 1}"
                      ${index === 0 ? "disabled" : ""} title="Move up">&#9650;</button>
              <button class="icon" data-move="${index}" data-to="${index + 1}"
                      ${index === operations.length - 1 ? "disabled" : ""} title="Move down">&#9660;</button>
              <button class="icon remove" data-remove="${index}" title="Remove">&#10005;</button>
            </div>
            <div class="params">${params}</div>
          </div>
        `;
      })
      .join("");

    operationsEl.querySelectorAll("[data-remove]").forEach((button) => {
      button.addEventListener("click", () =>
        ctx.pushEvent("remove_operation", { index: Number(button.dataset.remove) })
      );
    });

    operationsEl.querySelectorAll("[data-move]").forEach((button) => {
      button.addEventListener("click", () =>
        ctx.pushEvent("move_operation", {
          index: Number(button.dataset.move),
          to: Number(button.dataset.to),
        })
      );
    });

    bindParams(operationsEl);
  }

  // The only operation-aware code in this file.
  function widget(param, value, index) {
    const current = value === undefined || value === null ? param.default : value;
    const attributes = `data-param="${param.key}" data-index="${index}"`;

    const control = (() => {
      switch (param.type) {
        case "range":
          return `<input type="range" ${attributes}
                    min="${param.min}" max="${param.max}" step="${param.step}"
                    value="${escapeHtml(String(current))}" />
                  <output>${escapeHtml(String(current))}</output>`;

        case "number":
          return `<input type="number" ${attributes}
                    min="${param.min}" max="${param.max}" step="${param.step}"
                    value="${escapeHtml(String(current))}" />`;

        case "select":
          return `<select ${attributes}>
                    ${param.options
                      .map(
                        (option) =>
                          `<option value="${option}"${
                            String(option) === String(current) ? " selected" : ""
                          }>${escapeHtml(option)}</option>`
                      )
                      .join("")}
                  </select>`;

        case "colour":
          return `<input type="color" ${attributes} value="${escapeHtml(String(current))}" />`;

        case "boolean":
          return `<input type="checkbox" ${attributes} ${current === "true" || current === true ? "checked" : ""} />`;

        default:
          return `<input type="text" ${attributes} value="${escapeHtml(String(current))}" />`;
      }
    })();

    return `<label class="param"><span>${escapeHtml(param.label)}</span>${control}</label>`;
  }

  function bindFields(container) {
    container.querySelectorAll("[data-field]").forEach((input) => {
      input.addEventListener("change", () =>
        ctx.pushEvent("update_field", { field: input.dataset.field, value: input.value })
      );
    });
  }

  function bindParams(container) {
    container.querySelectorAll("[data-param]").forEach((input) => {
      const push = () =>
        ctx.pushEvent("update_param", {
          index: Number(input.dataset.index),
          key: input.dataset.param,
          value: input.type === "checkbox" ? String(input.checked) : input.value,
        });

      // A range reports continuously, so show the value as it moves but
      // only tell the server when the drag ends.
      if (input.type === "range") {
        const output = input.nextElementSibling;
        input.addEventListener("input", () => {
          if (output) output.textContent = input.value;
        });
      }

      input.addEventListener("change", push);
    });
  }
}

function escapeHtml(value) {
  return String(value).replace(
    /[&<>"']/g,
    (character) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[character]
  );
}
