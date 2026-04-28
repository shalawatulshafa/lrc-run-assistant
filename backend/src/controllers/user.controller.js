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
        const { name, email } = req.body;

        if (!name || !email) {
            return fail(res, 'VALIDATION_ERROR', 'Name dan email diperlukan', 400);
        }

        // Update user's name in the database
        const updatedUser = await prisma.user.update({
            where: { id: userId },
            data: { name, email },
            select: { id: true, name: true, email: true }
        });

        return ok(res, updatedUser);
    } catch (error) {
        if (error.code == 'P2002') {
            return fail(res, 'EMAIL_EXISTS', 'Email sudah digunakan', 409);
        }
        next(error);
    }
};