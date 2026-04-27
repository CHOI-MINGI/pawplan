# Railway Deployment

Deploy the backend as a Railway service with the repository root directory set to `backend`.

## Services

Create one Railway project with:

- Node.js service from this GitHub repository
- PostgreSQL database service
- Optional volume for local visit attachments

## Backend service settings

- Root Directory: `backend`
- Config file: `/backend/railway.json`
- Public networking: enabled

`railway.json` runs:

- Build: `npm run build`
- Pre-deploy: `npx prisma migrate deploy`
- Start: `npm start`
- Health check: `/health`

## Variables

Set these variables on the backend service:

```text
NODE_ENV=production
JWT_SECRET=<long-random-secret>
CORS_ORIGIN=*
DATABASE_URL=<Railway PostgreSQL DATABASE_URL>
```

For attachment uploads, create a Railway volume and mount it at `/data`, then add:

```text
UPLOAD_ROOT=/data/uploads
```

Without a volume, uploaded visit attachments may be lost on redeploy or restart.

## Mobile build

After the backend is deployed, rebuild the APK with the Railway API URL:

```powershell
cd H:\programming\jonsulpu\mobile
H:\tools\flutter\bin\flutter.bat build apk --debug --dart-define=API_BASE_URL=https://<railway-domain>/api/v1
```
