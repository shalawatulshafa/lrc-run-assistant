import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import primsa from '../lib/prisma.js'
import { ok, fail } from '../lib/apiResponse.js';

export const register = async (req, res, next) => {
  try {
    const { name, email, password } = req.body;

    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      return fail(res, 'EMAIL_EXISTS', 'Email sudah terdaftar', 409);
    }

    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    const user = await prisma.user.create({
      data: { name, email, passwordHash },
    });

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
      expiresIn: process.env.JWT_EXPIRES_IN,
    });

    return ok(res, {
      token,
      user: { id: user.id, name: user.name, email: user.email },
    });
  } catch (error) {
    next(error);
  }
};

export const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      return fail(res, 'INVALID_CREDENTIALS', 'Email atau password salah', 401);
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      return fail(res, 'INVALID_CREDENTIALS', 'Email atau password salah', 401);
    }

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
      expiresIn: process.env.JWT_EXPIRES_IN,
    });

    return ok(res, {
      token,
      user: { id: user.id, name: user.name, email: user.email },
    });
  } catch (error) {
    next(error);
  }
};

export const logout = async (req, res, next) => {
    try {
        return ok(res, { message: "Logout berhasil!" });
    } catch (error) {
        next(error);
    }
};