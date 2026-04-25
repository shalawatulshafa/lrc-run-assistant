import prisma from '../lib/prisma.js';
import { ok, fail } from '../lib/apiResponse.js';

export const getProfile = async (req, res, next) => {
    try {
        const userId = req.user.userId;

        const user = await prisma.user.findUnique({
            where: { id: userId },
            select: { id: true, name: true, email: true, createdAt: true }
        });

        if (!user) {
            return fail(res, 'NOT_FOUND', 'Pengguna tidak ditemukan', 404);
        }

        return ok(res, user);
    } catch (error) {
        next(error);
    }
};

export const updateProfile = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { name } = req.body;

        // Update user's name in the database
        const updatedUser = await prisma.user.update({
            where: { id: userId },
            data: { name },
            select: { id: true, name: true, email: true }
        });

        return ok(res, updatedUser);
    } catch (error) {
        next(error);
    }
};