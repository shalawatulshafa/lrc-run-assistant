import prisma from '../lib/prisma.js';
import { ok, fail } from '../lib/apiResponse.js';

// Sync new run from chest strap to the database
export const syncRun = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { title, date, distance, avgSpm, compliance, duration } = req.body;

        const newRun = await prisma.run.create({
            data: {
                userId,
                title,
                date: new Date(date),
                distance,
                avgSpm,
                compliance,
                duration,
            },
        });

        return ok(res, newRun, 201);
    } catch (error) {
        next(error);
    }
};

export const getRuns = async (req, res, next) => {
    try {
        const userId = req.user.userId;

        const runs = await prisma.run.findMany({
            where: { userId },
            orderBy: { date:'desc' }, // Order by date
        });

        return ok(res, runs);
    } catch (error) {
        next(error);
    }
}
