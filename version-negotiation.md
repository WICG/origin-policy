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

### Cache-friendly

There must be a way to express that a new origin policy should apply even to take long-lived, cached resources, e.g. static HTML pages. This can be tricky since such cached responses are, by definition, not updated, and so cannot explicitly request the new policy.

## Proposed model

Conceptually, origin policies are stored in the HTTP cache, under the URL `$origin/.well-known/origin-policy`. In particular, this means they are double-keyed [in the same way as the HTTP cache](https://github.com/whatwg/fetch/issues/904): that is, by (origin of document, origin of top-document). This prevents them from being used for cross-site tracking. This also means that clearing of the cache should generally clear any origin policy.

A policy can have several identifiers, found in its JSON document as, for example, `"ids": ["policyA", "polB"]`.

The `Origin-Policy` header can express that it allows, or prefers, specifically-identified policies. The header also can express that it allows any policy, with the token `lastest`, or that it allows no policy at all, with the token `null`. Finally, the header can express that it prefers the latest origin policy from the network, with the token `latest-from-network`.

* ID-based matching is used when the web application wants to express constraints on the contents of the policy.
* `latest` and `latest-from-network` are used when the web application wants to ensure there is an origin policy, but does not want to take on the maintenance burden of expressing ID-based constraints.
* `null` is used when the web application is OK with a given response being processed without an origin policy, for example to avoid an extra server round-trip.

(Note the distinction between string-based policy identifiers, surrounded by quotes, and the special tokens, which are not quoted. This distinction is given to us by the structured headers specification.)

### Evaluation

This model allows async update by having sites send a list of acceptable policies, as well as a preferred policy. If any of these match, then page loading will not be blocked.

This model allows sync update by having sites only include acceptable policies in the list of acceptable policies. If that policy isn't already downloaded, then page loading will not continue until the policy arrives.

This model allows a kill switch by having sites send `Origin-Policy: allowed=(null)`. In that case the null policy will be applied without any further action.

This model is privacy-preserving in that it uses the HTTP cache double-keying semantics for the origin policy data and behavior.

This model is cache-friendly by allowing multiple ID values for a policy. When updating a policy, server operators should keep the previous ID value in the array, until any cached resources that are requesting that ID have expired.

### Comparison to previous model

Compared to the [previously-specified model](https://github.com/WICG/origin-policy/tree/c3be6b3b84c92a8e49fce1a5eca91a7eb70c4158), this model has the following advantages:

* **Preserves privacy.** The previous use of the `Sec-Origin-Policy` "cookie-like" header, with no double-keying, was problematic.
* **Allows use of HTTP cache semantics to expire policies.** Previously policy expiration would be done more manually, by the browser telling the server about its current version using `Sec-Origin-Policy`, and the server possibly replying with an update. Now, `Cache-Control` or `Expires` on the `/.well-known/origin-policy` resource can be used for expiration.
* **Allows async update.** Previously there was no mechanism specified to allow the server to signal their preferred policy, separate from their allowed policy.
* **Is more frugal.** In particular, it does not require the client to send any request headers. Instead it relies on `/.well-known/` URLs.
* **Works on subresources.** Nothing in this protocol is specific to navigation requests. It can also be used to gather origin policies from subresources; for example a page on `https://www.example.com/` which performs `fetch("https://api.example.com/endpointA")` could perform a CORS preflight the first time, but come back with an async-updated origin policy keyed to the (`https://api.example.com/`, `https://example.com/`) tuple which allows a future fetch to `https://api.example.com/endpointB` to avoid the CORS preflight.
* **Is more cache-friendly.** Previously, cached resources would downgrade the default origin policy for the entire origin to the old revision that they requested. (This default would only matter for pages which did not send an explicit `Sec-Origin-Policy` header, though, so this merely unfortunate, not terrible.)

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
