# Explainer: Format of Origin Policy documents

**tl;dr:** [Origin Policy](README.md) documents are JSON files with top-level
entries for each supported policy mechanism. We try to re-use existing format
syntax where applicable (e.g. where equivalent HTTP headers exist).

## General File Format

An origin policy document is a JSON document that contains a series of policy
items. Each top-level dictionary entry names a policy item and contains an
item specifc dictionary. Each type of (currently) supported policy item is
described below.

Example:

```js
{
  // Example format with comments.
  "features": .... ,
  "content-security": .... ,
  "referrer": ....
}
```

Note: We sometimes use comments in the examples. The comment syntax is not
      supported JSON and is not part of the actual format.

## Format Versioning and Error Handling

Applications should

- consider it a fatal error if the file is not well-formed JSON (or cannot be
  fetched),
- ignore any top-level section they do not understand,
- consider it an error if they fail to parse a policy item that they do
  understand. How to handle an error with a particular policy item should
  be consistent with how errors are handled elsewhere for a comparable policy.
  (For example, Feature Policy usually resorts to browser defaults if a policy
  is not understood. It would be odd if this would lead to more drastic
  failures if the same policy is declared in an Origin Policy.)

## Supported Policy Items

### Content Security Policy (CSP)

The `content-security` policy item contains the equivalent of one or
more
[Content-Security-Policy HTTP headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP).

- The `"content-security"` policy item contains a dictionary with two
  supported keys: "policy" and "policy-report-only", corresponding to the
  "Content-Security-Policy" and "Content-Security-Policy-Report-Only" HTTP
  headers.
- Each contains an array of strings, with the same fomat as the HTTP headers.
- Note that - just as the headers - you can chain multiple policies by either
  listing them as seperate strings in the array of strings, or by merging them
  into one string and separating them by a semicolon.

Example:

```js
"content-security": {
  "policy": [ "frame-ancestors 'none'", "object-src 'none'" ],
  "policy-report-only": [ "script-src 'self' https://cdn.example.com/js/" ]
}
```

Example:

```js
"content-security": {
  "policy": [ "frame-ancestors 'none'; object-src 'none'" ]
}
```


### Feature Policy

The `features` policy item contains the equivalent of one or more
[Feature-Policy](https://wicg.github.io/feature-policy/) HTTP headers.

Example:

```js
"features": {
  "policy": "geolocation 'self' https://example.com"
}
```


### Transport-Level Security (TLS)

The `tls` policy item contains several directives related to TLS, particularly:

- [HTTP Strict Transport Security](https://tools.ietf.org/html/rfc6797)
- [Expect-CT](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Expect-CT)

Example:

```js
"tls": {
  // Strict-Transport-Security
  "required": true,

  // Expect-CT
  "certificate-transparency": {
    "disposition": "enforce",    // (or "report-only")
    "report-to": "group-name"
  },

  // Others. `Expect-Staple`, etc.
  ...
}
```

### Referrer Policy

Referrer policy might look like:

Example:

```js
"referrer": {
 "policy": "origin-when-cross-origin",
}
```

### Client Hints

Example:

```js
"client-hints": [ "DPR", "Width", "Viewport-Width" ],
```

### CORS:

Example:

```js
"cors-preflights": {
  "no-credentials": {
    "origins": "*",
  },
  "unsafe-include-credentials": {
    "origins": [ "https://trusted.example.com/" ]
  },
}
```

# Notes & Appendices

## Open Questions

- Are there any generic properties (like 'must understand') that apply to all
  policy items, or is this merely a collection of otherwise unrelated policy
  items?
- Error handling: This would likely need to be fully defined for cross-browser
  compatibility, but the exact definition will have substantial impact on
  deployability and security. This should be revisited following early tester
  feedback.


## File Format Evolution

The original file format was focused on HTTP headers, and effectively described
a series of header-values with some vaguely specified metadata in JSON.

Largely based on
[this discussion](https://github.com/WICG/origin-policy/issues/19#issuecomment-321229817)
the format was revised to move away from being a header collection,
towards a format that allows for custom formats for each policy item.

