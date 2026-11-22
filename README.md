# Chubb Backend Assessment

Two .NET 10 services implement the claims lifecycle and claimant notifications. This backend-only submission reuses the verified backend from the [Fullstack assessment](https://github.com/Vijay-Kanna/Chubb_Assesment-FSD). The import commits name their source revisions. The API-only demo and documentation are specific to this submission.

## Run locally

Use PowerShell 7, the .NET 10 SDK, and Docker Compose. From the repository root:

```powershell
dotnet dev-certs https --trust
docker compose up -d --wait
$env:Kafka__BootstrapServers = '127.0.0.1:9092'
$env:Jwt__SigningKey = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$env:Demo__Password = [guid]::NewGuid().ToString('N')
dotnet run --project backend/Claims.Api
```

In a second PowerShell terminal, set `Kafka__BootstrapServers` and `Jwt__SigningKey` to the same values and run `dotnet run --project backend/Notifications.Api`. The APIs start on ports 7164 and 7165 and the broker on 9092. If you already run the Fullstack demo, free the API ports before starting these services. Reuse a broker already listening on 9092 or stop its Compose project before starting another. To isolate notification streams when reusing Kafka, set the same `Kafka__Topic` on both APIs and a separate `Kafka__GroupId` for the consumer.

On Windows with several localhost certificates, if the API starts with an untrusted certificate, set the following on both API terminals before restarting:

```powershell
$env:Kestrel__Certificates__Default__Subject = 'localhost'
$env:Kestrel__Certificates__Default__Store = 'My'
$env:Kestrel__Certificates__Default__Location = 'CurrentUser'
```

SQLite migrations run at startup. Set `ConnectionStrings__Claims` and `ConnectionStrings__Notifications` for separate databases. For local demos, the Claims API creates accounts in Development from the supplied password. Swagger and the demo use bearer tokens. No keys or real claim data are required or checked in.

## Demo and verification

Set `Demo__Password` in the terminal running the scripts to the same value as the Claims API:

```powershell
.\scripts\demo-lifecycle.ps1
.\scripts\seed-demo-claims.ps1
$env:KAFKA_TEST_BOOTSTRAP_SERVERS = '127.0.0.1:9092'
dotnet test
```

The first script submits two fictional claims, verifies owner isolation and a competing staff acceptance, runs the question/reply and approval/settlement sequence, rejects the second claim with a reason, and checks reporting and four notifications. The second script adds ten repeatable demo claims. The integration suite covers validation, authorization, concurrency, session restoration, Kafka delivery and replay, and SignalR notifications.

- [Claims Swagger](https://localhost:7164/swagger/) — use `POST /auth/login` with `staff@example.test` or `claimant@example.test` and authorize with the returned token.
- [Notifications Swagger](https://localhost:7165/swagger/) — authorize with a claimant token.
- `GET /claims?status=Submitted&page=1&pageSize=10` lists available work for staff. `GET /reports/overview?days=30` shows current workload, exposure by currency, and staff decisions. Pass inclusive UTC `startDate` and `endDate` to report on a submission cohort.

## Service design

The Claims API owns users, roles, claim status, message threads, audit history, and the notification outbox. A transition, the related audit change, and any queued event share a database transaction. REST returns immediate success, validation, or conflict. The EF Core claim version ensures only one staff member can take a submitted claim. Claim and message access is scoped to the owner and authorized staff.

Kafka carries event identifiers, recipient, event type, and timestamp. The Notifications API saves each notice in its own database before committing the offset and uses the event ID to deduplicate replay. Reporting queries scope and aggregate claims in SQLite. Requested and approved amounts and estimated exposure are separate measures. The exposure report excludes rejected and settled claims and groups currency totals without conversion.

Deferred scope includes real payment and policy integrations, evidence storage, production identity, market-specific routing, and production deployment and operations. Settlement records claim resolution in the workflow. See the [AI journal](AI-JOURNAL.md) and [panel walkthrough](PANEL-WALKTHROUGH.md).
