// Auth Middleware
import jwt from 'jsonwebtoken';
import { fail } from '../lib/apiResponse.js';

export const verifyToken = (req, res, next) => {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return fail(res, 'UNAUTHORIZED', 'Akses ditolak. Token tidak ditemukan', 401);
    }

    const token = authHeader.split(' ')[1];

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);

        req.user = { userId: decoded.userId };

        next();
    } catch (error) {
        return fail(res, 'TOKEN_EXPIRED', 'Token tidak valid atau sudah kedaluwarsa', 401);
    }
};