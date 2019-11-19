# Explainer: origin policy manifest format

[Origin policy](./README.md) manifests are JSON files with top-level entries for each supported policy mechanism. We try to reuse existing format syntax where applicable (e.g., where equivalent HTTP headers exist).

## General file format

An origin policy document is a JSON document, whose top-level must be an object, that contains a series of policy items. Each key in the object names a policy item, and its value contains an item specific configuration. The keys and values for each proposed policy item are described below.

Example:

```js
{
  "features": ...,
  "content-security": ...,
  "referrer": ...
}
```

The MIME type for origin policy manifest files is `application/originpolicy+json`.

## Error handling

Various failures can be encountered when parsing an origin policy manifest. The [current proposal](https://github.com/WICG/origin-policy/issues/49) is that failures generally be "soft"; that is, unless the resource mandates an origin policy be applied, then an invalid origin policy manifest will be ignored. This is the case even if authoring errors make the origin policy manifest unparseable.

Although the requirements will become more detailed as we write a full specification, the following is our current general proposal:

* JSON parsing failures, or top-level schema failures (e.g. a JSON document consisting of an array or boolean instead of an object), are not recoverable.
* Any top-level keys that the user agent doesn't understand must be ignored, for future compatibility.
* Failures to parse the syntax of a specific policy item should be handled the same as how parsing errors are handled elsewhere for a comparable policy. (For example, Feature Policy usually resorts to browser defaults if a policy is not understood.)

## Supported policy items

### Mostly settled

The following policy items are ones that we are reasonably sure on the format of, and hoping to draft spec text for ASAP.

#### [Content Security Policy](https://w3c.github.io/webappsec-csp/)

The `"content_security"` policy item is an object with two possible keys:

* `"policy"`, which contains an array of strings that are equivalent to [`Content-Security-Policy`](https://w3c.github.io/webappsec-csp/#csp-header) HTTP response headers, and
* `"policy_report_only"`, which contains an array of strings that are equivalent to [`Content-Security-Policy-Report-Only`](https://w3c.github.io/webappsec-csp/#cspro-header) HTTP response headers.

The format of the strings is the same as those of the HTTP headers. (I.e., there is no further "JSON-ification" of the content security policies.)

Just as with headers, you can chain multiple policies by either listing them as seperate strings in the array of strings, or by merging them into one string and separating them by a comma.

Any CSP applied via HTTP headers or `<meta>` tags is applied after those from the origin policy, as if concatenated with a separating comma.

Examples:

```json
{
  "id": "my-policy",
  "content_security": {
    "policy": ["frame-ancestors 'none'", "object-src 'none'"],
    "policy_report_only": ["script-src 'self' https://cdn.example.com/js/"]
  }
}
```

```json
{
  "id": "my-policy",
  "content_security": {
    "policy": ["frame-ancestors 'none'; object-src 'none'"]
  }
}
```

#### [Feature Policy](https://w3c.github.io/webappsec-feature-policy/)

The `"features"` policy item is an object with two possible keys:

* `"policy"`, which is a string that is equivalent to a [`Feature-Policy`](https://w3c.github.io/webappsec-feature-policy/#feature-policy-http-header-field) HTTP response header, and
* `"policy_report_only"`, which is a string that is equivalent to a [`Feature-Policy-Report-Only`](https://github.com/w3c/webappsec-feature-policy/blob/master/reporting.md#can-i-just-trigger-reports-without-actually-enforcing-the-policy) HTTP response header.

The format of the strings is the same as those of the HTTP headers. (I.e., there is no further "JSON-ification" of the content security policies.)

Any feature policies applied via HTTP headers are applied after those from the origin policy, as if concatenated with a separating comma.

TODO: [string vs. array of strings for FP vs. CSP is strange](https://github.com/WICG/origin-policy/issues/50).

Example:

```json
{
  "id": "my-policy",
  "features": {
    "policy": "geolocation 'self' https://example.com"
  }
}
```

### Still in flux

The following policy items are still under discussion, with their formats not exactly settled. They will probably be specced after the above.

#### [Origin isolation](https://github.com/domenic/origin-isolation)

The current proposal for enabling origin isolation is with a `"origin_isolated"` policy item, which can be set to two values:

* `"best-effort"` indicates origin isolation should be done, with a best-effort attempt at process separation
* `"none"` indicates no origin isolation should be done

Any unrecognized values would be treated as `"best-effort"`, for future compatibility.

This policy item is mainly under flux for naming reasons: both the [`"origin_isolated"` key](https://github.com/domenic/origin-isolation/issues/5) and the [`"best-effort"` value](https://github.com/domenic/origin-isolation/issues/1) need a bit more bikeshedding.

### Transport-Level Security (TLS)

The hypothesized `"tls"` policy item could contain various directives related to TLS. Ideas so far include:

- [HTTP Strict Transport Security](https://tools.ietf.org/html/rfc6797), via the `"required"` field
- [Expect-CT](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Expect-CT), via the `"certificate-transparency"` field

Example:

```json
{
  "id": "my-policy",
  "tls": {
    "required": true,
    "certificate-transparency": {
      "disposition": "enforce",
      "report-to": "group-name"
    }
  }
}
```

In general any `HSTS` or `Expect-CT` headers would override the expectations set by origin policy, although the details here are not yet clear.

### [Referrer Policy](https://w3c.github.io/webappsec-referrer-policy/)

Referrer policy configuration might look like:

```json
{
  "id": "my-policy",
  "referrer-policy": "origin-when-cross-origin"
}
```

The origin policy-set referrer policy would be consulted last, after the current cascade of `noreferrer=""` → `referrerpolicy=""` → `<meta name="referrer">` → `Referrer-Policy` HTTP header.

### [Client Hints](https://httpwg.org/http-extensions/client-hints.html)

Setting default client hints might look like:

```json
{
  "id": "my-policy",
  "client-hints": ["DPR", "Width", "Viewport-Width"]
}
```

These would be cumulative with any per-resource client hints set by the `Accept-CH` header or `<meta http-equiv="accept-ch">`.

### [CORS protocol](https://fetch.spec.whatwg.org/#http-cors-protocol)

Configuring the behavior of CORS preflights to the origin in question might look like:

```json
{
  "id": "my-policy",
  "cors_preflights": {
    "no_credentials": {
      "origins": "*",
    },
    "unsafe_include_credentials": {
      "origins": ["https://trusted.example.com/"]
    },
  }
}
```

It's not immediately obvious whether this credentials-bucketed structure is the best one, or how to fit in equivalents for `Access-Control-Allow-Methods`, `Access-Control-Allow-Headers`, or `Access-Control-Expose-Headers`.

In general the CORS headers for a given resource would override those from the origin policy, which could cause interesting failures if the per-resource headers are stricter.

## Appendix: file format evolution

The original file format was focused on HTTP headers, and effectively described a series of header-values, as well as a separation between baseline and fallback values.

Largely based on [discussion in #19](https://github.com/WICG/origin-policy/issues/19) the format was revised to move away from being a header collection, towards a format that allows for custom formats for each policy item. This will require more integration work for each policy item, but avoids constraining the format and evolution of the policy items.
