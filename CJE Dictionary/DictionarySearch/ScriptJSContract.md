# Script.js Contract

This document defines what a dictionary `Script.js` must do so CJE Dictionary can parse definitions correctly.

## Where Script.js is used

- For dictionaries with parser type `scriptJS`, Swift loads raw record HTML and executes `Script.js` with a hidden `WKWebView`.
- Runtime path:
  - `MdictOptimizedDictionary.getDefinitionGroups(...)`
  - `MongoDict.getDefinitionGroups(...)`
  - `ScriptExecutor.execute(html:script:)`

`Script.js` runs in a browser-like DOM environment with the current entry HTML as `document`.

## Required output

Your script must evaluate to a **JSON string** that decodes to `[DefinitionGroup]`.

In practice, the last evaluated expression should be:

```js
JSON.stringify(convertToJSON())
```

If the JS evaluation result is not a `String`, parsing fails with `invalidScriptResult`.

### Runtime expectation (important)

The executor does this at runtime:

1. Injects the entry HTML into `WKWebView`.
2. Evaluates your entire `Script.js`.
3. Expects the **final JS evaluation result** to be a string.
4. Decodes that string as JSON into Swift `DefinitionGroup` models.

So your script must not only build objects; it must **return serialized JSON as a string**.

## Required JSON schema

Top-level value: array of definition groups.

```json
[
  {
    "tags": [
      { "shortName": "...", "longName": "..." }
    ],
    "definitions": [
      {
        "definition": "...",
        "exampleSentences": [
          { "language": "ja-JP", "sentence": "..." },
          { "language": "en-US", "sentence": "..." }
        ]
      }
    ]
  }
]
```

## Detailed output types (AI-targeted spec)

Use this as the source of truth when generating `convertToJSON()`.

### TypeScript-style contract

```ts
type ScriptOutput = DefinitionGroup[];

interface DefinitionGroup {
  tags: Tag[];
  definitions: Definition[];
}

interface Tag {
  shortName: string;
  longName: string;
}

interface Definition {
  definition: string;
  exampleSentences: ExampleSentence[];
}

interface ExampleSentence {
  language: string | null;
  sentence: string;
}
```

### Strict field-level requirements

#### `DefinitionGroup`
- `tags` (required): array, may be empty.
- `definitions` (required): array, may be empty.

#### `Tag`
- `shortName` (required): non-null string.
- `longName` (required): non-null string.

#### `Definition`
- `definition` (required): non-null string (can be empty, but prefer meaningful text).
- `exampleSentences` (required): array, may be empty.

#### `ExampleSentence`
- `language` (required key): `string` or `null`.
  - Prefer full locale tags (BCP-47 style), e.g. `ja-JP`, `en-US`, `zh-CN`.
  - Short tags (like `ja`) may work, but full locale is preferred for consistency.
- `sentence` (required): non-null string.

### Do not omit required keys

Even when empty, include all required keys:

```json
{
  "tags": [],
  "definitions": [
    {
      "definition": "",
      "exampleSentences": []
    }
  ]
}
```

## Canonical full example

This example is fully valid against app decoding:

```json
[
  {
    "tags": [
      { "shortName": "名", "longName": "名詞" },
      { "shortName": "自サ", "longName": "自動詞・サ変" }
    ],
    "definitions": [
      {
        "definition": "ある状態や現象を説明する語。",
        "exampleSentences": [
          { "language": "ja-JP", "sentence": "用語を定義する。" },
          { "language": "en-US", "sentence": "Define a term." },
          { "language": null, "sentence": "語法: 文脈依存で意味が変わる。" }
        ]
      },
      {
        "definition": "第二義。",
        "exampleSentences": []
      }
    ]
  }
]
```

## Invalid vs valid output examples

### Invalid: returns object (not string)

```js
function convertToJSON() {
  return [];
}
convertToJSON();
```

### Valid: returns JSON string

```js
function convertToJSON() {
  return [];
}
JSON.stringify(convertToJSON());
```

### Invalid: missing required keys

```json
[ { "definitions": [] } ]
```

### Valid: all required keys present

```json
[ { "tags": [], "definitions": [] } ]
```

### Field rules

- `tags`: array (can be empty)
  - `shortName`: string
  - `longName`: string
- `definitions`: array (can be empty)
  - `definition`: string
  - `exampleSentences`: array (can be empty)
    - `language`: string or `null`
      - Recommended locale-like codes: `ja`, `en`, `zh-CN`, etc.
    - `sentence`: string

## Markdown and ruby annotations (optional)

`exampleSentences[].sentence` is parsed as Markdown into `AttributedString`.

For ruby/furigana, this app supports custom markdown in this form:

```md
^[漢字](CTRubyAnnotation: 'かんじ')
```

If you do not need ruby, plain text is fine.

## AI implementation notes

When another AI generates `Script.js`, it should follow this sequence:

1. Parse `document` into intermediate arrays (`groups`, `definitions`, `examples`).
2. Normalize null/missing values to valid defaults:
  - missing text -> `""`
  - missing arrays -> `[]`
  - unknown language -> `null`
3. Build objects exactly matching the schema above.
4. Return `JSON.stringify(result)` as the last expression.

Recommended safety helpers:

```js
const text = (node) => (node?.textContent ?? "").trim();
const arr = (value) => (Array.isArray(value) ? value : []);
```

## Minimal template

```js
function convertToJSON() {
  return [
    {
      tags: [],
      definitions: [
        {
          definition: document.body?.innerText ?? "",
          exampleSentences: []
        }
      ]
    }
  ];
}

JSON.stringify(convertToJSON());
```

## Robustness recommendations

- Always return arrays for `tags`, `definitions`, `exampleSentences`.
- Avoid throwing; guard missing nodes (`querySelector(...)` may return `null`).
- Keep script synchronous (no async/await). `evaluateJavaScript` expects immediate result.
- Ensure the last expression returns the JSON string.

## Common failure modes

- Returning object/array instead of string.
- Missing keys (`definition`, `exampleSentences`, etc.).
- Invalid JSON / non-serializable values.
- Script assumes nodes always exist and crashes on different entries.

## Quick validation checklist

- Script ends with `JSON.stringify(...)`.
- JSON shape matches this doc.
- All required keys exist even when values are empty.
- Works on entries with and without examples.
- Handles missing tags/senses gracefully.
