# poost Media Buying OS — Complete Product Specification

## Product
Android-first media buying agency operating system for owners and media buyers.

## Core business rules
- Spend commission = Ad Spend × 20%
- Sales commission = Sales × 10%
- Total commission = Spend commission + Sales commission
- ROAS = Sales ÷ Ad Spend
- CPA = Ad Spend ÷ Orders (or Leads, depending on configured objective)
- AOV = Sales ÷ Orders
- Gross contribution = Sales - Ad Spend - other configured costs
- Month-over-month growth = (Current - Previous) ÷ Previous × 100

## Roles
### Owner
- Full agency visibility
- Manage users
- Manage clients
- Manage Meta connections
- Financial visibility
- Reports
### Media Buyer
- Assigned clients only
- Campaign performance
- Notes/tasks
- No other buyers' private data
### Client
- Own company only
- Performance and approved reports
- No commission/internal notes/other clients

## Main modules
1. Authentication
2. Command Center
3. Clients
4. Client profile
5. Campaigns
6. Ad Sets
7. Ads
8. Creative Library
9. Daily/weekly/monthly performance
10. Finance & commissions
11. Monthly snapshots
12. Alerts
13. AI Analyst
14. Reports/PDF
15. Client Portal
16. Meta Ads Connections
17. Users & permissions
18. Settings
19. Audit Log

## Dashboard KPIs
- Active clients
- Managed ad spend
- Sales
- Total commission
- Portfolio ROAS
- Portfolio CPA
- Orders
- Agency health
- MoM growth
- Forecast

## Client health
Health combines configurable signals:
- ROAS trend
- CPA trend
- spend pacing
- sales trend
- tracking/data freshness
- creative fatigue
- manual risk flag

The score is advisory, not a financial guarantee.

## Meta connection architecture
Production:
1. User selects Connect Meta.
2. Backend starts OAuth.
3. Meta grants access.
4. Backend stores encrypted/secured credentials.
5. User selects authorized ad accounts.
6. Accounts are mapped to clients.
7. Sync jobs fetch campaigns/ad sets/ads/insights.
8. Dashboard consumes normalized metrics.

Never hard-code long-lived secrets in the APK.

## Sync
Recommended:
- Initial historical sync
- Incremental daily sync
- Retry with exponential backoff
- Idempotent upserts
- Last successful sync timestamp
- Error state and human-readable message

## Sales integration
Keep sales source-agnostic:
- orders
- revenue
- refunds
- date
- currency
- order identifier
- attribution metadata where available

## Reports
Owner report:
- agency summary
- client ranking
- revenue/commission
- risk accounts
- growth

Client report:
- spend
- sales
- ROAS
- orders
- CPA
- AOV
- top campaigns
- recommendations
- month comparison

## Notifications
- low ROAS
- CPA spike
- sales drop
- budget pacing anomaly
- sync failure
- tracking freshness
- client report ready

## Security
- OAuth instead of collecting permanent tokens in the UI
- Backend authorization
- row-level tenant isolation
- encrypted secrets
- audit logs
- least privilege
- no secrets in source control
- no secrets in APK
