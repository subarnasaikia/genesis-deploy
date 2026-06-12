# Frontend — Architecture

The Genesis frontend is a **Next.js 15** application (App Router, React 19,
TypeScript) managed with **pnpm** and styled with **Tailwind CSS v4** on top
of shadcn/ui components.

## Application structure

The codebase is organised by **feature**, not by technical layer:

```
src/
├── app/                    # routes only — thin pages that compose features
│   ├── (auth)/             #   /login, /signup        (public route group)
│   ├── (app)/              #   /home, /workspace/[id], /workspace/[id]/editor
│   └── api/                #   small route handlers (auth session, export)
├── features/               # one folder per domain feature
│   ├── auth/
│   ├── workspace/
│   ├── document/
│   ├── editor/
│   │   ├── core/           #   shared editor plumbing (session, pagination)
│   │   ├── coref/ ner/ pos/ wsd/   # one sub-feature per annotation type
│   ├── notifications/
│   ├── recommendations/
│   └── home/
├── server/                 # server-only HTTP client, cookies, error mapping
├── config/env.ts           # validated environment access
└── lib/                    # constants, fonts, generic utilities
```

Each feature folder follows the same convention:

| File | Role |
|---|---|
| `*.contracts.ts` | TypeScript types mirroring the backend DTOs |
| `*.gateway.ts` | Server-side fetch calls to the backend API |
| `*.actions.ts` | Next.js Server Actions — the only way client components mutate data |
| `components/` | React components for the feature |

## Data flow

```
Client component
  → Server Action (features/<x>/<x>.actions.ts)
    → Gateway (features/<x>/<x>.gateway.ts)
      → src/server/http.ts        (attaches auth, base URL, error mapping)
        → Backend REST API
```

Client components never call the backend directly; everything goes through
server actions and gateways running on the Next.js server. This keeps
tokens out of browser JavaScript and gives one place to handle errors and
auth.

## Authentication

- Tokens are held in **HTTP-only cookies** managed server-side
  (`src/server/cookies.ts`); browser code never sees them.
- `src/middleware.ts` (Edge runtime) guards the `(app)` route group and
  redirects unauthenticated visitors to `/login`.
- An auth provider (`features/auth/auth.provider.tsx`) exposes the current
  user to client components.

## Editor architecture

The editor route (`/workspace/[id]/editor`) renders a different editor
component based on the workspace's annotation type — `CorefEditor`,
`NerEditor`, `PosEditor`, or `WsdEditor` — dispatched by
`features/editor/dispatch.tsx`. Shared concerns live in
`features/editor/core/`:

- `useEditorSession` — persists scroll/selection state to the backend so
  annotators resume where they left off;
- `usePaginatedDocument` — lazy-loads token pages for large documents;
- shared components (document switcher, help panel, load-more,
  disagreement indicators).

Adding a new annotation type means adding one sub-folder under
`features/editor/` with its own contracts/gateway/actions/components and a
case in the dispatcher — no changes to existing editors.

## Configuration

| Variable | Purpose |
|---|---|
| `NEXT_PUBLIC_API_URL` | Backend base URL as seen from the browser. **Required in production builds** — the build fails without it. Inlined at build time, so changing it requires a rebuild. |

Server Actions accept request bodies up to 25 MB (configured in
`next.config.ts`) to accommodate real annotation corpora uploads; keep this
in sync with the backend's multipart limit.

## Build & runtime

- `pnpm build` produces a **standalone** output (`output: 'standalone'` in
  `next.config.ts`) — a self-contained `server.js` plus static assets,
  designed for slim Docker images.
- The repo ships a multi-stage `Dockerfile` (pnpm install → build → non-root
  Node 22 Alpine runner) listening on port 3000.
