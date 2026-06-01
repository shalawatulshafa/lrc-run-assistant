-- Metrik baru untuk LRC analysis dengan format CSV step=0 transition rows.
-- Semua nullable agar data lari lama (sebelum firmware update) tetap valid (NULL).
ALTER TABLE "Run" ADD COLUMN "avgLag" DOUBLE PRECISION;
ALTER TABLE "Run" ADD COLUMN "phaseDrift" DOUBLE PRECISION;
ALTER TABLE "Run" ADD COLUMN "consistencyScore" INTEGER;
