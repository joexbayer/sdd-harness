---
status: advisory
---
OWASP ASVS 5.0.0, level 3: high assurance (level 2 plus the strictest controls: finance, health, critical systems).
ASVS3-1 MUST encode output and validate input at every new input, query, template or output sink (V1, V2).
ASVS3-2 MUST secure each new page, cookie, header, endpoint or CORS rule (V3, V4).
ASVS3-3 MUST confine uploads, downloads, archives and paths built from input (V5).
ASVS3-4 MUST check who is logged in and who may act on every login, password, session, role or ownership change (V6, V7, V8).
ASVS3-5 MUST treat JWTs, third-party login and token scopes as untrusted until verified (V9, V10).
ASVS3-6 MUST use vetted cryptography and TLS for hashing, encryption and keys (V11, V12).
ASVS3-7 MUST keep secrets out of code, with safe defaults, and protect personal or sensitive data (V13, V14).
ASVS3-8 MUST justify each new dependency, trust boundary or risky component (V15).
ASVS3-9 MUST NOT leak detail in errors, and MUST log the events that need a trace (V16).
ASVS3-10 SHOULD secure WebRTC media and signalling when peer-to-peer is used (V17).
