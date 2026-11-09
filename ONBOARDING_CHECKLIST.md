# Handover Checklist (Nasr → Asmaa)

Fill in one copy of Section B per system.

## A. Chat history
- [ ] Export the data from ChatGPT: Settings → Data Controls → Export data
- [ ] Send the zip (`conversations.json`, `chat.html`) securely
- [ ] Share any chats that matter most as links (optional)
- [ ] List which chats belong to which system or module

## B. Per system (repeat for each)

**System name:** ______________________  **Link:** ______________________

- [ ] Where does it run? (Nasr's laptop / a server / a hosting platform: ________)
- [ ] Is the link a tunnel? (ngrok / Cloudflare / localtunnel / none)
- [ ] Project folder path: ______________________
- [ ] Start command (e.g. `npm run dev`, `python app.py`, `docker compose up`): ______________________
- [ ] Stack (language, framework, versions): ______________________
- [ ] Database type and location (SQLite file / local Postgres or MySQL / hosted: ________)
- [ ] DB dump or backup provided
- [ ] `.env` file or list of env vars (send keys via a password manager, never by chat or email)
- [ ] External services and keys in use (OpenAI API, email, storage, auth, etc.)
- [ ] Existing backup of the folder
- [ ] Known bugs / unfinished parts / next features wanted

## C. Access and ownership
- [ ] Copy of every project folder
- [ ] Private repo created under the firm's GitHub org
- [ ] `.env` added to `.gitignore` before the first commit
- [ ] Accounts needed: hosting, domain/DNS, OpenAI API, DB host, tunnel service
- [ ] Who owns each account (firm or personal)?

## D. Verification on the MacBook
- [ ] Fresh clone runs from the README
- [ ] DB restored and the app reads it correctly
- [ ] Each system has a short README (run, stack, env vars, schema)
- [ ] Inventory and per-module gap list written

## Quick checks for each link
- [ ] `curl -I <url>` and note the headers
- [ ] Domain hints at the host (`ngrok`, `trycloudflare`, `vercel`, `replit`, `lovable`)
- [ ] Does it go down when Nasr's laptop is off? (yes means it's a tunnel to his machine)
