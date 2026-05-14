/*
  Warnings:

  - You are about to drop the column `distance` on the `Run` table. All the data in the column will be lost.
  - Added the required column `targetPattern` to the `Run` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "Run" DROP COLUMN "distance",
ADD COLUMN     "targetPattern" TEXT NOT NULL,
ALTER COLUMN "duration" SET DATA TYPE TEXT;
