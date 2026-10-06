# Tiger Style for HTML

**Safety > performance > developer experience.**

A practical standard for writing HTML5 documents, templates, and components on Arch
Linux. Written for the Diver language documentation directory. This is an independent
interpretation of
[TigerBeetle's Tiger Style](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md),
not an official TigerBeetle or WHATWG document.

| Policy | Baseline |
| --- | --- |
| Standard | HTML Living Standard (WHATWG), HTML5 syntax |
| Doctype | `<!DOCTYPE html>` on every document; no quirks mode |
| Encoding | UTF-8 declared in the first 1024 bytes, always |
| Formatting | Prettier or djhtml; two-space indent; 100-column target for attributes |
| Template size | Review templates above 300 physical lines |
| Primary platform | Arch Linux; browser claims require tested browser versions |
| Document reviewed | 2026-10-06 |

HTML is the browser's most privileged input: it defines structure, loads active
content, and carries user data into the DOM. Most web vulnerabilities are HTML
problems first — XSS is an HTML escaping failure, clickjacking is a framing failure,
CSRF rides on HTML forms. Treat every HTML document as a security boundary, not
as inert text.

## Contents

- [1. Engineering contract](#1-engineering-contract)
- [2. Toolchain and build trust](#2-toolchain-and-build-trust)
- [3. Structure and naming](#3-structure-and-naming)
- [4. Types and state](#4-types-and-state)
- [5. Contracts and errors](#5-contracts-and-errors)
- [6. Bounds and arithmetic](#6-bounds-and-arithmetic)
- [7. Ownership and memory](#7-ownership-and-memory)
- [8. Control flow and concurrency](#8-control-flow-and-concurrency)
- [9. Unsafe code and foreign interfaces](#9-unsafe-code-and-foreign-interfaces)
- [10. Operating-system boundaries](#10-operating-system-boundaries)
- [11. Performance and reproducibility](#11-performance-and-reproducibility)
- [12. Tests and review gates](#12-tests-and-review-gates)
- [13. Complete reference module](#13-complete-reference-module)
- [14. Neovim integration](#14-neovim-integration)

## 1. Engineering contract

Correctness comes before speed. Speed comes before convenience when the tradeoff is real.
Measure that tradeoff; do not use the priority order to justify speculative complexity.

Every HTML document or template must identify:

1. Accepted inputs, rejected inputs, and the trust boundary. Untrusted data
   (user input, third-party feeds, URL parameters) must be named explicitly.
2. Maximum document size, DOM node count, and embedded resource budget.
3. The owner of every dynamic region: which code may write into it, and how
   that code escapes or sanitizes its input.
4. The point at which externally visible state changes (form submission,
   navigation, resource fetch).
5. Failure behavior: what renders when a resource, script, or stylesheet fails.
6. The evidence supporting the result: validator output, CSP evaluation,
   accessibility audit, or manual browser test.

Use this rule for exceptions: name the rule, explain the need, bound the resulting
risk, and record a test or review condition. An exception belongs near the affected
markup or in its design record. Blanket waivers are difficult to maintain.

Prefer semantic elements over generic containers with classes. `<article>`,
`<nav>`, `<main>`, `<button>`, and `<form>` carry meaning that `<div>` and
`<span>` do not; assistive technology, search indexing, and future maintainers
all depend on that meaning. A `<div>` with `onclick` is a bug report waiting
to happen — it is not keyboard-accessible, not announced to screen readers,
and not a real control.

## 2. Toolchain and build trust

Pin formatter and linter versions in the project, not only in the editor.
A template:

```json
{
  "devDependencies": {
    "prettier": "3.3.3",
    "htmlhint": "1.1.4"
  }
}
```

Record the exact versions with `npm ls prettier htmlhint` when diagnosing
differences between terminal, editor, and CI. An environment override can
change the selected tool; record which binary actually ran.

Treat template engines, static-site generators, and HTML minifiers as
executable code in the build. Opening an unfamiliar repository must not
silently authorize its build scripts, template compilation, or asset
pipeline. Review `package.json` scripts before running them; a `preinstall`
hook executes on `npm install`.

Keep generated HTML distinct from authored HTML. Generated files belong in
a build directory, are gitignored, and are never hand-edited. If a generated
file must be inspected, regenerate it from source rather than patching the
output — patched output diverges silently on the next build.

Validate against the WHATWG Living Standard, not against "works in my
browser". Browser error recovery (the HTML parser's forgiveness) hides
structural mistakes: unclosed elements, misnested tables, duplicate IDs.
What one parser forgives, another may interpret differently. Run the
Nu Html Checker
([validator.w3.org/nu](https://validator.w3.org/nu/)) on representative
documents; treat validation errors as defects, not style suggestions.

## 3. Structure and naming

One document, one `<main>`. One `<h1>` per document (or per `<article>`).
Headings form a strict outline: never skip levels (`<h1>` directly to
`<h3>`), because screen readers use heading levels for navigation.

Order document sections as the HTML specification expects:

1. `<!DOCTYPE html>` — first, no preceding whitespace or comments.
2. `<html lang="...">` — language declared, always.
3. `<head>` — charset, viewport, title, then metadata, then stylesheets.
4. `<body>` — skip link first, then header, main, footer.

Name IDs and classes for purpose, not appearance: `user-profile`,
`checkout-form`, `error-summary` — not `blue-box`, `left-col`, `big-text`.
Appearance changes; purpose is the contract. Keep IDs unique per document;
duplicate IDs break fragment navigation, `label` association, and ARIA
references.

Use lowercase element and attribute names. Quote all attribute values, even
when the value could legally be unquoted — `disabled="disabled"` is explicit,
`disabled` relies on the reader knowing boolean-attribute rules.

Prefer explicit association over proximity. A `<label for="email">` bound to
`<input id="email">` survives CSS reordering; a label merely placed next to
an input does not survive anything.

Keep the DOM shallow where it matters: deeply nested tables and divs slow
parsing and layout, and they make the accessibility tree harder to navigate.
Review templates that nest beyond six levels without a structural reason.

Comments explain intent and trust decisions, not syntax. A comment like
`<!-- user content below is escaped server-side -->` records a security
contract. A comment like `<!-- div starts -->` narrates the obvious and
should be removed.

> **In plain terms:** Every XSS vulnerability is a category error: the browser treated attacker data as trusted markup. This guide's three content kinds — static markup you wrote, escaped data you're displaying, active content that runs code — are the mental firewall. The moment data crosses from one kind into another without escaping, you've handed the attacker a keyboard. `textContent` keeps data as data; `innerHTML` with untrusted input is an invitation.


## 4. Types and state

Distinguish three kinds of HTML content, because confusing them is the
root cause of injection vulnerabilities:

| Content kind | Meaning | Examples |
| --- | --- | --- |
| Static markup | Authored by the project, reviewed | Layout, navigation, labels |
| Escaped data | Untrusted values rendered as text | Usernames, comments, search terms |
| Active content | Code the browser executes | Scripts, event handlers, `javascript:` URLs |

Static markup is the only kind that may contain raw HTML. Escaped data must
pass through context-appropriate escaping before it reaches the document.
Active content must be justified, minimized, and governed by Content
Security Policy (see section 9).

Represent document state explicitly. A form has states — pristine, dirty,
valid, invalid, submitting, submitted, failed — and the markup should
reflect the current one through attributes (`aria-invalid`, `disabled`,
`aria-busy`), not through untracked visual changes. State carried only in
CSS classes is invisible to assistive technology.

Use enumerated attribute values rather than inventing new ones. `inputmode`
accepts `numeric`, `decimal`, `tel`, `email`, `url` — these are contracts
with the browser's virtual keyboard and validation. A misspelled value is
silently ignored, so validate attribute values with a linter, not by eye.

Data attributes (`data-*`) carry application state for scripts. Keep their
contract documented: what values are legal, who writes them, who reads them.
Never store secrets in data attributes — they are visible in page source
and to every script on the page.

> **In plain terms:** Client-side validation is a courtesy for the user — faster feedback, fewer round trips. Server-side validation is the actual security boundary, because the client is the attacker's computer and they can skip your JavaScript entirely. Any check that exists only in the browser is a suggestion, not a rule; the server must re-verify everything that matters.


## 5. Contracts and errors

Validate at the trust boundary, in the order the data travels. Client-side
validation is a usability feature; server-side validation is the security
contract. Never rely on HTML validation attributes (`required`, `pattern`,
`maxlength`) to enforce security — they are trivially bypassed.

Use native validation attributes as the first layer, because they are
accessible by default and work without JavaScript:

```html
<label for="email">Email address</label>
<input
  type="email"
  id="email"
  name="email"
  required
  maxlength="254"
  autocomplete="email"
>
```

| Situation | Preferred response |
| --- | --- |
| Missing required field | Native `required` + server-side rejection with field-level error |
| Malformed value | `type`/`pattern` hint client-side; strict server-side parse |
| Value too long | `maxlength` client-side; enforce the same bound server-side |
| Submission failure | Preserve user input; announce errors via `aria-describedby` |
| Resource load failure | Degrade visibly (`<noscript>`, `alt` text, fallback content) |

Error messages must identify the field, describe the problem, and suggest
recovery — and must not leak system internals. "Invalid email address" is
correct. "SQLSTATE[23000]: constraint violation on users.email_idx" is a
reconnaissance gift.

Associate every error with its field using `aria-describedby` pointing at
the error element's ID. A summary of all errors at the top of the form,
with links to each field, is the accessible pattern for multi-error forms.

Never render raw exception text, stack traces, or debug output into HTML
responses. Error pages are still HTML documents: they need the same
escaping discipline as every other template.

## 6. Bounds and arithmetic

Name resource limits with units and enforce them where the data enters.

| Resource | Required contract |
| --- | --- |
| Document | Maximum bytes served; reject or truncate oversized templates |
| DOM | Maximum node count for generated lists; paginate beyond the bound |
| Input | `maxlength` on every free-text field, mirrored server-side |
| Uploads | Maximum file bytes, checked before reading into memory |
| Embedded data | Maximum JSON-in-HTML payload bytes (see section 7) |
| Time | Resource timeouts; what renders when a fetch exceeds them |

Bound generated repetition. A template loop over user-controlled
collections needs a cap: `{% for item in items|slice:":100" %}` or an
equivalent. An unbounded loop over a 10-million-row result set is a
denial of service composed in HTML.

Bound `maxlength` from the data model, not from the layout. If the
database column holds 255 characters, the input allows 255 characters.
A mismatch in either direction is a defect: too small truncates legitimate
input, too large invites storage errors or truncation attacks.

For numeric inputs, set `min`, `max`, and `step`. These are hints, not
enforcement — the server revalidates — but they prevent the common case
of accidental out-of-range submission and they drive appropriate mobile
keyboards via `inputmode`.

## 7. Ownership and memory

Every dynamic region of a document has exactly one writer. If server
templates and client scripts both write into `#results`, their escaping
rules and update ordering must be a single reviewed contract, not two
independent assumptions.

Treat embedded JSON as a serialization boundary. Data passed from server
to script inside HTML must be JSON-encoded with HTML-safe escaping
(`<`, `>`, `&` escaped), placed in a `<script type="application/json">`
block, and parsed with `JSON.parse` — never interpolated into executable
script:

```html
<!-- Correct: data as inert text, parsed explicitly. -->
<script type="application/json" id="config">
  {"theme":"dark","items":[]}
</script>
<script>
  const config = JSON.parse(document.getElementById('config').textContent);
</script>
```

```html
<!-- Wrong: unescaped interpolation into executable context. -->
<script>
  const config = {"theme":"dark"}; <!-- XSS if any value contains </script> -->
</script>
```

The wrong pattern breaks when any value contains `</script>` — the HTML
parser ends the block early and the attacker's markup becomes live HTML.
This is not theoretical; it is the single most common template-injection
shape.

Own the lifetime of dynamically inserted content. Content added with
`innerHTML` must be escaped or sanitized at insertion; content added with
`textContent` or DOM construction is safe by construction. Prefer the safe
construction and reserve `innerHTML` for reviewed cases with a named
sanitizer.

Clean up what the document creates: remove event listeners on discarded
nodes, revoke object URLs, disconnect observers. A single-page application
that leaks DOM subtrees on every navigation will eventually exhaust memory
on long-lived sessions.

## 8. Control flow and concurrency

HTML has no loops or branches of its own, but templates do — and template
logic needs the same discipline as any control flow. Keep template
conditionals shallow and readable. A template with five nested conditionals
is business logic wearing a markup costume; move it into a tested
presenter or view model.

Order of definition matters for the parser. Stylesheets in `<head>` block
rendering until loaded — that is intentional, to avoid a flash of unstyled
content. Scripts with `src` block parsing unless marked `defer` or `async`.
The rules:

- Stylesheets: in `<head>`, in cascade order, no `@import` (it serializes
  fetches).
- Scripts that the page needs: `defer`, in dependency order, before
  `</body>` or in `<head>`.
- Scripts that are independent (analytics): `async`, with a documented
  assumption that they may run before or after parsing completes.
- Never use `document.write` — it blocks parsing and is banned by CSP in
  practice.

Form submission is the document's primary control flow. Define the method
explicitly (`POST` for state changes, never `GET`), include anti-CSRF
tokens for authenticated actions, and make destructive actions require an
explicit confirmation step — not a bare link that a prefetcher or crawler
can trigger.

Handle the no-script case deliberately. Either the document works without
JavaScript (progressive enhancement), or it declares so honestly with a
`<noscript>` message. A blank page with no explanation is a failure to
communicate, not a technical limitation.

> **In plain terms:** Content Security Policy is an allow-list the browser enforces: it declares which sources may provide scripts, styles, and other active content, and blocks everything else — including injected payloads. Think of it as a bouncer with a guest list standing between your page and the attacker. Every `'unsafe-inline'` exception you add is a name you're crossing off the bouncer's list, so each one needs a justification, an owner, and an expiry.


## 9. Unsafe code and foreign interfaces

In HTML, "unsafe" means markup or attributes that hand control to an
attacker. The default policy is: no inline scripts, no inline event
handlers, no `javascript:` URLs. Enforce it with Content Security Policy:

```html
<meta http-equiv="Content-Security-Policy"
      content="default-src 'self'; script-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'">
```

A CSP is a contract, not a decoration. Every `'unsafe-inline'` or
`'unsafe-eval'` in the policy needs a named justification, an owner, and
a removal condition — the same exception rule as section 1. Prefer
nonces or hashes over `'unsafe-inline'` when inline content is genuinely
required.

The dangerous attribute set — review every use:

| Pattern | Risk | Policy |
| --- | --- | --- |
| `onclick`, `onload`, etc. | Inline script execution | Forbidden; use `addEventListener` |
| `href="javascript:..."` | Script execution on click | Forbidden; use real URLs or buttons |
| `srcdoc` on iframe | Full HTML injection surface | Only with `sandbox` and reviewed content |
| `target="_blank"` without `rel` | `window.opener` access | Always add `rel="noopener noreferrer"` |
| `formaction`, `formmethod` overrides | Bypasses form-level policy | Forbidden unless reviewed |

`iframe` elements are foreign interfaces: they embed another document with
its own origin and privileges. Default to `sandbox` with the minimum
permissions the embedded content needs, and never combine
`allow-scripts` with `allow-same-origin` for untrusted content — that
combination removes the sandbox's origin isolation.

Treat `postMessage` as an FFI boundary: validate `event.origin` against an
allowlist, validate the message shape before acting on it, and never
`eval` or `innerHTML` message contents.

SVG embedded inline in HTML is active content: it can contain scripts and
event handlers. Treat inline SVG with the same suspicion as inline script.
Prefer `<img src="...svg">` (which disables scripting) for untrusted or
decorative SVG.

## 10. Operating-system boundaries

HTML documents reach the filesystem through uploads, downloads, and
generated files. Each crossing needs its contract.

For uploads: accept only declared MIME types, verify the content matches
the declaration (magic bytes, not just extension), bound the size before
buffering, store outside the web root, and serve back with
`Content-Disposition: attachment` unless inline rendering is an explicit,
reviewed feature. An uploaded "image" served with a `.html` extension or
a sniffable content type is stored XSS.

For downloads: set an explicit `Content-Type` and `X-Content-Type-Options:
nosniff`. Filenames in `Content-Disposition` must be sanitized — strip
path separators and control characters, and bound the length.

Generated HTML files (static site output, reports) are written through a
temporary file plus rename, exactly as section 10 of the systems guides
requires. A half-written HTML file served to a user is a corrupted
document at best.

Respect the distinction between build-time and request-time file access.
Templates read at build time from fixed paths; user uploads handled at
request time from isolated storage. Never let a template path be
influenced by request data — that is local file inclusion, and it reads
`/etc/passwd` as readily as a stylesheet.

## 11. Performance and reproducibility

Establish correct rendering before tuning. Measure with representative
documents: the largest real page, the longest real list, the heaviest real
form. Report first-contentful-paint and largest-contentful-paint
percentiles, total document bytes, and DOM node counts.

The dominant costs in HTML documents:

1. **Render-blocking resources.** Every synchronous stylesheet and script
   delays first paint. Minimize count, minimize bytes, defer what can wait.
2. **DOM size.** Layout cost grows with node count. Paginate or virtualize
   lists beyond a few hundred rows; do not render 10,000 rows and hide
   9,900 with CSS.
3. **Images.** Serve responsive sizes (`srcset`), modern formats, explicit
   `width`/`height` to prevent layout shift, and `loading="lazy"` below
   the fold.
4. **Web fonts.** Subset to used glyphs, use `font-display: swap`, and
   preconnect to the font origin.

Reproducibility for generated HTML means byte-stable output: sorted
attributes where the generator controls them, deterministic iteration
order, no timestamps embedded in markup unless the document is
explicitly versioned. Nondeterministic output breaks caching, diffing,
and content-hash integrity checks.

Avoid layout shift as a correctness issue, not just a metric. Content
that moves after load causes mis-clicks — a usability failure with
security-adjacent consequences on payment and consent flows. Reserve
space for late-loading content.

## 12. Tests and review gates

Test the contract, not the pixels. Valuable HTML tests:

- Validator passes with zero errors (Nu Html Checker).
- CSP evaluates without violations on every page (report-only mode first,
  then enforcing; monitor `report-uri` before tightening).
- Accessibility audit passes: axe-core with zero critical violations,
  keyboard-only walkthrough of every interactive flow, screen-reader pass
  of forms and error states.
- Escaping tests: every dynamic region receives `<script>`, `"`, `'`,
  `&`, `<img src=x onerror=>` payloads and renders them inert.
- Adversarial template tests: `</script>` inside JSON payloads, quotes
  inside attribute values, Unicode homoglyphs in usernames.
- Print and narrow-viewport rendering for documents users will print or
  read on phones.

Typical gates for a reviewed HTML change:

```sh
# Validate markup
npx html-validate "src/**/*.html"
# Lint for best practices
npx htmlhint "src/**/*.html"
# Accessibility
npx axe --exit src/dist/*.html
# CSP evaluation (against a staging deploy)
npx csp-evaluator https://staging.example.com/
```

A passing formatter is not a passing validator. A passing validator is
not a security review. A passing accessibility audit does not establish
that dynamic content is escaped. Report each kind of evidence accurately.

Review checklist for every HTML change:

- [ ] Doctype, language, charset, viewport, and title are present.
- [ ] Headings form an unbroken outline; landmarks (`main`, `nav`) are used.
- [ ] Every form control has an associated label; errors use `aria-describedby`.
- [ ] All dynamic content is escaped or sanitized at its trust boundary.
- [ ] No inline scripts, event handlers, or `javascript:` URLs.
- [ ] CSP is defined and does not contain unjustified `'unsafe-inline'`.
- [ ] `target="_blank"` links carry `rel="noopener noreferrer"`.
- [ ] Images have `alt` text; decorative images have empty `alt`.
- [ ] The document is usable keyboard-only and announces state changes.

## 13. Complete reference module

Save this fence as `secure-form.html`. It demonstrates semantic structure,
accessible form validation, CSP, safe JSON embedding, and no inline scripts.
It is a complete, self-contained document.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="Content-Security-Policy"
        content="default-src 'self'; script-src 'self'; style-src 'self';
                 img-src 'self' data:; object-src 'none'; base-uri 'self';
                 form-action 'self'">
  <title>Contact — Example</title>
  <link rel="stylesheet" href="/static/main.css">
</head>
<body>
  <a class="skip-link" href="#main">Skip to main content</a>

  <header>
    <nav aria-label="Primary">
      <ul>
        <li><a href="/">Home</a></li>
        <li><a href="/contact" aria-current="page">Contact</a></li>
      </ul>
    </nav>
  </header>

  <main id="main">
    <h1>Contact us</h1>

    <div id="error-summary" role="alert" hidden>
      <h2>There is a problem</h2>
      <ul id="error-list"></ul>
    </div>

    <form id="contact-form" method="post" action="/contact" novalidate>
      <input type="hidden" name="csrf_token" value="<!-- server fills -->">

      <div>
        <label for="name">Full name</label>
        <input type="text" id="name" name="name" required
               maxlength="100" autocomplete="name"
               aria-describedby="name-error">
        <p id="name-error" class="error" hidden></p>
      </div>

      <div>
        <label for="email">Email address</label>
        <input type="email" id="email" name="email" required
               maxlength="254" autocomplete="email"
               aria-describedby="email-error">
        <p id="email-error" class="error" hidden></p>
      </div>

      <div>
        <label for="message">Message</label>
        <textarea id="message" name="message" required
                  maxlength="5000" rows="6"
                  aria-describedby="message-error"></textarea>
        <p id="message-error" class="error" hidden></p>
      </div>

      <button type="submit">Send message</button>
    </form>
  </main>

  <footer>
    <p>&copy; 2026 Example. All rights reserved.</p>
  </footer>

  <!-- Server-provided data as inert JSON, parsed explicitly. -->
  <script type="application/json" id="page-data">
    {"maxMessageLength":5000}
  </script>
  <script src="/static/contact.js" defer></script>
</body>
</html>
```

And the companion script (`contact.js`), which contains no inline
behavior — everything is attached with `addEventListener`, all user
content is inserted with `textContent`:

```javascript
// contact.js — deferred, no inline handlers.
(function () {
  'use strict';

  var form = document.getElementById('contact-form');
  var summary = document.getElementById('error-summary');
  var errorList = document.getElementById('error-list');
  var pageData = JSON.parse(document.getElementById('page-data').textContent);

  function setError(input, message) {
    var errorEl = document.getElementById(input.getAttribute('aria-describedby'));
    errorEl.textContent = message; // textContent: safe by construction.
    errorEl.hidden = false;
    input.setAttribute('aria-invalid', 'true');
    return { input: input, message: message };
  }

  function clearErrors() {
    summary.hidden = true;
    errorList.textContent = '';
    Array.prototype.forEach.call(form.querySelectorAll('[aria-invalid]'), function (el) {
      el.removeAttribute('aria-invalid');
    });
    Array.prototype.forEach.call(form.querySelectorAll('.error'), function (el) {
      el.textContent = '';
      el.hidden = true;
    });
  }

  form.addEventListener('submit', function (event) {
    clearErrors();
    var errors = [];
    var name = document.getElementById('name');
    var email = document.getElementById('email');
    var message = document.getElementById('message');

    if (!name.value.trim()) {
      errors.push(setError(name, 'Enter your full name.'));
    }
    if (!email.value.trim() || email.validity.typeMismatch) {
      errors.push(setError(email, 'Enter an email address in the correct format.'));
    }
    if (message.value.length > pageData.maxMessageLength) {
      errors.push(setError(message, 'Message must be 5000 characters or fewer.'));
    }

    if (errors.length > 0) {
      event.preventDefault();
      summary.hidden = false;
      errors.forEach(function (e) {
        var li = document.createElement('li');
        var a = document.createElement('a');
        a.href = '#' + e.input.id;
        a.textContent = e.message; // textContent: safe by construction.
        li.appendChild(a);
        errorList.appendChild(li);
      });
      summary.focus();
    }
    // Server revalidates everything; this is usability, not security.
  });
})();
```

Validation for the reference:

```sh
# Save both fences, then:
npx html-validate secure-form.html
npx htmlhint secure-form.html
npx axe --exit secure-form.html
```

## 14. Neovim integration

Place this document at `lua/config/lang/TIGER_STYLE_HTML.md` in Diver.
Markdown is reference material; do not `require()` it from `init.lua`.
Your HTML language configuration, LSP definitions, lint runner, and
formatter remain their own Lua modules.

Recommended tooling, consistent across editor and CI:

| Role | Tool | Notes |
| --- | --- | --- |
| Language server | `html` (vscode-html-language-server) | Completion, hover, validation |
| Formatter | Prettier (`prettier --write`) | Two-space indent, single quotes in JS |
| Markup lint | `htmlhint` | Tag pairing, attribute rules, doctype |
| Standards validation | Nu Html Checker | Zero errors on representative pages |
| Accessibility | `axe-core` CLI | Zero critical violations |
| Link checking | `lychee` or `html-proofer` | No dead internal links |

Keep one owner for format-on-save and avoid duplicate validation runners.
Compare the editor's Prettier version with the project's pinned version
before changing diagnostics to conceal a mismatch.

When HTML is generated from templates, the editor should validate the
template source where possible and the rendered output where it matters.
Template syntax (`{{ }}`, `{% %}`) will confuse pure-HTML validators;
configure the validator to ignore template delimiters or validate a
rendered fixture instead.

Make project execution deliberate: workspace trust gates template
compilation, asset pipelines, and local preview servers. Read-only
browsing and editing should remain possible before trust. Expensive
checks (full-site validation, accessibility sweeps) should be cancellable
and must not block editor callbacks.

**Maintenance:** review this guide whenever the HTML Living Standard
gains relevant features, the CSP baseline changes, the template engine
is replaced, or the accessibility target level changes. Keep the rule
and the evidence together. Remove obsolete workarounds when their
underlying constraint disappears.
