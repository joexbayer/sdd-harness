---
id: {{id}}
type: contract
title: {{title}}
status: open
created: {{date}}
---
# {{id}} {{title}}

## Why
<!-- What the sides need to agree on, and what goes wrong without it. 2-4 lines. -->

## Contract
<!-- The files under specs/contracts/ this adds or changes, and the change itself: the
endpoints, fields or messages, with an example of each. Items name a contract by its file or
folder name without the extension: specs/contracts/orders-api.yaml is `contracts: orders-api`.
sdd does not read the format: the project's check validates it. -->

## Users
<!-- The items (and sides: frontend, backend, a job) that build against it, one per line,
e.g. "item 31 (Orders page): reads GET /orders". Not opened yet: say which side. -->

## Compatibility
<!-- Breaking or not, and why. Every open item using it (`contracts: <name>`) goes back to
planning when this ships: name them and what each must change. -->

## Security
<!-- Does the contract carry untrusted input, login or permissions, secrets or personal data?
If not: "none: <why>". Otherwise, per risk: what can go wrong → what the contract requires
(auth on an endpoint, a field's limits, what is never returned). -->

## Done when
<!-- DOD-{{id}}.1 <observable outcome>, e.g. "the project's check validates
specs/contracts/orders-api.yaml". -->

## Built
<!-- The contract diff as applied (or a summary of a large one), and that the check passed.
A contract item lands no code: only specs/ changes. -->

## Review (optional)
<!-- The human's review notes: what to change, one per line. The agent works through them
and says under "## Built" what it changed for each. -->
