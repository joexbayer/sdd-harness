---
status: advisory
---
OWASP Top 10 for LLM Applications 2025: apps that call a model.
LLM-1 MUST keep user or fetched text from steering a prompt (LLM01 Prompt Injection).
LLM-2 MUST keep secrets and personal data out of prompts, context and output (LLM02 Sensitive Information Disclosure).
LLM-3 MUST vet each new model, dataset, plugin or package (LLM03 Supply Chain).
LLM-4 MUST NOT train, fine-tune or retrieve from untrusted data unchecked (LLM04 Data and Model Poisoning).
LLM-5 MUST treat model output as untrusted before rendering, executing or passing it on (LLM05 Improper Output Handling).
LLM-6 MUST limit the tools, permissions and actions given to the model (LLM06 Excessive Agency).
LLM-7 MUST NOT hold secrets or rules in the system prompt (LLM07 System Prompt Leakage).
LLM-8 MUST apply access control to vector stores and retrieval (LLM08 Vector and Embedding Weaknesses).
LLM-9 SHOULD check answers users rely on (LLM09 Misinformation).
LLM-10 MUST limit tokens, calls, cost and request rate (LLM10 Unbounded Consumption).
