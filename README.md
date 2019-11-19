# Origin Policy

Origin policy is a web platform mechanism that allows origins to set their origin-wide configuration in a central location, instead of using per-response HTTP headers.

## The problems and goals

### Configurations with origin-wide effects

**Problem 1:** Using HTTP headers as a delivery mechanism for origin-wide configuration allows individual resources or web applications on an origin to misconfigure the entire origin. For example, if one page on an origin sets the [`Strict-Transport-Security`](https://tools.ietf.org/html/rfc6797) response header before all other pages are available over HTTPS, the other pages become inaccessible.

**Problem 2:** Allowing different resources to give different values for origin-wide configuration, via different HTTP response headers, complicates the web- and browser-developer facing models for the features in question. Such cases require defining a conflict resolution procedure (e.g., HSTS's decision to choose the most-strict policy seen so far).

**Goal:** Centralize configuration for entire origin, so that when used exclusively, origin policy ensures coordination between individual resources and applications sharing the same origin.

### HTTP header redundancy

**Problem 1:** Some HTTP headers have to be sent again and again without actually changing their values. Sometimes these headers add significant number of bytes, e.g. [CSP](https://w3c.github.io/webappsec-csp/).

**Problem 2:** Some HTTP headers are sent with every response, even though their effect has a lifetime, e.g. [HSTS](https://tools.ietf.org/html/rfc6797). Within the valid time frame these headers do not need to be repeated.

**Goal:** Provide a mechanism to download origin-wide configurations only once per origin, instead of per request, and only update them when needed.

### Missing configurations

**Problem:** For complex web applications it is easy to forget configuring certain resources or pages, e.g. the error page.

**Goal 1:** Allow applying origin-wide fallback settings that are applied when correpsonding HTTP headers are not set.

**Goal 2:** Allow providing baseline settings that are guaranteed to be applied, e.g. baseline CSP which guarantees a certain minimum level of security for the entire origin.

### CORS-preflight overhead

**Problem:** For certain resources the CORS-preflight decisions can be predetermined. That is, the server decision to (dis-)allow access is independent of the actual request itself, but is instead static for certain requests, e.g. "allow all requests from a.com" or "use the [basic safe CORS protocol setup](https://fetch.spec.whatwg.org/#basic-safe-cors-protocol-setup)".

**Goal:** Provide a mechanism to inform the browser about CORS access decisions beforehand, to avoid the CORS-preflight request overhead.


## The proposal

### The origin policy manifest

Server operators can provide a per-origin **origin policy manifest**, at `/.well-known/origin-policy`, which is a JSON file that allows configuring various origin-wide settings. An example would be

```json
{
  "id": "my-policy",
  "content_security": {
    "policy": ["frame-ancestors 'none'", "object-src 'none'"],
    "policy_report_only": ["script-src 'self' https://cdn.example.com/js/"]
  },
  "features": {
    "policy": "geolocation 'self' https://example.com",
    "policy_report_only": "document-domain 'none'"
  },
  "cors_preflights": {
    "no_credentials": {
      "origins": "*"
    },
    "unsafe_include_credentials": {
      "origins": ["https://trusted.example.com/"]
    },
  },
  "origin_isolated": "best-effort"
}
```

For more on the policy format, see [the dedicated document](./policy-format.md).

### Fetching and applying the origin policy

Browsers then fetch and cache origin policies for a given origin. They can optionally do so proactively (e.g. for frequently-visited origins), but generally will be driven by the web application sending a HTTP response header requesting that a given origin policy be fetched and applied:

```
Origin-Policy: allowed=(none my-policy my-old-policy), preferred=my-policy
```

Here the header specifies allowed and preferred policies, which correspond to the JSON document's `"id"` value. This allows servers to take on a variety of behaviors, including:

* Require that a given origin policy be available (either from the cache or via fetching) and applied, before proceeding with page initialization
* Allow a previous revision of the policy, or no policy at all, to apply, but in the background do an asynchronous update of the policy so that future resource fetches will apply the preferred one.

For more on the model for fetching and updating origin policies, see [the dedicated document](./version-negotiation.md).

Another important note is that the policy items in question automatically stop applying (in a policy item-specific way) when the origin policy stops applying. So, for example, removing the `"content_security"` member of the origin policy manifest above would cause any future loads that use that origin policy to not include the CSP in question. Combined with the usual HTTP cache expiry mechanisms for the `/.well-known/origin-policy` resource, this allows a general "max age" mechanism for origin-wide configuration, similar to the `max-age` parameter of [HSTS](https://tools.ietf.org/html/rfc6797), but for all policy items.

### Configurable policy items

We anticipate specifying the following configurable policy items inside the origin policy:

* [Origin Isolation](https://github.com/domenic/origin-isolation)
* [Content Security Policy](https://w3c.github.io/webappsec-csp/)
* [Feature Policy](https://w3c.github.io/webappsec-feature-policy/)
* [Document Policy](https://github.com/w3c/webappsec-feature-policy/blob/master/document-policy-explainer.md)
* [Referrer Policy](https://w3c.github.io/webappsec-referrer-policy/)
* [Cross-Origin Resource Sharing](https://fetch.spec.whatwg.org/#http-cors-protocol)
* TLS Configuration, including [Strict Transport Security](https://tools.ietf.org/html/rfc6797) and [Expect-CT](https://httpwg.org/http-extensions/expect-ct.html)
* [Client Hints](https://httpwg.org/http-extensions/client-hints.html)

Some of these will be specified sooner than others, and plans may change as we do that specification and implementation work, but we hope to include at least origin isolation, content security policy, and feature policy in initial spec drafts.

See the [policy format](./policy-format.md) sub-explainer for information on the syntax and semantics envisioned for each of these.
