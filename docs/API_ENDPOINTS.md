# API Endpoints - Ringkasan 
## 16 april

## Base URL
https://api.lrc-run.com/v1

## Authentication
Header: `Authorization: Bearer {token}`

---

## Daftar Endpoint

| No | Method | URL | Deskripsi | Auth |
|----|--------|-----|-----------|------|
| 1 | POST | /auth/login | Login | ❌ |
| 2 | POST | /auth/register | Daftar akun | ❌ |
| 3 | POST | /auth/logout | Logout | ✅ |
| 4 | GET | /user/profile | Ambil profil | ✅ |
| 5 | PUT | /user/profile | Update profil | ✅ |
| 6 | GET | /runs | History lari | ✅ |
| 7 | GET | /run/{id} | Detail lari | ✅ |
| 8 | POST | /runs/sync | Kirim data lari | ✅ |
| 9 | DELETE | /runs/{id} | Hapus data lari | ✅ |

---

## Keterangan

- ✅ = Perlu Header `Authorization: Bearer {token}`
- ❌ = Tidak perlu token

---

## Contoh Response Sukses

```json
{
  "success": true,
  "data": {}
}
```
## Contoh Response Error
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Pesan error"
  }
}
```
## Format Data

- **dateTime**: string (ISO 8601) → contoh: `2026-04-15T08:30:00Z`
- **distance**: double → contoh: `5.2`
- **avgSpm**: int → contoh: `164`
- **compliance**: int → contoh: `80`
- **duration**: int → contoh: `2535`
