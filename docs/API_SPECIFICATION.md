# API Specification - LRC Run Assistant

## Base URL
https://api.lrc-run.com/v1

## Authentication
Header: Authorization: Bearer {token}

---

## 1. LOGIN

**Method:** POST
**URL:** /auth/login

**Request:**
```json
{
  "email": "string",
  "password": "string"
}
```
**Response:**
```json
{
  "success": true,
  "data": {
    "token": "string",
    "user": {
      "id": "string",
      "name": "string",
      "email": "string"
    }
  }
}
```
## 2. REGISTER

**Method:** POST
**URL:** /auth/register

**Request:**
```json
{
  "email": "user@example.com",
  "name": "User Name",
  "password": "password123"
}
```
**Response Sukses:**
```json
{
  "success": true,
  "data": {
    "token": "jwt_token_xxx",
    "user": {
      "id": "user_123",
      "name": "User",
      "email": "user@example.com"
    }
  }
}
```
## 3. LOGOUT

**Method:** POST
**URL:** /auth/logout
**Header:** Authorization: Bearer {token}


**Response:**
```json
{
  "success": true
}
```
## 4. GET PROFILE

**Method:** GET
**URL:** /user/profile
**Header:** Authorization: Bearer {token}

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "user_123",
    "name": "User Name",
    "email": "user@example.com"
  }
}
```

## 5. UPDATE PROFILE

**Method:** PUT
**URL:** /user/profile
**Header:** Authorization: Bearer {token}

**Request:**
```json
{
  "name": "Nama Baru",
  "email": "emailbaru@example.com"
}
```
**Response:**
```json
{
  "success": true,
  "data": {
    "id": "user_123",
    "name": "Nama Baru",
    "email": "emailbaru@example.com"
  }
}
```
## 6. GET RUN HISTORY

**Method:** GET
**URL:** /runs
**Header:** Authorization: Bearer {token}

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "string",
      "title": "string",
      "date": "2026-04-15T08:30:00Z",
      "distance": 5.2,
      "avgSpm": 164,
      "compliance": 80,
      "duration": 2535
    }
  ]
}
```
## 7. GET RUN DETAIL

**Method:** GET
**URL:** /run/{id}
**Header:** Authorization: Bearer {token}

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "run_001",
    "title": "Pagi 5.2km - Lari Rutin",
    "date": "2026-04-15T08:30:00Z",
    "distance": 5.2,
    "avgSpm": 164,
    "compliance": 80,
    "duration": 2535
  }
}
```
## 8. SYNC RUN DATA (dari Chest Strap)

**Method:** POST
**URL:** /runs/sync
**Header:** Authorization: Bearer {token}

**Request:**
```json
{
  "dateTime": "2026-04-15T08:30:00Z",
  "distance": 5.2,
  "avgSpm": 164,
  "compliance": 80,
  "duration": 2535
}
```
**Response:**
```json
{
  "success": true,
  "data": {
    "runId": "string",
    "title": "string"
  }
}
```
## 9. DELETE RUN DATA

**Method:** DELETE
**URL:** /runs/{id}
**Header:** Authorization: Bearer {token}

**Response:**
```json
{
  "success": true
}
```
## FORMAT ERROR (Semua Endpoint)
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Pesan error"
  }
}
```
## DAFTAR ERROR CODE

- **INVALID_CREDENTIALS** : Email atau password salah
- **UNAUTHORIZED** : Token tidak valid
- **TOKEN_EXPIRED** : Token kadaluarsa
- **EMAIL_EXISTS** : Email sudah terdaftar
- **NOT_FOUND** : Data tidak ditemukan
- **SERVER_ERROR** : Error server

## CATATAN UNTUK BACKEND

- **Token**: JWT, expire 7 hari
- **Format tanggal**: ISO 8601 (contoh: 2026-04-15T08:30:00Z)
- **Distance**: kilometer (double)
- **Duration**: detik (int)
- **Compliance**: persen 0-100 (int)





