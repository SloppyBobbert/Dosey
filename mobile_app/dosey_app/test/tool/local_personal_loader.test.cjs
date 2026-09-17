const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const { test } = require("node:test");
const { runInNewContext } = require("node:vm");

const source = readFileSync(
  join(__dirname, "../../tool/local_personal/flutter_loader.js"),
  "utf8",
);

function load() {
  const listeners = [];
  const calls = [];
  runInNewContext(source, {
    window: {
      addEventListener(type, handler, options) {
        listeners.push({ type, handler, options });
        calls.push("listen");
      },
    },
    _flutter: {
      loader: {
        load(options) {
          calls.push(options);
        },
      },
    },
  });
  return { listeners, calls };
}

function dispatch(listeners, key, target) {
  let cancellations = 0;
  const event = {
    key,
    target,
    preventDefault() {
      cancellations++;
    },
    stopPropagation() {
      assert.fail("Propagation must remain untouched");
    },
    stopImmediatePropagation() {
      assert.fail("Propagation must remain untouched");
    },
  };
  for (const { type, handler } of listeners) {
    if (type === "keydown") handler(event);
  }
  return cancellations;
}

test("only exact placeholder Enter is canceled, without stopping propagation", () => {
  const { listeners } = load();
  assert.equal(
    dispatch(listeners, "Enter", { localName: "flt-semantics-placeholder" }),
    1,
  );
  for (const key of [
    "Tab",
    " ",
    "Space",
    "Spacebar",
    "W",
    "w",
    "Unidentified",
    "Escape",
    "ArrowDown",
    "NumpadEnter",
    "enter",
    "",
    null,
    undefined,
  ]) {
    assert.equal(
      dispatch(listeners, key, { localName: "flt-semantics-placeholder" }),
      0,
      `Excluded key: ${String(key)}`,
    );
  }
  for (const target of [
    null,
    undefined,
    {},
    { localName: null },
    ...[
      "flt-semantics",
      "button",
      "input",
      "textarea",
      "select",
      "a",
      "body",
      "FLT-SEMANTICS-PLACEHOLDER",
      "flt-semantics-placeholder-child",
      "",
    ].map((localName) => ({ localName })),
  ]) {
    assert.equal(
      dispatch(listeners, "Enter", target),
      0,
      `Excluded target: ${JSON.stringify(target)}`,
    );
  }
});

test("one nonpassive capture keydown guard is registered before loader start", () => {
  const { listeners, calls } = load();
  assert.equal(listeners.length, 1);
  assert.equal(listeners[0].type, "keydown");
  assert.deepEqual(JSON.parse(JSON.stringify(listeners[0].options)), {
    capture: true,
    passive: false,
  });
  assert.equal(calls.length, 2);
  assert.equal(calls[0], "listen");
});

test("loader retains local asset configuration and no service-worker settings", () => {
  const { calls } = load();
  assert.deepEqual(
    JSON.parse(JSON.stringify(calls.filter((call) => call !== "listen"))),
    [
      {
        config: {
          canvasKitBaseUrl: "/local/canvaskit/",
          fontFallbackBaseUrl: "/local/assets/local_fonts/",
        },
      },
    ],
  );
});
