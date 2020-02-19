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
  "ids": ["my-policy"],
  "content_security": {
    "policies": ["frame-ancestors 'none'", "object-src 'none'"],
    "policies_report_only": ["script-src 'self' https://cdn.example.com/js/"]
  },
  "features": {
    "policy": "geolocation 'self' https://example.com",
    "policy_report_only": "document-domain 'none'"
  },
  "isolation": {
    "prefer_isolated_event_loop": true,
    "prefer_isolated_memory": true
  }
}
```

For more on the policy format, see [the dedicated document](./policy-format.md).

### Fetching and applying the origin policy

Browsers then fetch and cache origin policies for a given origin. They can optionally do so proactively (e.g. for frequently-visited origins), but generally will be driven by the web application sending a HTTP response header requesting that a given origin policy be fetched and applied.

For more on the model for fetching and updating origin policies, including motivations behind the design, see [the dedicated document](./version-negotiation.md). Here we summarize the most common patterns applications will probably use:

#### Optional-but-suggested policy

```
Origin-Policy: preferred="my-policy", allowed=("my-old-policy" null)
```

This allows a previous revision of the policy (identified by `"my-old-policy"`), or no policy at all (`null`), but specifies that the `"my-policy"` revision is preferred. This response might be processed with the old or null origin policy if those are in the HTTP cache, but in that case, the browser will perform an asynchronous update to fetch the latest policy for use with future responses.

If a _different_ origin policy is found in the HTTP cache, apart from `"my-policy"` or `"my-old-policy"`, then the response will use the null origin policy, since that is allowed.

#### Latest available policy, if any

```
Origin-Policy: preferred=latest-from-network, allowed=(latest null)
```

This says that any cached origin policy from `/.well-known/origin-policy` can be used, but if no such policy is cached, then the null policy will be used instead. In either case, the latest policy will be fetched asynchronously.

This is essentially a simplification of the previous version, where the server operator is expressing fewer constraints on the exact contents of the policy.


#### Mandatory policy

```
Origin-Policy: allowed=("my-policy")
```

This says that the only origin policy that is allowed is one identified by `"my-policy"`. The origin policy must be fetched, from the cache or network, and must have an `"ids"` value that contains `"my-policy"`, before the response can be processed. If such an origin policy cannot be found, then the response will be treated as a network error.

This makes the most sense if the origin policy contains security-critical policies which would not be acceptable to continue without.

### Policy expiry

Policy items in question automatically stop applying (in a policy item-specific way) when the origin policy stops applying. So, for example, removing the `"content_security"` member of the origin policy manifest above would cause any future loads that use that origin policy to not include the CSP in question. Combined with the usual HTTP cache expiry mechanisms for the `/.well-known/origin-policy` resource, this allows a general "max age" mechanism for origin-wide configuration, similar to the `max-age` parameter of [HSTS](https://tools.ietf.org/html/rfc6797), but for all policy items.

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

Note that generally, if a policy item can be configured both with origin policy and on a per-resource level, the per-resource headers will have precedence. The exact meaning of "precedence" depends on the policy item in question.

See the [policy format](./policy-format.md) sub-explainer for information on the syntax and semantics envisioned for each of these.
