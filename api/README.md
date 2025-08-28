# Lead Storage API Setup

This Cloudflare Worker stores lead data in S3-compatible storage (Cloudflare R2, AWS S3, etc.)

## Setup Instructions

### Option 1: Cloudflare R2 (Recommended - S3-compatible, no egress fees)

1. Create an R2 bucket:
```bash
wrangler r2 bucket create lead-storage
```

2. Deploy the Worker:
```bash
cd api
wrangler deploy --env production
```

3. Set up a custom domain (optional):
```bash
# Add DNS record in Cloudflare Dashboard
# Type: CNAME
# Name: api.lead
# Target: lead-storage-api.workers.dev
```

### Option 2: AWS S3

1. Create an S3 bucket in AWS Console

2. Set Worker secrets:
```bash
wrangler secret put S3_ACCESS_KEY
wrangler secret put S3_SECRET_KEY
```

3. Update wrangler.toml with your S3 details

4. Deploy:
```bash
wrangler deploy --env production
```

### Option 3: Cloudflare KV (Simple key-value storage)

1. Create a KV namespace:
```bash
wrangler kv:namespace create "LEADS_KV"
```

2. Update the namespace ID in wrangler.toml

3. Deploy:
```bash
wrangler deploy --env production
```

## Testing

Test the API endpoint:
```bash
curl -X POST https://api.lead.dwellingdb.com/store-lead \
  -H "Content-Type: application/json" \
  -d '{
    "vertical": "insurance",
    "firstName": "Test",
    "lastName": "User",
    "email": "test@example.com",
    "phone": "5555555555",
    "zipCode": "90100"
  }'
```

## Viewing Stored Leads

### For R2:
```bash
# List all leads
wrangler r2 object list lead-storage --prefix leads/

# Download a specific lead
wrangler r2 object get lead-storage/leads/insurance/2024-01-01/lead_123.json
```

### For S3:
```bash
# Using AWS CLI
aws s3 ls s3://your-bucket/leads/
aws s3 cp s3://your-bucket/leads/insurance/2024-01-01/lead_123.json -
```

### For KV:
```bash
# List keys
wrangler kv:key list --namespace-id=YOUR_NAMESPACE_ID

# Get a specific lead
wrangler kv:key get --namespace-id=YOUR_NAMESPACE_ID "lead_123"
```

## Lead Data Structure

Each lead is stored as JSON with the following structure:
```json
{
  "leadId": "1234567890_abc123",
  "timestamp": "2024-01-01T12:00:00Z",
  "vertical": "insurance",
  "firstName": "John",
  "lastName": "Doe",
  "email": "john@example.com",
  "phone": "5555555555",
  "zipCode": "90100",
  "pageUrl": "https://lead.dwellingdb.com/insurance/",
  "source": "lead.dwellingdb.com",
  "ip": "192.168.1.1",
  "country": "US"
}
```

## Security Notes

- Never expose S3 credentials in client-side code
- Use the Worker as a proxy to keep credentials secure
- Enable CORS only for your domain
- Consider rate limiting for production use
- Implement CAPTCHA for bot protection if needed