/*
  Warnings:

  - You are about to drop the column `createdAt` on the `Run` table. All the data in the column will be lost.
  - You are about to drop the column `updatedAt` on the `Run` table. All the data in the column will be lost.
  - Added the required column `rawLrcData` to the `Run` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE "Run" DROP CONSTRAINT "Run_userId_fkey";

-- DropIndex
DROP INDEX "Run_userId_date_idx";

-- AlterTable
ALTER TABLE "Run" DROP COLUMN "createdAt",
DROP COLUMN "updatedAt",
ADD COLUMN     "rawLrcData" JSONB NOT NULL,
ALTER COLUMN "date" SET DEFAULT CURRENT_TIMESTAMP;

-- AddForeignKey
ALTER TABLE "Run" ADD CONSTRAINT "Run_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
