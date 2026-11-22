# AI working journal — Backend

I told Codex the recruiter requires the individual Frontend and Backend submissions in addition to Fullstack. I requested separate folders and asked Codex to do them one at a time with meaningful commits. Codex completed Frontend first, then scoped the Backend repo to the .NET services, Kafka configuration, tests, and scripts.

## Design provenance

I previously challenged the initial design because it did not specify the domain model. I asked for one user model with roles, a claim status and review workflow, and claim history. I clarified that questions and replies should be a readable conversation, with audit history separate. The [Fullstack AI journal](https://github.com/Vijay-Kanna/Chubb_Assesment-FSD/blob/main/AI-JOURNAL.md) records those prompts, the approved two-service design, and the original implementation milestones.

Codex reused the original backend milestones and recorded their source hashes on the import commits. It kept REST synchronous for assignment and decisions, and Kafka asynchronous for notifications. It adapted the presentation to Swagger and an API-only workflow script, because the Backend brief puts Angular outside scope. The script checks results rather than relying on manual inspection of responses.

## Verification

Codex started both APIs against new SQLite databases and a dedicated Kafka topic on the local broker. It verified both Swagger contracts and ran all 15 integration tests with Kafka enabled. During the API demo, it found that PowerShell wrapped JSON arrays as a single item in an array subexpression. It corrected the script and verified the resulting message and history counts, workload and exposure, the two decision paths, and four claimant-only Kafka notices. The seed script created ten samples and reused them on rerun.
