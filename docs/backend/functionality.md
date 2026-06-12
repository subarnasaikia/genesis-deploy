# Backend — Functionality

What the Genesis API actually does, feature by feature. All endpoints return
the standard `{ success, data, message }` envelope and (except auth) require
a valid JWT access token.

## Accounts & authentication

- Sign-up with email and password; passwords are stored hashed.
- Login issues a short-lived **access token** and a longer-lived **refresh
  token**; refreshing rotates the refresh token so a stolen one is only
  usable once.
- Logout invalidates the session server-side.

## Workspaces

A workspace is the unit of collaboration. Each workspace:

- has a fixed **annotation type** chosen at creation — `COREF`, `NER`, `POS`,
  or `WSD` — which determines the editor the frontend renders and the
  annotation endpoints that apply;
- has an **owner** and **members** with roles that gate who can manage
  members, upload documents, and annotate;
- contains any number of **documents**.

## Documents & tokenization

- Documents are uploaded as plain text (TXT) or pre-annotated CoNLL-2012.
- On upload, the backend stores the raw file, then tokenises the content
  into sentences and tokens (with global and per-sentence indices) so that
  annotations can reference exact token spans.
- Large documents are served to the editor in pages (keyset pagination) so
  the UI can lazy-load instead of fetching the whole corpus at once.

## Annotation

Each annotation type has its own module and endpoints, all operating on
token spans:

- **Coreference** — create mentions over token ranges, group mentions into
  clusters, merge clusters, delete mentions/clusters.
- **NER** — label token spans with entity types.
- **POS** — assign part-of-speech tags per token; supports custom tag sets
  per workspace and CSV import of tags.
- **WSD** — maintain sense inventories and assign senses to ambiguous
  tokens.

Annotations are per-user where the workflow requires comparing annotators
(disagreement views), with editor sessions persisted server-side so an
annotator can resume exactly where they stopped.

## Recommendations

A rule-based recommender suggests likely annotations (e.g. candidate
mentions) which annotators can accept or dismiss; dismissals are remembered
per user.

## Notifications

Cross-module events (document uploaded and tokenized, member added, etc.)
generate in-app notifications for the affected users, delivered through a
polling endpoint and shown by the frontend's notification dropdown.

## Import / export

- **Import**: TXT (tokenised on upload) and CoNLL-2012 (tokens + existing
  annotations preserved).
- **Export**: workspace or document annotations as CoNLL-2012 and CSV
  (POS), suitable for downstream NLP pipelines.

## Health & observability

- `/actuator/health` aggregates per-module health indicators plus the
  database connection.
- Prometheus-format metrics at `/actuator/prometheus` in prod.
- Structured request logging with a rolling file in prod.
