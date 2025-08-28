// Cloudflare Worker for S3-compatible lead storage
// Deploy this as a Cloudflare Worker and set your environment variables

export default {
  async fetch(request, env) {
    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Only accept POST requests
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { 
        status: 405,
        headers: corsHeaders 
      });
    }

    try {
      const body = await request.json();
      
      // Validate lead data
      if (!body.vertical || !body.email || !body.zipCode) {
        return new Response(JSON.stringify({ 
          error: 'Missing required fields' 
        }), { 
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Generate filename
      const timestamp = new Date().toISOString();
      const date = timestamp.split('T')[0];
      const leadId = `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      const fileName = `leads/${body.vertical}/${date}/${leadId}.json`;

      // Add metadata
      const leadData = {
        ...body,
        leadId,
        timestamp,
        source: new URL(request.headers.get('Referer') || request.url).hostname,
        ip: request.headers.get('CF-Connecting-IP'),
        country: request.headers.get('CF-IPCountry'),
      };

      // Option 1: Use Cloudflare R2 (S3-compatible)
      if (env.R2_BUCKET) {
        const object = await env.R2_BUCKET.put(fileName, JSON.stringify(leadData, null, 2), {
          httpMetadata: {
            contentType: 'application/json',
          },
          customMetadata: {
            vertical: body.vertical,
            source: leadData.source,
          },
        });

        return new Response(JSON.stringify({ 
          success: true,
          leadId,
          message: 'Lead stored successfully'
        }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Option 2: Use AWS S3 or compatible service
      if (env.S3_ENDPOINT && env.S3_ACCESS_KEY && env.S3_SECRET_KEY) {
        const s3Url = `${env.S3_ENDPOINT}/${env.S3_BUCKET}/${fileName}`;
        
        // Create AWS Signature v4 (simplified version)
        const dateStamp = new Date().toISOString().slice(0, 10).replace(/-/g, '');
        const amzDate = new Date().toISOString().replace(/[:-]|\.\d{3}/g, '');
        
        const response = await fetch(s3Url, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
            'x-amz-date': amzDate,
            // Add proper AWS signature headers here
            // For production, use @aws-sdk/signature-v4 or similar
          },
          body: JSON.stringify(leadData, null, 2),
        });

        if (response.ok) {
          return new Response(JSON.stringify({ 
            success: true,
            leadId,
            message: 'Lead stored successfully'
          }), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }
      }

      // Option 3: Fallback to KV storage
      if (env.LEADS_KV) {
        await env.LEADS_KV.put(
          `lead_${leadId}`,
          JSON.stringify(leadData),
          {
            expirationTtl: 60 * 60 * 24 * 90, // 90 days
            metadata: {
              vertical: body.vertical,
              timestamp: timestamp,
            },
          }
        );

        return new Response(JSON.stringify({ 
          success: true,
          leadId,
          message: 'Lead stored successfully in KV'
        }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // No storage configured
      return new Response(JSON.stringify({ 
        error: 'No storage backend configured' 
      }), { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });

    } catch (error) {
      console.error('Error processing lead:', error);
      return new Response(JSON.stringify({ 
        error: 'Failed to process lead' 
      }), { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
  },
};