# Enforcement configs

Offer the configs for the stack of the repo. Add only the configs that the user accepts.
After you add a tool, add its command to the Project section of `AGENTS.md`.

## All stacks

### Writing (STE-inspired)

ASD-STE100 inspired these rules. They are not a full STE check. pj has no affiliation with ASD.

1. Copy `<skill>/templates/vale/.vale.ini` to `.vale.ini`.
2. Copy `<skill>/templates/vale/styles/STE/` to `.vale/styles/STE/`.
3. Copy `<skill>/templates/markdownlint.jsonc` to `.markdownlint.jsonc`.

| Tool | Install | Command |
|---|---|---|
| Vale | `brew install vale` | `vale sync && vale docs/ AGENTS.md` |
| markdownlint-cli2 | none (npx) | `npx markdownlint-cli2 "docs/**/*.md" AGENTS.md` |

### Mermaid

1. Copy `<skill>/templates/er_limit.py` to `.pj/er_limit.py`.

| Check | Command |
|---|---|
| Diagrams parse | `npx -p @mermaid-js/mermaid-cli mmdc -i <file.md> -o <tmp>/out.md` |
| Max 9 entities | `python3 .pj/er_limit.py docs/*.md` |

`mmdc` needs Chromium. It can exit 0 on a broken diagram, so also check stderr.

## Web (TypeScript)

### Magic numbers, magic strings, UI text

```sh
npm i -D eslint-plugin-sonarjs eslint-plugin-i18next
```

Add to the existing `eslint.config.js`:

```js
import sonarjs from "eslint-plugin-sonarjs";
import i18next from "eslint-plugin-i18next";

export default [
  // …existing config
  {
    plugins: { sonarjs, i18next },
    rules: {
      "no-magic-numbers": "off",
      "@typescript-eslint/no-magic-numbers": ["error", {
        ignore: [0, 1, -1],
        ignoreEnums: true,
        ignoreReadonlyClassProperties: true,
        ignoreTypeIndexes: true,
      }],
      "sonarjs/no-duplicate-string": ["error", { threshold: 3 }],
      "i18next/no-literal-string": ["error", { mode: "jsx-text-only" }],
    },
  },
  {
    files: ["**/*.test.ts", "**/*.spec.ts"],
    rules: { "@typescript-eslint/no-magic-numbers": "off" },
  },
];
```

### Mutation tests

```sh
npm i -D @stryker-mutator/core @stryker-mutator/vitest-runner
```

`stryker.config.json`. Ask the user for the globs of the key logic.

```json
{
  "testRunner": "vitest",
  "mutate": ["src/domain/**/*.ts"],
  "thresholds": { "break": 60 },
  "incremental": true
}
```

Command: `npx stryker run`. Use the runner of the repo: vitest, jest, or mocha.

### Accessibility

```sh
npm i -D @axe-core/playwright
```

```ts
const result = await new AxeBuilder({ page })
  .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
  .analyze();
expect(result.violations).toEqual([]);
```

React: add `eslint-plugin-jsx-a11y`. On ESLint 10, use the fork `eslint-plugin-jsx-a11y-x`.

## Flutter (Dart)

### Magic numbers, UI text

The plugins need Dart 3.10 or later. They run with `dart analyze`, not `flutter analyze`.
Check the syntax in the README of each package before you write it.

`analysis_options.yaml`:

```yaml
plugins:
  solid_lints:
    version: ^2.0.0
    diagnostics:
      no_magic_number: true
  hardcoded_strings_lint:
    version: ^2.1.0
```

No free Dart tool finds single magic strings. The review checks them.
Do not use DCM. The free plan has no CI license.

### Mutation tests

```sh
dart pub add --dev mutation_test
```

Run it only on changed files. A full run can take hours.

```sh
flutter test --coverage
dart run mutation_test --coverage coverage/lcov.info $(git diff --name-only origin/main -- 'lib/*.dart')
```

### Accessibility

```dart
final handle = tester.ensureSemantics();
await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
await expectLater(tester, meetsGuideline(textContrastGuideline));
handle.dispose();
```
