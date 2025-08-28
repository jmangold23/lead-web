#!/bin/bash

# Cloudflare Lead Arbitrage System Deployment Script
# Run this to set up your entire infrastructure

echo "🚀 Deploying Lead Generation Arbitrage System on Cloudflare"
echo "============================================"

# Check if wrangler is installed
if ! command -v wrangler &> /dev/null; then
    echo "❌ Wrangler CLI not found. Installing..."
    npm install -g wrangler
fi

# Login to Cloudflare
echo "📝 Logging into Cloudflare..."
wrangler login

# Create D1 Database
echo "🗄️ Creating D1 database..."
wrangler d1 create lead-arbitrage-db

# Get the database ID from output and update wrangler.toml
echo "⚠️  Please update the database_id in wrangler.toml with the ID shown above"
read -p "Press enter when you've updated wrangler.toml..."

# Apply database schema
echo "📊 Applying database schema..."
wrangler d1 execute lead-arbitrage-db --file=d1-schema.sql

# Create KV namespaces
echo "🔑 Creating KV namespaces..."
wrangler kv:namespace create "TREND_CACHE"
wrangler kv:namespace create "REPORTS_KV"

echo "⚠️  Please update the KV namespace IDs in wrangler.toml"
read -p "Press enter when you've updated wrangler.toml..."

# Create R2 buckets
echo "📦 Creating R2 buckets..."
wrangler r2 bucket create landing-pages
wrangler r2 bucket create lead-storage

# Set up secrets
echo "🔐 Setting up API secrets..."
echo "Enter your OpenAI API key:"
read -s OPENAI_KEY
wrangler secret put OPENAI_API_KEY --env production <<< "$OPENAI_KEY"

echo "Enter your PX API key (or press enter to skip):"
read -s PX_KEY
if [ ! -z "$PX_KEY" ]; then
    wrangler secret put PX_API_KEY --env production <<< "$PX_KEY"
fi

echo "Enter your LeadConduit API key (or press enter to skip):"
read -s LEADCONDUIT_KEY
if [ ! -z "$LEADCONDUIT_KEY" ]; then
    wrangler secret put LEADCONDUIT_API_KEY --env production <<< "$LEADCONDUIT_KEY"
fi

# Deploy the Worker
echo "🚀 Deploying Worker..."
wrangler deploy --env production

# Set up custom domain
echo "🌐 Setting up custom domain..."
echo "Add this DNS record in Cloudflare Dashboard:"
echo "  Type: CNAME"
echo "  Name: api.lead"
echo "  Target: lead-arbitrage-system.workers.dev"
echo ""

# Test the deployment
echo "✅ Testing deployment..."
WORKER_URL=$(wrangler deployments list | grep -oP 'https://[^\s]+' | head -1)
curl -s "$WORKER_URL/api/analytics/dashboard" | jq '.'

echo ""
echo "✨ Deployment Complete!"
echo "========================"
echo "Worker URL: $WORKER_URL"
echo "Dashboard: $WORKER_URL/api/analytics/dashboard"
echo ""
echo "Next steps:"
echo "1. Update the API_ENDPOINT in _layouts/landing.html to: $WORKER_URL/api/leads/process"
echo "2. Visit https://lead.dwellingdb.com to test lead capture"
echo "3. Monitor performance at: $WORKER_URL/api/analytics/dashboard"
echo ""
echo "Monthly cost estimate: $5-15 (Workers Paid plan)"