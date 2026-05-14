import prisma from '../lib/prisma.js';
import { ok, fail } from '../lib/apiResponse.js';
import { analyzeRunData } from '../services/analyzer.service.js';

const convertPatternId = (id) => {
  const patterns = {
    0: "3:2",
    1: "2:1"
  };
  return patterns[id] || "3:2"; 
};

// GET /runs
export const getRuns = async (req, res, next) => {
    try {
        const userId = req.user.userId;

        const runs = await prisma.run.findMany({
            where: { userId },
            orderBy: { date: 'desc' },
        });

        return ok(res, runs);
    } catch (error) {
        next(error);
    }
};

// GET /run/:id and /runs/:id
export const getRunById = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const runId = req.params.id;

        const run = await prisma.run.findFirst({
            where: {
                id: runId,
                userId: userId,
            }
        });

        if (!run) {
            return fail(res, 'NOT_FOUND', 'Run not found', 404);
        }

        return ok(res, run);
    } catch (error) {
        next(error);
    }
};

// POST /runs/sync
export const syncRun = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { dateTime, targetPattern, rawData } = req.body;
    
    if (!rawData || !targetPattern) {
        return fail(res, 'VALIDATION_ERROR', 'Data sensor dan target pola diperlukan', 400);
    }

    const patternLabel = convertPatternId(parseInt(targetPattern));

    const analysis = analyzeRunData(rawData, patternLabel);

    const newRun = await prisma.run.create({
      data: {
        userId,
        date: new Date(dateTime),
        title: `Lari LRC ${patternLabel}`,
        targetPattern: patternLabel, 
        avgSpm: analysis.avgSpm,
        compliance: analysis.compliance,
        duration: analysis.duration,
        rawLrcData: analysis.graphData 
      },
    });

    return ok(res, { 
        runId: newRun.id, 
        summary: analysis 
    }, 201);
  } catch (error) {
    next(error);
  }
};

// UPDATE /runs/:id (Update Judul)
export const updateRun = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const runId = req.params.id;
        const { title } = req.body;

        // Pastikan data ini milik user yang sedang login
        const run = await prisma.run.findFirst({
            where: { id: runId, userId: userId },
        });

        if (!run) {
            return fail(res, 'NOT_FOUND', 'Data lari tidak ditemukan', 404);
        }

        const updatedRun = await prisma.run.update({
            where: { id: runId },
            data: { title: title },
        });

        return ok(res, updatedRun);
    } catch (error) {
        next(error);
    }
};

// DELETE /runs/:id
export const deleteRun = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const runId = req.params.id;

        const run = await prisma.run.findFirst({
            where: { id: runId, userId: userId },
        });

        if (!run) {
            return fail(res, 'NOT_FOUND', 'Data lari tidak ditemukan', 404);
        }

        await prisma.run.delete({
            where: { id: runId },
        });

        return ok(res, { message: 'Data lari berhasil dihapus' })
    } catch (error) {
        next(error);
    }
};

// DELETE /runs
export const deleteAllRuns = async (req, res, next) => {
    try {
        const userId = req.user.userId;

        // Menghapus semua riwayat lari milik user yang sedang login
        await prisma.run.deleteMany({
            where: { userId: userId },
        });

        return ok(res, { message: "Semua data lari berhasil dihapus secara permanen" });
    } catch (error) {
        next(error);
    }
};