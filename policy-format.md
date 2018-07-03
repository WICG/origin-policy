
# Explainer: Format of Origin Policy documents

**tl;dr** [Origin Policy](README.md) documents are JSON files  with top-level
entries for each supported mechanism.

## General File Format

An origin policy document is a JSON document that contains a series of policy
items. A top-level dictionary contains names policy items. Each type of
(currently) supported policy item is described below.

Example:

```js
{
  "tls": .... ,
  "content-security-policy": .... ,
  "referrer": ....
}
```

## Format Versioning and Error Handling

Applications should

- raise an error if the file is not well-formed JSON,
- ignore any top-level section they do not understand,
- consider it an error if they fail to parse a policy item that they do
  understand.

**TODO:** Should there be a 'must understand' directive, so that site owners
can determine themselves whether failure to understand a given policy item
should be fatal ot nor?

## Support Policy Items

### Content Security Policy (CSP)

The `content-security-policy` policy item contains the equivalent of one or more
[Content-Security-Policy HTTP headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP).

- The `"content-security-policy"` policy item contains an array of
  content-security-policy directives.
- Each CSP directive contains a `"policy"` string, containing the CSP format.
- A `"disposition"` is either `"enforce"` or `"report"`.

Example:

```js
"content-security-policy": [
  {
    "policy": "frame-ancestors 'none'; object-src 'none';",
    "disposition": "enforce"
  },{
    "policy": "script-src 'self' https://cdn.example.com/js/",
    "disposition": "report",
  }
]
```


### Transport-Level Security (TLS)

The `tls` policy item contains several directives related to TLS, particularly:

- [HTTP Strict Transport Security](https://tools.ietf.org/html/rfc6797)
- [HTTP Public Key Pinning](https://tools.ietf.org/html/rfc7469)
- [Expect-CT](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Expect-CT)

Example:

```js
"tls": {
  // Strict-Transport-Security
  "required": true,

  // Public-Key-Pins / Public-Key-Pins-Report-Only
  "pinned-public-keys": {
    "pins": [
      "d6qzRu9zOECb90Uez27xWltNsj0e1Md7GkYYkVoZWmM=",
      "E9CZ9INDbd+2eRQozYqqbQ2yXLVKB9+xcprMF+44U1g=",
      "LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ="
    ],
    "disposition": "enforce",
    "report-to": "group-name",
  },

  // Expect-CT
  "certificate-transparency": {
    "disposition": "enforce",    // (or "report-only")
    "report-to": "group-name"
  },

  // Others. `Expect-Staple`, etc.
  ...
}
```

Note: The actual format does not include comment syntax.

### Feature Policy

The `features` policy item contains the equivalent of one or more
[Feature-Policy](https://wicg.github.io/feature-policy/) HTTP headers.

Example:

```js
"features": {
  "policy": "geolocation 'self' https://example.com"
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
  items.
- Error handling: (E.g., reject malformed policies?) This would likely need
  to be fully defined for cross-browser compatibility, but the exact definition
  will have substantial impact on deployability and security. The present
  course here seems unclear.

## File Format Evolution

The original file format was focused on HTTP headers, and effectively described
a series of header-values with some vaguely specified metadata in JSON.

Largely based on
[this discussion](https://github.com/WICG/origin-policy/issues/19#issuecomment-321229817)
the format was revised to move away from being a header collection,
towards a format that allows for custom formats for each policy item.



