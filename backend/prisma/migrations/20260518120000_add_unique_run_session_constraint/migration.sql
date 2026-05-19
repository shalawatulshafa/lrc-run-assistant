-- Dedup defensif: hapus baris yang punya (userId, date, sessionNumber) sama,
-- pertahankan satu baris arbitrer (lexicographically largest id).
-- Statement ini no-op kalau tidak ada duplikat eksisting.
-- WARNING: kalau ada duplikat dengan data berbeda, baris yang dihapus tidak bisa
-- dikembalikan tanpa backup. Review hasil SELECT berikut sebelum apply:
--   SELECT "userId", "date", "sessionNumber", COUNT(*)
--   FROM "Run"
--   GROUP BY "userId", "date", "sessionNumber"
--   HAVING COUNT(*) > 1;
DELETE FROM "Run" a
USING "Run" b
WHERE a.id < b.id
  AND a."userId" = b."userId"
  AND a."date" = b."date"
  AND a."sessionNumber" IS NOT DISTINCT FROM b."sessionNumber";

-- CreateIndex
CREATE UNIQUE INDEX "Run_userId_date_sessionNumber_key" ON "Run"("userId", "date", "sessionNumber");
