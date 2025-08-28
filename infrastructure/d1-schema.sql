-- D1 Database Schema for Lead Generation Arbitrage System
-- Optimized for Cloudflare D1 with horizontal scaling in mind

-- Leads table: Core lead storage
CREATE TABLE IF NOT EXISTS leads (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lead_id TEXT UNIQUE NOT NULL,
    vertical TEXT NOT NULL,
    status TEXT DEFAULT 'captured',
    
    -- Lead data
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    zip_code TEXT NOT NULL,
    
    -- Metadata
    source_url TEXT,
    landing_page TEXT,
    ip_address TEXT,
    country TEXT,
    user_agent TEXT,
    
    -- Tracking
    captured_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    distributed_at DATETIME,
    
    -- Monetization
    buyer_id TEXT,
    sale_price REAL,
    cost REAL,
    profit REAL GENERATED ALWAYS AS (sale_price - cost) STORED,
    
    -- Custom fields as JSON
    custom_data TEXT,
    
    -- Indexes for performance
    INDEX idx_vertical (vertical),
    INDEX idx_status (status),
    INDEX idx_captured_at (captured_at),
    INDEX idx_email (email)
);

-- Trends table: Track trending keywords and opportunities
CREATE TABLE IF NOT EXISTS trends (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    keyword TEXT NOT NULL,
    vertical TEXT NOT NULL,
    score REAL NOT NULL,
    search_volume INTEGER,
    competition_level TEXT,
    
    -- Timing
    detected_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME,
    
    -- Performance
    pages_generated INTEGER DEFAULT 0,
    leads_captured INTEGER DEFAULT 0,
    conversion_rate REAL,
    
    -- Status
    status TEXT DEFAULT 'active',
    
    INDEX idx_keyword (keyword),
    INDEX idx_vertical_trend (vertical),
    INDEX idx_score (score DESC),
    INDEX idx_status_trend (status)
);

-- Landing pages table: Track generated pages
CREATE TABLE IF NOT EXISTS landing_pages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    page_id TEXT UNIQUE NOT NULL,
    trend_id INTEGER,
    vertical TEXT NOT NULL,
    
    -- Page details
    url TEXT NOT NULL,
    title TEXT NOT NULL,
    headline TEXT,
    content TEXT,
    
    -- Performance metrics
    visits INTEGER DEFAULT 0,
    conversions INTEGER DEFAULT 0,
    conversion_rate REAL GENERATED ALWAYS AS (
        CASE WHEN visits > 0 THEN CAST(conversions AS REAL) / visits ELSE 0 END
    ) STORED,
    
    -- A/B testing
    variant TEXT DEFAULT 'control',
    test_group TEXT,
    
    -- Timestamps
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    published_at DATETIME,
    
    -- Status
    status TEXT DEFAULT 'draft',
    
    FOREIGN KEY (trend_id) REFERENCES trends(id),
    INDEX idx_vertical_page (vertical),
    INDEX idx_status_page (status),
    INDEX idx_conversion_rate (conversion_rate DESC)
);

-- Lead distribution table: Track where leads are sent
CREATE TABLE IF NOT EXISTS lead_distribution (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lead_id TEXT NOT NULL,
    network TEXT NOT NULL, -- 'px', 'cpalead', 'leadconduit', etc.
    
    -- Ping/Post tracking
    ping_id TEXT,
    post_id TEXT,
    ping_response TEXT,
    post_response TEXT,
    
    -- Results
    status TEXT NOT NULL, -- 'pending', 'accepted', 'rejected', 'duplicate'
    price REAL,
    buyer_name TEXT,
    
    -- Timestamps
    attempted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME,
    
    FOREIGN KEY (lead_id) REFERENCES leads(lead_id),
    INDEX idx_lead_dist (lead_id),
    INDEX idx_network (network),
    INDEX idx_status_dist (status)
);

-- Campaign performance table: Track ROI by campaign
CREATE TABLE IF NOT EXISTS campaigns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    campaign_id TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    vertical TEXT NOT NULL,
    traffic_source TEXT,
    
    -- Budget tracking
    daily_budget REAL,
    total_spent REAL DEFAULT 0,
    
    -- Performance
    impressions INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    leads INTEGER DEFAULT 0,
    revenue REAL DEFAULT 0,
    
    -- Calculated metrics
    ctr REAL GENERATED ALWAYS AS (
        CASE WHEN impressions > 0 THEN CAST(clicks AS REAL) / impressions ELSE 0 END
    ) STORED,
    cpl REAL GENERATED ALWAYS AS (
        CASE WHEN leads > 0 THEN total_spent / leads ELSE 0 END
    ) STORED,
    roi REAL GENERATED ALWAYS AS (
        CASE WHEN total_spent > 0 THEN ((revenue - total_spent) / total_spent) * 100 ELSE 0 END
    ) STORED,
    
    -- Status
    status TEXT DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_vertical_campaign (vertical),
    INDEX idx_status_campaign (status),
    INDEX idx_roi (roi DESC)
);

-- API logs table: Track all API interactions
CREATE TABLE IF NOT EXISTS api_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    request_id TEXT UNIQUE NOT NULL,
    endpoint TEXT NOT NULL,
    method TEXT NOT NULL,
    
    -- Request/Response
    request_body TEXT,
    response_body TEXT,
    status_code INTEGER,
    
    -- Metadata
    ip_address TEXT,
    user_agent TEXT,
    duration_ms INTEGER,
    
    -- Timestamps
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_endpoint (endpoint),
    INDEX idx_created_at_log (created_at DESC)
);

-- Create views for common queries
CREATE VIEW IF NOT EXISTS daily_performance AS
SELECT 
    DATE(captured_at) as date,
    vertical,
    COUNT(*) as leads_captured,
    SUM(sale_price) as revenue,
    SUM(cost) as costs,
    SUM(profit) as profit,
    AVG(sale_price) as avg_sale_price
FROM leads
WHERE status = 'sold'
GROUP BY DATE(captured_at), vertical;

CREATE VIEW IF NOT EXISTS top_converting_pages AS
SELECT 
    page_id,
    url,
    vertical,
    visits,
    conversions,
    conversion_rate
FROM landing_pages
WHERE status = 'published' AND visits > 100
ORDER BY conversion_rate DESC
LIMIT 20;

CREATE VIEW IF NOT EXISTS trend_performance AS
SELECT 
    t.keyword,
    t.vertical,
    t.score,
    COUNT(DISTINCT lp.id) as pages_created,
    SUM(lp.conversions) as total_conversions,
    AVG(lp.conversion_rate) as avg_conversion_rate
FROM trends t
LEFT JOIN landing_pages lp ON t.id = lp.trend_id
WHERE t.status = 'active'
GROUP BY t.id
ORDER BY total_conversions DESC;