# Backend panel walkthrough

Use 45 minutes. Spend 18 minutes presenting, 12 on trade-offs, 10 on deferred work, and 5 on your questions.

## Presentation · 18 minutes

1. **Architecture and domain — 5 minutes.** Show the two services and SQLite databases. Explain `User`, `Role`, `Claim`, `ClaimMessage`, `ClaimHistory`, and the outbox. Show the claim version and transaction boundary. Identify the source milestones reused from Fullstack.
2. **API demo — 8 minutes.** Run `scripts/demo-lifecycle.ps1` and show both Swagger contracts. Explain the queue, owner visibility, competing acceptance conflict, request for information, reply, approval and separate settlement. Open the rejection example and its reason. Show the four Kafka notices and the aggregate report.
3. **Read and write paths — 3 minutes.** Show how list queries scope and page results, how reporting aggregates open exposure by currency, and how the write transaction commits the state, audit entry, and outbox event.
4. **Verification and AI — 2 minutes.** Open the Git log and journal. Discuss how you directed the domain modeling, challenged the design, and verified access, concurrent updates, and replay.

## Trade-offs · 12 minutes

Explain why claim decisions use REST and why Kafka is outside that request path. Discuss the failure window between publishing and marking the outbox entry and why the consumer deduplicates by event ID. Explain why approval leaves exposure open until settlement and why claims with missing estimates are counted separately.

## Deferred work · 10 minutes

Discuss production identity, service-level observability, deployment and disaster recovery, evidence storage, and market-specific policy and payment integrations. Explain how a payment integration would change the settlement transition and reconciliation model.

## Your questions · 5 minutes

Ask about Chubb’s workload metrics, exposure definition, and the production practices the team uses to review AI-generated code.
