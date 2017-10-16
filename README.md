
# Explainer: Origin Manifest

**tl;dr** Origin Manifest is a web platform mechanism
that aims to shift configuring the origin from web applications to the origin
itself. For this the origin provides a manifest file in a predefined well-known
location which browsers can load and apply.


## The Problems and Goals

### Configurations with origin-wide effects
**Problem:** Some configuration delivery mechanisms, e.g. like HTTP headers, affect an entire
  origin even though they might have been set through only a sub-resource load.
  Misconfiguration of font resource header can have dramatic effects for the
  origin, e.g. a wrong HPKP value.

**Goals:** Configurations for web applications with effects on entire origin in
  a more structured way to minimize the chances for origin misconfiguration
  through individual web applications sharing the same origin.

### HTTP header redundancy
**Problem 1:** Some HTTP headers have to be sent again and again without actually changing the
  values. Sometimes these headers add significant number of
  bytes, e.g. CSP.

**Problem 2:** Some HTTP headers are sent with every response even though their
  effect has a lifetime, e.g. HSTS. Within the valid time frame these headers
  do not need to be repeated.

**Goal:** Mechanism to download configurations like HTTP header values only
  once. These values are only overridden when needed.

### Missing configurations
**Problem:** For complex web applications it is easy to forget configuring
  certain resources or pages, e.g. the error page.

**Goal 1:** Fallback settings that are applied when HTTP headers are not set.

**Goal 2:** Baseline settings that guaranteed to be applied, e.g. baseline CSP
  which guarantees a certain least level of security for the entire origin.

### CORS-preflight overhead
**Problem:** For certain resources the CORS-preflight decisions can be
  pre-determined. That is, the server decision to (dis-)allow access is
  independent of the actual request itself but static for certain requests, e.g.
  "allow all requests from a.com".

**Goal:** Mechanism to inform a browser about CORS access decisions beforehand
  to avoid CORS-preflight request overhead.


## The Proposal
We propose Origin Manifest as a web platform mechanism that aims to shift
configuring the origin from web applications to the origin itself.

### Server side
Origin Manifest files are to be published in a well-known location on the
server. This enforces that the origin and not the individual web apps defines
them.

### Client side
Web clients fetch and cache manifests for an origin. There can always be at most
one manifest for an origin. The client enforces the configurations from a
manifest similar to how HTTP headers are used. In fact, currently most
configurations directly relate to HTTP headers, e.g. CSP.

### Origin Manifest File

#### File Format
Origin Manifests must be written in valid JSON format. The currently discussed
schema will look like or similar to the one propsed by Mike West in
[Issue 19]{https://github.com/WICG/origin-policy/issues/19#issuecomment-321229817}.

#### Versioning
Updates to the Origin Manifest file are natural. To this end every manifest has
a by the server defined version identifier. This allows firstly to easily
identify if a client needs to fetch a newer version. Secondly, it allows a web
application to decide that a manifest cached in the client is "good enough" to
avoid fetching a newer version for performance reasons.


### Fetching Protocol
Clients always set the `Sec-Origin-Manifest` header to indicate the support for
the mechanism. Servers can then opt-in to use the mechanism by sending back a
`Sec-Origin-Manifest` header with the current manifest version. If servers
should decide to not send the header, clients try to retreive a manifest from
their cache and not use Origin Manifest otherwise.

#### Opt-in
In case no manifest is cached the client indicates support for the feature by
setting the value 1.
![Opt-in](/images/opt_in.png)

#### Updating and Confirming
In case a manifest is cached the client informs the server about the currently
cached version. If the version is accepted by the server the response simply
confirms the header. No fetch is needed. Otherwise the new version is fetched.
![Updating and Confirm](/images/update.png)

#### Opt-out
Servers can decide not no longer use Origin Manifest. If so they can set the
`Sec-Origin-Manifest` header to 0 in the response. Clients then behave like no
manifest was ever set and remove the currently cached manifest from cache (if
any).

## Related Work
Mark Nottingham came up with basically the same idea around the same time
[https://mnot.github.io/I-D/site-wide-headers/]{https://mnot.github.io/I-D/site-wide-headers/}.
The goal is of course to pick the best parts from both approaches and to merge
them into a useful mechanism.


## Discussion
**Why is the current version sent?**

The currently cached version is set in the request header to allow HTTP2 Push.
In particular, the server can decide to push the manifest since it knows whether
it will be eventually fetched or not.


**Why does it defer the response?**

Certain configuration options, e.g. CSP, require to be loaded before the actual
content is processed, e.g. a HTML document is rendered. This makes it also
fundamentally different from Application Manifest (TODO: ref here).


**Why not just using HTTP caching and ETag?**

We need to process Origin Manifests differently from other data fetched over
HTTP. In particular, it allows us to manage the different versions and to ensure
that there exists at most only exactly one manifest per origin.
Directly related to the above question "Why is the current version sent?",
servers using HTTP/2 would start pushing the manifest to the client which clients
would need to cancel. This imposes performance costs we want to avoid.
