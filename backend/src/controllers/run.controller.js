import prisma from '../lib/prisma.js';
import { ok, fail } from '../lib/apiResponse.js';

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
        const { dateTime, distance, avgSpm, compiance, duration } = req.body;

        const dateObj = new Date(dateTime);
        const title = `Run on ${dateObj.toLocaleDateString()}`;

        const newRun = await prisma.run.create({
            data: {
                userId,
                title,
                date: dateObj,
                distance,
                avgSpm,
                compliance,
                duration,
            },
        });

        return ok(res, { runId: newRun.id, title: newRun.title }, 201);
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
            return fail(res, 'NOT_FOUND', 'Run not found', 404);
        }

        await prisma.run.delete({
            where: { id: runId },
        });

        return ok(res, { message: 'Run deleted successfully' })
    } catch (error) {
        next(error);
    }
};