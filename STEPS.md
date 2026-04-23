# Backend Implementation Steps (Node.js) for LRC Run Assistant

This guide is written for a beginner backend developer and follows your current Flutter API contract in:
- `docs/API_SPECIFICATION.md`
- `docs/API_ENDPOINTS.md`
- `lib/services/api_service.dart`

Goal: build a production-ready-enough backend in clear phases, without guessing.

---

## 1. Decide your backend stack (recommended)

Use this stack:
1. Node.js `20+`
2. Express.js
3. PostgreSQL
4. Prisma ORM
5. JWT (authentication)
6. `bcrypt` (password hashing)
7. `zod` (request validation)
8. `helmet` + `cors` + `morgan` (security/logging)

Why this stack:
- Easy to learn
- Strong ecosystem
- Easy to connect from Flutter
- Prisma keeps database code clean and safer

---

## 2. Create backend project folder

From your repo root (`lrc-run-assistant`):

```bash
mkdir backend
cd backend
npm init -y
```

Install dependencies:

```bash
npm i express cors helmet morgan dotenv jsonwebtoken bcrypt zod prisma @prisma/client
npm i -D nodemon
```

Add scripts in `backend/package.json`:

```json
{
  "scripts": {
    "dev": "nodemon src/server.js",
    "start": "node src/server.js",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate dev",
    "prisma:studio": "prisma studio"
  }
}
```

---

## 3. Create base folders

Inside `backend/`, create:

```text
backend/
  prisma/
    schema.prisma
  src/
    app.js
    server.js
    config/
      env.js
    middleware/
      auth.js
      errorHandler.js
    routes/
      auth.routes.js
      user.routes.js
      run.routes.js
    controllers/
      auth.controller.js
      user.controller.js
      run.controller.js
    services/
      token.service.js
      runTitle.service.js
    lib/
      prisma.js
      apiResponse.js
```

---

## 4. Setup environment variables

Create `backend/.env`:

```env
PORT=3000
NODE_ENV=development
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/lrc_run_db?schema=public"
JWT_SECRET="replace_with_long_random_secret"
JWT_EXPIRES_IN="7d"
CORS_ORIGIN="*"
```

Important:
- Never commit real secrets.
- For production, use strong JWT secret.

---

## 5. Setup Prisma and database schema

Initialize Prisma:

```bash
npx prisma init
```

Replace `prisma/schema.prisma` with a minimal schema:

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id           String   @id @default(cuid())
  name         String
  email        String   @unique
  passwordHash String
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
  runs         Run[]
}

model Run {
  id         String   @id @default(cuid())
  userId     String
  title      String
  date       DateTime
  distance   Float
  avgSpm     Int
  compliance Int
  duration   Int
  createdAt  DateTime @default(now())
  updatedAt  DateTime @updatedAt

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId, date])
}
```

Run migration:

```bash
npx prisma migrate dev --name init
npx prisma generate
```

---

## 6. Build application skeleton first

`src/lib/prisma.js`
- export one Prisma client instance

`src/lib/apiResponse.js`
- helpers for consistent response format:
  - `ok(res, data, status = 200)`
  - `fail(res, code, message, status)`

Response format must match your docs:

```json
{
  "success": true,
  "data": {}
}
```

and

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Pesan error"
  }
}
```

`src/app.js`
- init express
- use `helmet`, `cors`, `morgan`, `express.json()`
- mount routes with `/v1`
- global error handler

`src/server.js`
- load env
- start app on `PORT`

---

## 7. Implement authentication first

Endpoints to build:
1. `POST /v1/auth/register`
2. `POST /v1/auth/login`
3. `POST /v1/auth/logout`

### 7.1 Register

Flow:
1. Validate body (`email`, `name`, `password`)
2. Check if email already exists
3. Hash password with bcrypt
4. Create user
5. Create JWT token
6. Return token + user object

### 7.2 Login

Flow:
1. Validate body
2. Find user by email
3. Compare password with `bcrypt.compare`
4. Return JWT + user

### 7.3 Logout

For MVP:
- Just return `{ success: true }`
- JWT remains stateless (no blacklist yet)

If later needed:
- add token blacklist table/Redis

---

## 8. Add auth middleware

`src/middleware/auth.js`:
1. Read `Authorization` header
2. Check format `Bearer <token>`
3. Verify token using `JWT_SECRET`
4. Put `req.user = { userId }`
5. Continue, or return `UNAUTHORIZED`

Use this middleware on protected routes:
- `/v1/user/*`
- `/v1/runs/*`

---

## 9. Implement user profile endpoints

Endpoints:
1. `GET /v1/user/profile`
2. `PUT /v1/user/profile`

Rules:
- require auth middleware
- only operate on current logged-in user (`req.user.userId`)
- do not return password hash

---

## 10. Implement run endpoints

From your docs:
1. `GET /v1/runs`
2. `GET /v1/run/:id` (singular in spec)
3. `POST /v1/runs/sync`
4. `DELETE /v1/runs/:id`

Recommendation for compatibility:
- Support both:
  - `GET /v1/run/:id`
  - `GET /v1/runs/:id`

### 10.1 GET /runs
- get all runs for authenticated user
- sort by date descending

### 10.2 GET /run/:id
- get run by id + userId (important security)
- if not found, return `NOT_FOUND`

### 10.3 POST /runs/sync
- validate body:
  - `dateTime` ISO string
  - `distance` number
  - `avgSpm` int
  - `compliance` int (0-100)
  - `duration` int seconds
- generate title (temporary simple title is fine)
- create run
- return `{ runId, title }`

### 10.4 DELETE /runs/:id
- delete by `id + userId`
- return success

---

## 11. Suggested validation rules (Zod)

Auth:
- email valid format
- name min length 2
- password min length 6

Run sync:
- `distance > 0`
- `avgSpm >= 0`
- `compliance` between 0 and 100
- `duration > 0`
- `dateTime` must parse to valid date

If validation fails:
- return `400` with `code: "VALIDATION_ERROR"`

---

## 12. Error code mapping (align with your docs)

Use these codes consistently:
1. `INVALID_CREDENTIALS` (401)
2. `UNAUTHORIZED` (401)
3. `TOKEN_EXPIRED` (401)
4. `EMAIL_EXISTS` (409)
5. `NOT_FOUND` (404)
6. `SERVER_ERROR` (500)
7. `VALIDATION_ERROR` (400)

---

## 13. Manual API testing checklist (Postman/Insomnia)

Test in this order:
1. Register user
2. Login user -> copy token
3. Get profile with token
4. Update profile
5. Sync run data
6. Get runs list
7. Get run detail by ID
8. Delete run
9. Logout

Also test error cases:
1. Invalid login
2. Missing token
3. Invalid token
4. Invalid run payload
5. Accessing another user’s run ID (must fail)

---

## 14. Connect Flutter to backend (after backend is stable)

In Flutter:
1. update `baseUrl` in `lib/services/api_service.dart`
2. implement methods to call real backend
3. store JWT securely (`shared_preferences` for MVP, secure storage preferred later)
4. add auth header on protected requests

Local testing URL:
- Android emulator usually uses `10.0.2.2` for localhost
- Example: `http://10.0.2.2:3000/v1`

---

## 15. Optional BLE endpoints (future phase)

Your `ApiService` has placeholders:
- `hasNewData()`
- `getChestStrapStatus()`
- `downloadRunData()`

If backend controls BLE gateway later:
1. add separate service/module for BLE adapter
2. keep same response contract
3. if not ready, return mock data safely

For now, core backend priority is auth/profile/runs.

---

## 16. Deployment checklist (when ready)

1. Deploy PostgreSQL (managed or VPS)
2. Deploy Node API (Railway/Render/Fly/VM)
3. Set production env vars
4. Run Prisma migrate on production DB
5. Set CORS to Flutter app origin(s)
6. Enable HTTPS
7. Add basic monitoring/logging
8. Backup database

---

## 17. Final implementation order (recommended timeline)

### Phase A (Day 1)
1. project setup
2. database setup + migration
3. app skeleton + response helpers

### Phase B (Day 2)
1. register/login/logout
2. auth middleware
3. profile endpoints

### Phase C (Day 3)
1. run endpoints (`/runs`, `/run/:id`, `/runs/sync`, delete)
2. validation + error handling polish
3. full API test pass

### Phase D (Day 4)
1. integrate Flutter with real API
2. fix contract mismatches
3. prepare deployment

---

## 18. Done criteria (Definition of Done)

Backend is considered done when:
1. all 9 endpoints from your API docs are implemented
2. responses follow the documented JSON structure
3. auth works with JWT on protected routes
4. run data is user-scoped securely
5. Postman test collection passes
6. Flutter can login + sync + read history from backend

---

## 19. Practical tips to avoid common mistakes

1. Always filter by `userId` for profile/run queries.
2. Never return `passwordHash` in API response.
3. Keep one error response format everywhere.
4. Validate request body before database query.
5. Use database migration files, not manual SQL edits in production.
6. Start simple first, optimize later.

---

If you want, next step I can generate a ready-to-run backend starter code (`backend/src/*`) following this exact plan so you can run it immediately.
