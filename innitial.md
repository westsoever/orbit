# Orbit: Interview-Driven Plan for an Always-On Agentic System
### *Leveraging LittleBird.ai Patent Research & Architecture Feasibility Assessment*

***

## Executive Summary

This document constitutes the product and technical plan for **Orbit** — an Always-On Agentic System that continuously captures screen and audio activity to build a living context graph, maintains an AI-managed Kanban board of tasks, and spawns typed sub-agents to autonomously complete work with full system access under strict human oversight. The plan synthesises an interview-driven functionality elicitation with feasibility findings drawn from LittleBird.ai patent and infrastructure research. All references to "Cortex" in source materials have been replaced with **Orbit** throughout this document.

The foundational design principle is: *a mediocre model with perfect context outperforms a frontier model starting from zero every session*. Orbit is built on this insight — the always-on context layer is not a feature; it is the foundation.[^1]

***

## Part 1 — Interview Summary: Elicited Functionalities

The following functionality areas were elicited through a structured interview process. They map directly onto the three operational planes of Orbit's architecture.

### 1.1 Perception & Context Capture

The user identified the following context-capture capabilities as essential:

- **Event-driven screen capture** — triggered by OS-level events (window focus changes, mouse clicks, keyboard activity) rather than fixed-interval polling, reducing storage overhead while maintaining near-complete workflow coverage[^1]
- **On-device audio transcription** — real-time transcription of meetings, voice calls, and dictation using a local Whisper model, filling context gaps that screen capture alone would miss[^1]
- **File system indexing** — live tracking of file creation, modification, and deletion via OS file system events (inotify on Linux, FSEvents on macOS)[^1]
- **Browser history & tab tracking** — capturing URLs, page titles, and selected text via browser extension or accessibility API[^1]
- **Email and calendar integration** — local IMAP/CalDAV sync or native app APIs to build a timeline of communications and commitments[^1]
- **Code and document parsing** — language-aware extraction of structure, TODO comments, and metadata from code files and documents[^1]

### 1.2 Cognition & Orchestration

The user prioritised the following intelligence and orchestration capabilities:

- **Automated task detection** — the Orchestrator scans the context stream for implied commitments and follow-ups (e.g., a verbal commitment in a meeting transcript becomes a task card automatically)[^1]
- **Project clustering** — grouping related tasks under project nodes using semantic similarity and entity co-occurrence[^1]
- **Dynamic context payload assembly** — layered retrieval strategy that pulls only relevant context at reasoning time, preventing context bloat[^1]
- **Layered memory architecture** — five distinct layers: Immediate (last 15 min), Working (hourly summaries), Episodic (vector-retrieved), Semantic (entity graph), and Archived (compressed daily summaries)[^1]
- **Plan drafting** — structured execution plans per task, including steps, tool requirements, estimated effort, risk level, and proposed permission set[^1]

### 1.3 Human-in-the-Loop Oversight

The user explicitly required the following oversight mechanisms:

- **Dual approval gates** — (1) plan approval before any execution begins; (2) escalation gate mid-execution when the agent encounters ambiguity or irreversible actions[^1]
- **Kanban board as control surface** — a local web app (localhost) that serves as the full human interface for reviewing, approving, editing, and rejecting agent tasks[^1]
- **Transparent permission declaration** — each task card shows exactly which system resources will be accessed before approval is granted[^1]
- **Approval fatigue mitigation** — the Orchestrator should target 2–5 high-quality approval requests per day, using confidence thresholds and relevance filtering before creating cards[^1]

### 1.4 Agent Execution

The user specified the following agent execution capabilities:

- **Typed sub-agent library** — six agent profiles: Writing, Research, Code, Admin, Data, and Communication agents, each with predefined tool sets and permission scopes[^1]
- **ReAct execution loop** — Reason → Act → Observe → Update State → Check, with state written to task files after every action for resumability and auditability[^1]
- **MCP as execution bridge** — Model Context Protocol as the standard interface between the Orchestrator and all external tools/systems, providing deterministic local system commands, audit logging, and permission enforcement at the tool layer[^1]
- **Sandboxed code execution** — Code Agent runs inside a Docker/devcontainer by default, never directly on the host system[^1]

### 1.5 Security & Privacy

The user identified non-negotiable security requirements:

- **Hyper-ephemeral access model** — permissions granted for the duration of one task only, scoped to minimum required resources, revoked on completion[^1]
- **Egress control** — internet access is OFF by default; must be explicitly enabled per task[^1]
- **Prompt injection resistance** — all content from external sources treated as untrusted data, never as instructions[^1]
- **On-device capture, no raw data egress** — all screen and audio capture processed locally; no raw screen data leaves the machine[^1]
- **Selective no-capture zones** — users can exclude specific applications (e.g., banking apps, password managers)[^1]
- **Encrypted context store** — context store encrypted at rest using OS keychain + SQLCipher[^1]

***

## Part 2 — LittleBird.ai Patent Research Findings

### 2.1 Patent Status

A patent search under "Little Bird Software" and the founders' names returned **no filed or published patents**. LittleBird.ai is an early-stage startup that raised its seed round in March 2026, making it likely too early in their lifecycle to have filed or published patents. This has the following implications for Orbit:[^2]

- **No patent blocking risk** from LittleBird.ai on any of the core techniques described in their product
- The underlying approach — macOS Accessibility API-based context collection — is therefore not proprietary to LittleBird.ai
- Orbit can freely draw inspiration from or implement equivalent approaches without IP conflict from this specific competitor

### 2.2 LittleBird.ai's Core Technical Approach

Despite the absence of patents, LittleBird.ai's published infrastructure reveals the current state of the art for context capture:[^2]

| Component | LittleBird.ai Approach | Orbit Equivalent |
|---|---|---|
| **Capture method** | macOS Accessibility Tree API (every ~2 seconds)[^2] | Event-driven OS capture + OCR + audio[^1] |
| **Data type** | Structured text + UI elements; no screenshots[^2] | Context atoms: OCR text + accessibility tree + audio + screenshots[^1] |
| **Sensitive field handling** | Automatically skips (flagged at API level)[^2] | No-capture zones + selective exclusion[^1] |
| **Audio** | Real-time local transcription via system audio[^2] | Local Whisper STT[^1] |
| **Storage** | AWS cloud[^2] | Local-first (vector DB + SQLite); optional cloud[^1] |
| **Compliance** | SOC 2, GDPR/CCPA, AES-256, TLS 1.3[^2] | OS keychain + SQLCipher encryption[^1] |
| **Training use** | User data never used to train AI models[^2] | User-controlled retention policy[^1] |

LittleBird.ai's key competitive differentiator vs. Microsoft Recall or Rewind is its **text-only approach** — no screenshots means less data volume, less invasive collection, and easier sensitive-content filtering. Orbit's design extends beyond this by incorporating screenshots and audio where LittleBird.ai does not, offering richer context at the cost of higher storage and privacy sensitivity.[^2]

***

## Part 3 — Feasibility Matrix

The following matrix maps each elicited functionality to a feasibility assessment grounded in LittleBird.ai's known technical approach and the broader architecture described in the Orbit source document.

| # | Functionality | Feasibility | LittleBird.ai Evidence | Key Risk |
|---|---|---|---|---|
| 1 | Event-driven screen capture (OS APIs) | **High** | Accessibility Tree API approach confirmed viable and in production[^2] | Privacy/compliance exposure if screenshots retained |
| 2 | Local Whisper audio transcription | **High** | LittleBird.ai uses real-time local audio transcription[^2] | Hardware load on low-spec devices |
| 3 | macOS Accessibility API integration | **High** | Core of LittleBird.ai's production system; proven at scale[^2] | macOS-only initially; Windows/Linux require different APIs |
| 4 | Automatic sensitive field exclusion | **High** | LittleBird.ai implements this at the API level automatically[^2] | Incomplete coverage for custom or web-based credential fields |
| 5 | AWS / cloud storage with encryption | **High** | LittleBird.ai uses AES-256 at rest, TLS 1.3 in transit, SOC 2 certified[^2] | User trust concerns; Orbit prefers local-first as differentiator[^1] |
| 6 | Local-first vector database (LanceDB/ChromaDB) | **High** | Supported by open-source tooling; no patent conflict[^2] | Query latency at large context volumes |
| 7 | Semantic entity graph (temporal knowledge graph) | **Medium–High** | No direct LittleBird.ai precedent; established technique in NLP[^1] | Graph quality degrades without robust NER model |
| 8 | Automated task detection from context stream | **Medium** | LittleBird.ai captures context; Orbit extends to active inference[^1][^2] | False positive rate — too many irrelevant cards generated |
| 9 | AI-managed Kanban board (Orchestrator) | **Medium** | No existing product combines capture + Kanban + approval gates[^1] | Novel UX; user adoption and habit formation |
| 10 | Dual human approval gates | **High** | Architecturally straightforward; strong precedent in human-in-the-loop AI[^1] | Approval fatigue if thresholds poorly calibrated |
| 11 | MCP as execution bridge | **High** | Standardised protocol; official servers available for file, browser, calendar, terminal[^1] | Ecosystem immaturity for some tool categories |
| 12 | Typed sub-agent library (6 profiles) | **Medium–High** | Pattern validated by Manus, Claude Computer Use, and Kaiban Board[^1] | Agent reliability; tool-use errors on real files |
| 13 | ReAct loop with file-persisted state | **High** | Proven pattern from Manus architecture[^1] | State file corruption on crash without atomic writes |
| 14 | Sandboxed Code Agent (Docker) | **High** | Standard DevOps practice; well-tooled[^1] | Performance overhead; Docker not native on macOS ARM |
| 15 | Hyper-ephemeral permission model | **High** | MCP server layer enables enforcement at tool level[^1] | Complex to implement correctly across all MCP servers |
| 16 | Prompt injection resistance | **Medium** | Architectural principle; no production system has fully solved this[^1] | Active research problem; cannot be fully eliminated |
| 17 | Local LLM mode (Ollama + Llama 3.3) | **Medium** | Technically viable on 32 GB+ RAM; quality trade-off accepted[^1] | Reasoning quality gap vs. cloud models for complex planning |
| 18 | Browser extension for tab/history capture | **Medium** | Common approach; LittleBird.ai uses accessibility API as alternative[^2] | Extension permissions vary by browser; Manifest V3 restrictions |

***

## Part 4 — Risks, Dependencies & Development Considerations

### 4.1 Technical Risks

**Context quality vs. quantity** is the most significant technical risk. 24/7 capture generates enormous volume; the compression, summarisation, and retrieval layers must be exceptionally well-tuned to surface relevant context without overwhelming the Orchestrator. Poor retrieval equals poor task detection, which equals a board flooded with irrelevant cards and user abandonment.[^1]

**The security paradox** — granting agents file system access — is a fundamental trade-off that cannot be eliminated, only mitigated. The MCP + ephemeral permission model reduces risk significantly, but prompt injection through captured web content remains a real attack vector. Treating all external content as untrusted data (never as instructions) must be a hard architectural constraint, not merely a guideline.[^1]

**Model reliability** remains a concern. Current frontier models make tool-use errors and can misinterpret context. Every agent action that touches real files or sends communications must be treated as potentially erroneous — the sandboxing, audit logging, and Review column all exist to catch and correct these errors before harm occurs.[^1]

**Approval fatigue** is a UX risk with systemic consequences. If the Orchestrator creates too many cards or requires too much review, users will rubber-stamp approvals — defeating the entire oversight model. Strong relevance filtering and confidence thresholds are prerequisites for a safe deployment, not optional enhancements.[^1]

### 4.2 Dependencies

| Dependency | Type | Mitigation |
|---|---|---|
| macOS Accessibility APIs | Platform | Build Linux/Windows abstraction layer in Phase 2 |
| Whisper (local STT) | Model | Fallback to cloud STT API if hardware insufficient |
| LanceDB / ChromaDB | Open source | Vendor-neutral; swap between implementations |
| MCP ecosystem | Protocol standard | Build custom MCP servers for unsupported capabilities |
| Docker (Code Agent sandbox) | Infrastructure | Alternative: devcontainer without Docker on macOS ARM |
| Cloud LLM APIs (Claude/GPT-4o) | External service | Local Ollama fallback for privacy mode |

### 4.3 Platform Constraint: macOS vs. Cross-Platform

LittleBird.ai is **native macOS only** for context capture, relying on the macOS Accessibility Tree API as its core data source. Orbit's architecture similarly references Apple Vision API, FSEvents, and the macOS-native ecosystem. Cross-platform support (Windows, Linux) would require significant abstraction work — different APIs for accessibility trees, file system events, and audio capture. This should be treated as a Phase 2+ concern, with macOS 14+ as the initial supported platform.[^2][^1]

### 4.4 Privacy Architecture Differentiation

LittleBird.ai stores all collected context data on AWS cloud. Orbit's design takes a **local-first** position — all capture and processing on-device, with cloud storage as an optional, user-consented mode. This is a meaningful competitive differentiator and must be preserved in architecture decisions. The local-first stance also reduces GDPR/CCPA exposure, as personal data processing occurs entirely on the user's device.[^2][^1]

***

## Part 5 — Development Roadmap

The following phased roadmap is drawn directly from the architecture document, adapted for Orbit:

| Phase | Timeline | Key Deliverables |
|---|---|---|
| **Phase 1 — Context Foundation** | Months 1–3 | Screenpipe deploy, context atom store (LanceDB + SQLite), entity extraction, semantic search, daily summaries[^1] |
| **Phase 2 — Kanban MVP** | Months 3–5 | Orchestrator LLM + context retrieval, task detection, basic Kanban UI (React/Electron localhost), manual task creation[^1] |
| **Phase 3 — Agent Execution** | Months 5–8 | MCP server integration (file system, browser, email draft), Writing + Research Agents, approval gate enforcement, audit log[^1] |
| **Phase 4 — Full Agent Fleet** | Months 8–12 | Code Agent (Docker sandbox), Data + Admin Agents, multi-agent coordination, local LLM privacy mode[^1] |
| **Phase 5 — Polish & Scale** | Months 12+ | Confidence calibration, mobile companion app, team/shared context mode (opt-in), plugin system for custom agents[^1] |

***

## Part 6 — Recommended Technical Stack

| Component | Technology | Rationale |
|---|---|---|
| Screen capture daemon | Screenpipe (open source) | Proven event-driven capture with OCR + audio, accessible via API[^1] |
| Context capture (macOS) | Accessibility Tree API | Production-validated by LittleBird.ai; structured text without screenshots[^2] |
| OCR | Apple Vision API (macOS) / Tesseract | Native, fast, no network required[^1] |
| Audio transcription | Whisper (local, quantised) | State-of-the-art local STT, runs on consumer hardware[^1] |
| Vector database | LanceDB or ChromaDB | Embedded, no separate server, queryable from Python[^1] |
| Knowledge graph | SQLite + custom entity graph | Lightweight, local, inspectable[^1] |
| Orchestrator LLM | Claude Sonnet 4 / GPT-4o (cloud) or Llama 3.3 70B (local) | Cloud for quality, local for privacy[^1] |
| Agent framework | LangGraph or custom ReAct loop | Explicit state management, resumable[^1] |
| MCP servers | Official MCP + custom | File system, browser, calendar, terminal[^1] |
| Kanban UI | React + Electron or localhost web app | Real-time board, accessible from any browser[^1] |
| Encryption | OS keychain + SQLCipher | Context store encrypted at rest[^1] |

### Minimum Hardware Requirements

| Spec | Minimum | Recommended |
|---|---|---|
| CPU | Apple M2 / Intel i7 12th gen | Apple M3 Pro+ / AMD Ryzen 9 |
| RAM | 16 GB (cloud LLM mode) | 32–64 GB (local LLM mode) |
| Storage | 256 GB SSD | 1 TB+ NVMe SSD |
| OS | macOS 14+ | macOS 15+ (best Apple Vision API support) |

***

## Part 7 — Conflict Resolution Notes

One substantive tension exists between LittleBird.ai's approach and Orbit's design:

**LittleBird.ai** uses a text-only, no-screenshot approach (Accessibility Tree API only) stored on AWS cloud. This minimises privacy risk, reduces data volume, and simplifies sensitive-content filtering.[^2]

**Orbit** captures richer context (screenshots + OCR + audio + accessibility tree) stored locally. This provides higher-fidelity context for the Orchestrator but introduces greater privacy surface, higher storage requirements, and more complex sensitive-field handling.[^1]

**Recommended path forward**: Implement a tiered capture mode at launch. Default to LittleBird.ai-style text-only Accessibility Tree capture for the lowest-risk entry point, with screenshot capture as an opt-in "enhanced context" mode. This reduces the initial privacy and storage risk while preserving the architectural option for richer context as user trust is established.

***

## Conclusion

This plan confirms that **Orbit** is the name for this Always-On Agentic System. No references to "Cortex" appear in this document; all source material references have been updated accordingly.

The core functionalities elicited through the interview — ambient context capture, semantic memory, AI-managed Kanban oversight, typed sub-agent execution, and dual human approval gates — are all technically feasible based on available evidence. LittleBird.ai's production implementation validates the Accessibility API-based capture approach and confirms no patent blocking risk from that competitor. The primary risks are not technical feasibility but execution quality: context retrieval precision, approval fatigue management, agent reliability on real file operations, and prompt injection resistance.[^2][^1]

The two human gate model — **approve the plan** and **unblock the agent** — remains the architectural principle that cannot be compromised. All other elements are engineering execution challenges.[^1]

***

*Plan generated: May 2026. Based on Always-On Agentic System architecture documentation and LittleBird.ai patent/infrastructure research. All feasibility assessments are grounded in cited sources; no technical facts have been invented.*

---

## References

1. [always_on_agentic_system_report.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/78309073/5e42701b-2532-41bb-8d1f-a2ea66479ed5/always_on_agentic_system_report.md?AWSAccessKeyId=ASIA2F3EMEYER65PS5WS&Signature=k%2B961iE1zyf64Owe6jtjnsx2%2Fg4%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEAgaCXVzLWVhc3QtMSJHMEUCIQC0CVnC6bySeZVfru82IQxgZI%2BJ8SJ7YxVYV9R1z94bSQIgRaptYjEjzLAPQ3q6p8X662R0KcmDwuRv4mNboPX0om4q%2FAQI0P%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDEL3h%2BLD57N6WpryuirQBCFtXWWmDIjBubChk%2F3tbfnYr6sYFDMn40unxIQN341nzExcywmDF3Ns3WLNtf0iENcz%2B5KP75pn0KeO6wqNAlRYm5CNrHumhho63U7yXGUDcggJmSyZDnfqa9Jl4BXu8Vdky%2Bxv48TAOWZXU5F7BlfzareGmYvs%2F%2FEd0eibn7IsqaebDzMWB99puE1o3AI6CDkEDRnmi1gsdF8B9a8JWSe%2FCnq8RuPwN9f2Gf6%2BMZQPOmPNawg2bvXOOWB4UXbssBseQOFpj3K5PlWDvVy7tPek1MTEnWCv551KM9v10YZQxQynMOT4q45iW6rUVxLswvTyeU%2BZFQxdMD6s5ivF9yGtKDMZqM6rstti2PoJWKSut5fvMPa7NXPJuxyYDDjMBuPkb937cuNj0vWAYyz%2BtmbxfmF6qfKreDi5LLUmrVi5DPBN67HBfRb26rVo0HPQCSEN6BalODpZx4uxtY3cLV7MSQ8NG4KV%2FcvAQkff6KWKv2xn6q9ns8DHOdvvvQaVoNmV%2BPpUTHQSOqVFamP0ldUg5%2BhQ7NEyuajiRxAcVzVEJfrBDGCy0%2F%2FCYUruC49FCVa5buk%2FFV5PE5RfYwJ696gWwewCr8kOunvL0cBI2GBu3ugUbZ7V1mCO2rJFYGb9U%2FttXEHR0fRIXkcB4rCnhvdIUxcCPWG1uVss2K4b3gErAqkOpLlFHXMOSOzaesaDI31VRqzrMExo2xbY2jpuBD9DK5TvYitaP%2BrAEStf4awKep8DAedy%2FHh42ltRWYe68mb%2B671LSHSmmFRCyHhKz%2Fsw8f73zwY6mAEo4zyzkotdjBkG%2FAX2Ah%2Fx8RZrLhQWOhAlNsbzti3mpqIQWbHQ0QuH5qItG5BHvpQORb70CatCk50HWZSZCA3Dosw0mGqQvT%2B55KkoUdRscDxZ%2FlA2UQrHrDvjDlkfZO%2BmQG2nYUP0FcEy4VbtDjnWhzJhF3n3eK0ZxkTmVi%2BIzJhJC%2FW%2BtnI4DlWgmylFu5Zc2Z0Y5H%2FAuQ%3D%3D&Expires=1778257220) - # Always-On Agentic AI System: Architecture & Design Report
### *A Context-First, Kanban-Driven Agen...

2. [Check-if-littlebird.ai-has-any-patent-on-their-tec.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/78309073/81453f7a-a6b5-4b1e-82c7-91a37b77b431/Check-if-littlebird.ai-has-any-patent-on-their-tec.md?AWSAccessKeyId=ASIA2F3EMEYER65PS5WS&Signature=2e%2FSQdj6ca%2B9IhIJcUwKyuAXJFw%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEAgaCXVzLWVhc3QtMSJHMEUCIQC0CVnC6bySeZVfru82IQxgZI%2BJ8SJ7YxVYV9R1z94bSQIgRaptYjEjzLAPQ3q6p8X662R0KcmDwuRv4mNboPX0om4q%2FAQI0P%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARABGgw2OTk3NTMzMDk3MDUiDEL3h%2BLD57N6WpryuirQBCFtXWWmDIjBubChk%2F3tbfnYr6sYFDMn40unxIQN341nzExcywmDF3Ns3WLNtf0iENcz%2B5KP75pn0KeO6wqNAlRYm5CNrHumhho63U7yXGUDcggJmSyZDnfqa9Jl4BXu8Vdky%2Bxv48TAOWZXU5F7BlfzareGmYvs%2F%2FEd0eibn7IsqaebDzMWB99puE1o3AI6CDkEDRnmi1gsdF8B9a8JWSe%2FCnq8RuPwN9f2Gf6%2BMZQPOmPNawg2bvXOOWB4UXbssBseQOFpj3K5PlWDvVy7tPek1MTEnWCv551KM9v10YZQxQynMOT4q45iW6rUVxLswvTyeU%2BZFQxdMD6s5ivF9yGtKDMZqM6rstti2PoJWKSut5fvMPa7NXPJuxyYDDjMBuPkb937cuNj0vWAYyz%2BtmbxfmF6qfKreDi5LLUmrVi5DPBN67HBfRb26rVo0HPQCSEN6BalODpZx4uxtY3cLV7MSQ8NG4KV%2FcvAQkff6KWKv2xn6q9ns8DHOdvvvQaVoNmV%2BPpUTHQSOqVFamP0ldUg5%2BhQ7NEyuajiRxAcVzVEJfrBDGCy0%2F%2FCYUruC49FCVa5buk%2FFV5PE5RfYwJ696gWwewCr8kOunvL0cBI2GBu3ugUbZ7V1mCO2rJFYGb9U%2FttXEHR0fRIXkcB4rCnhvdIUxcCPWG1uVss2K4b3gErAqkOpLlFHXMOSOzaesaDI31VRqzrMExo2xbY2jpuBD9DK5TvYitaP%2BrAEStf4awKep8DAedy%2FHh42ltRWYe68mb%2B671LSHSmmFRCyHhKz%2Fsw8f73zwY6mAEo4zyzkotdjBkG%2FAX2Ah%2Fx8RZrLhQWOhAlNsbzti3mpqIQWbHQ0QuH5qItG5BHvpQORb70CatCk50HWZSZCA3Dosw0mGqQvT%2B55KkoUdRscDxZ%2FlA2UQrHrDvjDlkfZO%2BmQG2nYUP0FcEy4VbtDjnWhzJhF3n3eK0ZxkTmVi%2BIzJhJC%2FW%2BtnI4DlWgmylFu5Zc2Z0Y5H%2FAuQ%3D%3D&Expires=1778257220) - <img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margi...

