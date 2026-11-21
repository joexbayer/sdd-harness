---
status: advisory
---
OWASP ASVS 5.0.0, level 2: most apps (level 1 plus defence in depth for sensitive data).
ASVS2-1 MUST encode output and validate input at every new input, query, template or output sink (V1, V2).
ASVS2-2 MUST secure each new page, cookie, header, endpoint or CORS rule (V3, V4).
ASVS2-3 MUST confine uploads, downloads, archives and paths built from input (V5).
ASVS2-4 MUST check who is logged in and who may act on every login, password, session, role or ownership change (V6, V7, V8).
ASVS2-5 MUST treat JWTs, third-party login and token scopes as untrusted until verified (V9, V10).
ASVS2-6 MUST use vetted cryptography and TLS for hashing, encryption and keys (V11, V12).
ASVS2-7 MUST keep secrets out of code, with safe defaults, and protect personal or sensitive data (V13, V14).
ASVS2-8 MUST justify each new dependency, trust boundary or risky component (V15).
ASVS2-9 MUST NOT leak detail in errors, and MUST log the events that need a trace (V16).
ASVS2-10 SHOULD secure WebRTC media and signalling when peer-to-peer is used (V17).
