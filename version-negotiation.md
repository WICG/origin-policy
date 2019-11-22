# Explainer: version negotiation for origin policies

This explainer lays out the problem and solution space for how origin policies can be updated, in a privacy-preserving way.

## Use cases and requirements

### Async update ([#10](https://github.com/WICG/origin-policy/issues/10))

Web applications want to be able to decide that a previously-downloaded origin policy, or even no policy at all, is "good enough", and that they don't need to block the page load waiting for the newest origin policy version.

### Sync update

Web applications want to be able to decide that a certain policy is mandatory, and the page cannot load until it arrives and is applied.

Similarly, web applications may have previously sent a bad policy, which they need to replace before any further page loads continue.

### Kill switch

There needs to be a way for a page to remove any previous origin policies, before the page loads. This is essentially a special case of sync update, which doesn't require loading a new policy since the browser already knows what the null policy looks like.

### Privacy-preserving

Any scenario in which the browser communicates previously-sent information back to the server or website can be (ab)used as a cookie. Previous incarnations of origin policy communicated the currently-downloaded policy version. But even the behaviors controlled by origin policy could be used in this manner.

## Proposed model

Conceptually, origin policies are stored in the HTTP cache, under the URL `$origin/.well-known/origin-policy`. In particular, this means they are double-keyed [in the same way as the HTTP cache](https://github.com/whatwg/fetch/issues/904): that is, by (origin of document, origin of top-document). This prevents them from being used for cross-site tracking. This also means that clearing of the cache should generally clear any origin policy.

When the browser makes a request to _url_, it:

* Checks if it has something cached, and not expired, for `$that_origin/.well-known/origin-policy`. If so, this is the _candidate origin policy_; otherwise the _candidate origin policy_ is the null policy.
* Makes the request to _url_.
* The response can contain a header of the form `Origin-Policy: allowed=("policyA" "polB" "polC" null), preferred="policyZ"`. This indicates that policies with identifiers `"policyA"`, `"polB"`, `"polC"`, or `"policyZ"` are acceptable to the site, or the null origin policy. Call these the _list of acceptable policies_. If the response contains no such header, then the _list of acceptable policies_ contains just the null policy.
* Checks the _list of acceptable policies_ against the _candidate origin policy_.
  * If the _candidate origin policy_ is in the _list of acceptable origin policies_, then:
    * Apply the _candidate origin policy_ and load the response. (This might apply the null policy.)
    * If _candidate origin policy_ is not the preferred origin policy (indicated by the `preferrered=` portion), then the browser sends a low-priority request to `$that_origin/.well-known/origin-policy` to refresh the HTTP cache, but it won't apply for this page load.
  * Otherwise, if the _list of acceptable origin policies_ only contains the null policy but _candidate origin policy_ is not the null policy, then:
    * Apply the null policy anyway, and load the response with it.
    * In the background, re-fetch `$that_origin/.well-known/origin-policy` to refresh the HTTP cache.
  * Otherwise, the browser makes a request (on the same connection, if HTTP/2), to `$that_origin/.well-known/origin-policy`. It delays any processing of the response for _url_ until the new policy has been loaded. If the new policy's identifier still doesn't match the _list of acceptable policies_, then the result of the origin navigation request is a network error.

Here, the identifier for an origin policy is found inside its JSON document, e.g. `"identifier": "policyA"`.

Note the distinction between string-based policy identifiers, surrounded by quotes (e.g. `"policyA"`), and the `null` token, which is not quoted. This distinction is given to use by the structured headers specification.

### Evaluation

This model allows async update by having sites send a list of acceptable policies, as well as a preferred policy. If any of these match, then page loading will not be blocked.

This model allows sync update by having sites only include acceptable policies in the list of acceptable policies. If that policy isn't already downloaded, then page loading will not continue until the policy arrives.

This model allows a kill switch by having sites send `Origin-Policy: allowed=(null)`. In that case the null policy will be applied without any further action.

This model is privacy-preserving in that it uses the HTTP cache double-keying semantics for the origin policy data and behavior.

### Comparison to previous model

Compared to the [previously-specified model](https://github.com/WICG/origin-policy/tree/c3be6b3b84c92a8e49fce1a5eca91a7eb70c4158), this model has the following advantages:

* **Preserves privacy.** The previous use of the `Sec-Origin-Policy` "cookie-like" header, with no double-keying, was problematic.
* **Allows use of HTTP cache semantics to expire policies.** Previously policy expiration would be done more manually, by the browser telling the server about its current version using `Sec-Origin-Policy`, and the server possibly replying with an update. Now, `Cache-Control` or `Expires` on the `/.well-known/origin-policy` resource can be used for expiration.
* **Allows async update.** Previously there was no mechanism specified to allow the server to signal their preferred policy, separate from their allowed policy.
* **Is more frugal.** In particular, it does not require the client to send any request headers. Instead it relies on `/.well-known/` URLs.
* **Works on subresources.** Nothing in this protocol is specific to navigation requests. It can also be used to gather origin policies from subresources; for example a page on `https://www.example.com/` which performs `fetch("https://api.example.com/endpointA")` could perform a CORS preflight the first time, but come back with an async-updated origin policy keyed to the (`https://api.example.com/`, `https://example.com/`) tuple which allows a future fetch to `https://api.example.com/endpointB` to avoid the CORS preflight.

The main drawback of this model is that it is slightly less efficient in some sync update cases. In particular, in this model, if a site wants to mandate a specific policy before any page loads occur, it has two choices:

* Use HTTP/2 Push to send the policy unconditionally on all loads. This wastes bytes and bandwidth if the policy is already cached.
* Do not use HTTP/2 Push to send the policy. Then, the browser will perform a second request to retrieve the policy, if the policy is *not* already cached.

The previous model threaded this needle by sending the `Sec-Origin-Policy` header with the request, containing the current origin policy version, which allows the server to decide intelligently whether or not to push a new origin policy. However, this was universally disliked.

We think this drawback is acceptable. In particular, we anticipate async updates being more common, so we should optimize for those cases. For truly mandatory sync updates, sites could use HTTP/2 Push; in that case, the result is largely the same as what sites are doing today by sending a bunch of headers with every response.

## Potential extension

To solve the drawback mentioned above, and allow efficient sync updates, user agents could more proactively fetch the `/.well-known/origin-policy` URL. In the extreme, they could fetch it along with every request they make, in parallel with the main request. The benefits of such a strategy are that, for cases where a site wants to mandate a specific policy before any page loads occur, the most-recent origin policy has already been requested in parallel with the main request to support that page load. That is, it eliminates the potential round trip or redundant HTTP/2 Push.

### Cost evaluation

This is not as scary as it sounds:

* Most of the time this would result in 404 or 304 responses, or even no network activity at all if the previous origin policy was delivered with `max-age`.
* The origin policy request is to the same origin as the main request, and could go over the same connection.
* The origin policy request would HPACK well with the main request.

However, it does have some drawbacks:

* Even though the responses may be trivial (e.g. mostly 304s), this doubles all servers' queries per second, which can be a burden for server operators in terms of CPU time.
* In HTTP/2 (and HTTP/3), servers impose a limit on the number of concurrent streams a client can open, which historically are tuned to limit the number of concurrent "actual" requests. Deploying this strategy would effectively halve the number of concurrent requests to a server, until or unless the server ecosystem raises their concurrent stream limits.

### `Origin-Policy` header

In this world, the `Origin-Policy` header becomes less necessary. With the browser proactively fetching "the current origin policy", the entry point no longer needs to be the page signaling a desire for an origin policy.

However, the header still provides value in the following ways:

* In the case where the main response headers have come back, before the origin policy response has completed, it allows the page to signal that it has no need to block main-response processing on retrieving the most-updated origin policy, as long as the currently-cached one is in the `allowed=` list.
* Via the `Origin-Policy: allowed=(null)` kill switch, it provides an immediate way to signal to the browser that no origin policy should apply, regardless of the cache or origin policy response.

Essentially, if we think of the origin policy request and the main request as racing, the `Origin-Policy` header allows the main request to declare itself the winner of the race, thus taking the overall latency from `max(main request/response round-trip time, origin policy request/response round trip time)` to just `main request/response round-trip time`.

### Conclusion

Given the above considerations, we feel justified in considering this avenue as a potential expansion to the main proposal, which can be developed and experimented with as a compatible extension to the main proposal. In particular, it will be helpful to find out how often web applications need sync policy updates in practice, and in such cases, how costly the redundant bytes or round-trips are.

In the spirit of such experimentation, it's worth noting that this potential extension doesn't have to applied to the extreme of every response. We could specify something more flexible, allowing the browser to optionally send requests to `/.well-known/origin-policy` as desired. For example, browsers might do this for sites that users visit often—either concurrent with other requests to this origin, as above, or just in general idle time.
