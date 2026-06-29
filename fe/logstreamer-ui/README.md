# LogStreamer UI

Internal React UI for operating the iOS log streamer backend locally.

## Features

- dashboard with active and recent sessions
- create-session form
- direct session search by `sessionId`
- session detail view with metadata and operator actions
- live log streaming over `EventSource`
- searchable log viewer with payload expansion

## Local run

1. Start the backend on `http://localhost:8080`
2. Install dependencies
3. Run the UI

```bash
cd fe/logstreamer-ui
npm install
npm run dev
```

The Vite dev server runs on `http://localhost:5173` and proxies `/api` and `/actuator` to the backend.

## Optional configuration

- `VITE_API_BASE_URL=http://localhost:8080`

## Direct backend calls in dev

This UI now defaults to calling the backend directly on port `8080`.

- frontend: `http://localhost:5173`
- backend API: `http://localhost:8080`

The checked-in `.env.development` pins `VITE_API_BASE_URL=http://localhost:8080`, and the backend allows CORS from `5173`.
