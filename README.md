# AI UGC Generator

Transform TikTok videos by replacing people with AI-generated characters using Kling Motion Control.

## Features

- 🎬 **Download TikTok videos** without watermark
- 🔍 **Auto-detect UGC segments** where a person is visible
- ✂️ **Cut segments** and handle short clips (auto-loop for minimum duration)
- 🎨 **Generate AI characters** using Google Gemini
- 🧹 **Remove watermarks** from generated images
- 🎥 **Create AI videos** using Kling V2.6 Pro Motion Control
- 📊 **Real-time progress** with logs and status updates

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    React Frontend                            │
│  (Dashboard, Job Details, Characters, Settings)             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                 Supabase Backend                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  PostgreSQL │  │   Storage   │  │  Realtime   │         │
│  │  (jobs,     │  │  (videos,   │  │  (live      │         │
│  │  segments,  │  │   images,   │  │   updates)  │         │
│  │  logs)      │  │   frames)   │  │             │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│               Supabase Edge Functions                        │
│  ┌──────────────────┐  ┌──────────────────┐                 │
│  │ download-tiktok  │  │  analyze-video   │                 │
│  │ (tikwm.com API)  │  │  (WaveSpeed)     │                 │
│  └──────────────────┘  └──────────────────┘                 │
│  ┌──────────────────┐  ┌──────────────────┐                 │
│  │generate-ai-char  │  │  generate-video  │                 │
│  │(Gemini+WaveSpeed)│  │ (Kling Motion)   │                 │
│  └──────────────────┘  └──────────────────┘                 │
│  ┌──────────────────┐                                       │
│  │ process-pipeline │ (orchestrator)                        │
│  └──────────────────┘                                       │
└─────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   External APIs                              │
│  • tikwm.com (TikTok download, free)                        │
│  • Google Gemini (image generation, free tier)              │
│  • WaveSpeed (Molmo2, watermark removal, Kling)             │
└─────────────────────────────────────────────────────────────┘
```

## Cost Breakdown

| Step | API | Cost |
|------|-----|------|
| TikTok Download | tikwm.com | Free |
| Video Analysis | WaveSpeed Molmo2 | ~$0.005 |
| Character Generation | Google Gemini | Free tier |
| Watermark Removal | WaveSpeed | $0.015 |
| Motion Control Video | Kling V2.6 Pro | $0.336 |
| **Total per segment** | | **~$0.36** |

For a TikTok with 4 UGC segments: **~$1.44**

## Deployment Guide

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Copy your project URL and anon key

### 2. Run Database Schema

1. Go to SQL Editor in Supabase dashboard
2. Copy contents of `supabase/schema.sql`
3. Run the SQL to create tables, policies, and storage buckets

### 3. Deploy Edge Functions

```bash
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login

# Link your project
supabase link --project-ref your-project-ref

# Deploy all functions
supabase functions deploy download-tiktok
supabase functions deploy analyze-video
supabase functions deploy generate-ai-character
supabase functions deploy generate-video
supabase functions deploy process-pipeline
```

### 4. Add API Keys as Secrets

```bash
# Add WaveSpeed API key
supabase secrets set WAVESPEED_API_KEY=your-wavespeed-key

# Add Gemini API key
supabase secrets set GEMINI_API_KEY=your-gemini-key
```

Or via Supabase Dashboard:
1. Go to Edge Functions → Secrets
2. Add `WAVESPEED_API_KEY` 
3. Add `GEMINI_API_KEY`

### 5. Deploy Frontend

#### Option A: Deploy to Vercel

```bash
# Install dependencies
npm install

# Build
npm run build

# Deploy to Vercel
npx vercel
```

#### Option B: Deploy to Netlify

```bash
npm run build
# Upload dist/ folder to Netlify
```

#### Option C: Use with Lovable

1. Create new Lovable project
2. Connect your Supabase project
3. Import the frontend code
4. Lovable will handle deployment

### 6. Configure Environment

Create `.env` file:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

## Project Structure

```
ai-ugc-generator/
├── src/
│   ├── components/
│   │   └── ui.tsx              # Reusable UI components
│   ├── hooks/
│   │   └── useJobs.ts          # Data fetching & realtime hooks
│   ├── lib/
│   │   └── supabase.ts         # Supabase client
│   ├── types/
│   │   └── index.ts            # TypeScript types
│   ├── App.tsx                 # Main app with all pages
│   ├── main.tsx                # Entry point
│   └── index.css               # Tailwind styles
├── supabase/
│   ├── schema.sql              # Database schema
│   └── functions/
│       ├── download-tiktok/    # TikTok download function
│       ├── analyze-video/      # UGC segment detection
│       ├── generate-ai-character/  # Gemini + watermark removal
│       ├── generate-video/     # Kling Motion Control
│       └── process-pipeline/   # Main orchestrator
├── package.json
├── vite.config.ts
├── tailwind.config.js
└── README.md
```

## Usage

1. **Create a Character**: Go to Characters page and define your AI character's appearance
2. **Start a Job**: Click "New Job", paste a TikTok URL, select character
3. **Watch Progress**: Real-time logs show each step of the pipeline
4. **Download Videos**: When complete, download your AI UGC videos

## API Keys Required

### WaveSpeed API
- Sign up at [wavespeed.ai](https://wavespeed.ai)
- Get your API key from the dashboard
- Used for: Video analysis, watermark removal, Kling Motion Control

### Google Gemini API
- Sign up at [Google AI Studio](https://aistudio.google.com)
- Create an API key
- Used for: AI character image generation

## Troubleshooting

### "WAVESPEED_API_KEY not configured"
Add your WaveSpeed API key to Supabase Edge Function Secrets.

### "GEMINI_API_KEY not configured"
Add your Gemini API key to Supabase Edge Function Secrets.

### "Failed to download TikTok video"
- Check if the TikTok URL is valid
- The video must be public
- Try a different TikTok URL

### "Video generation timed out"
- Kling Motion Control can take 2-5 minutes per video
- Check your WaveSpeed dashboard for status
- Retry the job if needed

## License

MIT License - feel free to use for personal and commercial projects.

## Credits

Built with:
- [React](https://react.dev)
- [Supabase](https://supabase.com)
- [WaveSpeed AI](https://wavespeed.ai)
- [Google Gemini](https://ai.google.dev)
- [Tailwind CSS](https://tailwindcss.com)
