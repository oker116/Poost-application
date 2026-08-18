# API Contract Blueprint

## Auth
POST /auth/login
POST /auth/logout
POST /auth/refresh

## Meta
POST /meta/oauth/start
GET  /meta/oauth/callback
GET  /meta/ad-accounts
POST /meta/ad-accounts/select
POST /meta/sync
GET  /meta/sync/status

## Clients
GET  /clients
POST /clients
GET  /clients/:id
PATCH /clients/:id
DELETE /clients/:id

## Performance
GET /clients/:id/metrics?from=YYYY-MM-DD&to=YYYY-MM-DD
GET /clients/:id/campaigns
GET /clients/:id/creatives
GET /clients/:id/monthly

## Finance
GET /finance/commissions
POST /finance/commissions/:id/payment
GET /finance/summary

## Reports
GET /reports/agency?month=YYYY-MM
GET /reports/client/:id?month=YYYY-MM
POST /reports/:id/generate

## AI
POST /ai/analyze/client/:id
POST /ai/analyze/agency

## Notifications
GET /alerts
POST /alerts/:id/resolve

All production endpoints must enforce authorization server-side.
