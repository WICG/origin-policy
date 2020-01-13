# Security and privacy

See spec's [Security and Privacy](https://wicg.github.io/origin-policy/#privacy-and-security) section.

## Questionnaire answers

The following are the answers to the W3C TAG's [security and privacy self-review questionnaire](https://www.w3.org/TR/security-privacy-questionnaire/).

**Does this specification deal with personally-identifiable information?**

No.

**Does this specification deal with high-value data?**

No.

**Does this specification introduce new state for an origin that persists across browsing sessions?**

Yes. The origin policy persists across browsing sessions using the HTTP cache.

**Does this specification expose persistent, cross-origin state to the web?**

No.

**Does this specification expose any other data to an origin that it doesn’t currently have access to?**

No.

**Does this specification enable new script execution/loading mechanisms?**

No.

**Does this specification allow an origin access to a user’s location?**

No.

**Does this specification allow an origin access to sensors on a user’s device?**

No.

**Does this specification allow an origin access to aspects of a user’s local computing environment?**

No.

**Does this specification allow an origin access to other devices?**

No.

**Does this specification allow an origin some measure of control over a user agent’s native UI?**

No.

**Does this specification expose temporary identifiers to the web?**

No.

**Does this specification distinguish between behavior in first-party and third-party contexts?**

Yes. Because it relies on the HTTP cache, which is [double- or triple-keyed](https://github.com/whatwg/fetch/issues/904), the behavior will differ depending on whether the origin is being embedded or not. See also [this example in the spec](https://wicg.github.io/origin-policy/#example-third-party).

**How should this specification work in the context of a user agent’s "incognito" mode?**

Because origin policy relies on the HTTP cache, the mechanisms specified here will be affected. In particular, we expect that previous origin policies will no longer be consulted, and any origin policies stored during incognito mode sessions will be discarded after exiting the session.

**Does this specification persist data to a user’s local device?**

Yes, via the HTTP cache.

**Does this specification have a "Security Considerations" and "Privacy Considerations" section?**

[Yes](https://wicg.github.io/origin-policy/#privacy-and-security).

**Does this specification allow downgrading default security characteristics?**

No.
