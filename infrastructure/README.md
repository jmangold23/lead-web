# Lead Generation Arbitrage System - Cloudflare Infrastructure

Complete infrastructure for running a LangGraph-based lead generation arbitrage system on Cloudflare's platform.

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   Cloudflare Edge                    │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │   Workers    │  │      D1      │  │    KV    │ │
│  │  (LangGraph) │  │  (Lead DB)   │  │ (Cache)  │ │
│  └──────────────┘  └──────────────┘  └──────────┘ │
│                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │      R2      │  │   Durable    │  │   Pages  │ │
│  │  (Storage)   │  │   Objects    │  │  (Site)  │ │
│  └──────────────┘  └──────────────┘  └──────────┘ │
└─────────────────────────────────────────────────────┘
```

## Quick Start

1. **Run the deployment script:**
```bash
cd infrastructure
chmod +x deploy.sh
./deploy.sh
```

2. **Manual setup (if preferred):**
```bash
# Create D1 database
wrangler d1 create lead-arbitrage-db
wrangler d1 execute lead-arbitrage-db --file=d1-schema.sql

# Create KV namespaces  
wrangler kv:namespace create "TREND_CACHE"
wrangler kv:namespace create "REPORTS_KV"

# Create R2 buckets
wrangler r2 bucket create landing-pages
wrangler r2 bucket create lead-storage

# Deploy Worker
wrangler deploy --env production
```

## Cost Breakdown

### Monthly Costs (at scale):
- **Workers Paid Plan**: $5/month base
- **D1 Database**: 
  - 5GB storage included
  - 25M reads/month included
  - 50K writes/month included
- **KV Storage**: 
  - 1GB storage included
  - 10M reads/month included
  - 1M writes/month included
- **R2 Storage**:
  - 10GB storage included
  - No egress fees

**Total: $5-15/month** for most use cases

## API Endpoints

### Agent Orchestration
- `POST /api/agent/execute` - Execute LangGraph agents
- `POST /api/trends/detect` - Detect trending keywords
- `POST /api/pages/generate` - Generate landing pages
- `POST /api/leads/process` - Process captured leads
- `POST /api/leads/distribute` - Distribute leads to buyers

### Analytics
- `GET /api/analytics/dashboard` - Real-time dashboard

## LangGraph Agents

### 1. Trend Detector Agent
Monitors multiple sources for trending keywords:
```javascript
const detector = new TrendDetectorAgent(env);
await detector.execute({});
// Returns: { trends: [...], count: 10 }
```

### 2. Page Generator Agent  
Creates optimized landing pages using AI:
```javascript
const generator = new PageGeneratorAgent(env);
await generator.execute({ 
  trend: { keyword: 'solar panels', vertical: 'solar' }
});
// Returns: { pageId: 'uuid', url: 'https://...' }
```

### 3. Lead Router Agent
Distributes leads to highest bidder:
```javascript
const router = new LeadRouterAgent(env);
await router.execute({ leadId: 'lead_123' });
// Returns: { status: 'accepted', price: 85.50, network: 'px' }
```

### 4. Revenue Optimizer Agent
Continuously optimizes for maximum ROI:
```javascript
const optimizer = new RevenueOptimizerAgent(env);
await optimizer.execute({});
// Returns: { metrics: {...}, opportunities: [...], actions: [...] }
```

## Database Schema

The D1 database includes:
- `leads` - Core lead storage with profit tracking
- `trends` - Trending keywords and performance
- `landing_pages` - Generated pages with conversion metrics
- `lead_distribution` - Lead routing history
- `campaigns` - Campaign performance and ROI
- `api_logs` - Complete audit trail

## Scheduled Tasks

Automated via Cron Triggers:
- **Every 30 minutes**: Detect new trends
- **Every 6 hours**: Optimize campaigns
- **Daily at 2 AM**: Generate performance reports

## Performance Metrics

Track these KPIs in the dashboard:
- Lead Quality Score (target: >60)
- Conversion Rate (target: >2%)
- Cost Per Lead (target: <$10 insurance, <$15 solar)
- Distribution Rate (target: >80%)
- ROI (target: >200%)

## Security Best Practices

1. **API Keys**: Store as secrets, never in code
2. **CORS**: Restrict to your domain only
3. **Rate Limiting**: Implement via Cloudflare rules
4. **Data Privacy**: TCPA compliant consent tracking
5. **Audit Logs**: All actions logged in D1

## Monitoring

View real-time metrics:
```bash
# Dashboard
curl https://api.lead.dwellingdb.com/api/analytics/dashboard

# Logs
wrangler tail --env production

# D1 queries
wrangler d1 execute lead-arbitrage-db --command "SELECT * FROM daily_performance"
```

## Scaling Guide

### Month 1-3 (Startup)
- 100-500 leads/month
- Cost: $5-7/month
- Focus: Testing and optimization

### Month 4-6 (Growth)
- 500-2000 leads/month  
- Cost: $10-20/month
- Focus: Scale profitable verticals

### Month 7+ (Scale)
- 2000+ leads/month
- Cost: $20-50/month
- Focus: Multi-vertical expansion

## Troubleshooting

### Common Issues:

**Worker timeout**: Increase CPU limit in wrangler.toml
```toml
[limits]
cpu_ms = 100  # Increase from 50ms
```

**D1 query slow**: Add indexes for frequently queried columns
```sql
CREATE INDEX idx_email ON leads(email);
```

**KV cache miss**: Increase TTL for frequently accessed data
```javascript
await env.TREND_CACHE.put(key, value, { expirationTtl: 7200 });
```

## Support

- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [D1 Documentation](https://developers.cloudflare.com/d1/)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/)

## License

This infrastructure code is provided as-is for educational purposes.