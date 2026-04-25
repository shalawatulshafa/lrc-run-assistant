import express from 'express';
import { getProfile, updateProfile } from '../controllers/user.controller.js';
import { verifyToken } from '../middleware/auth.js';

const router = express.Router();

router.use(verifyToken);

router.get('/profile', getProfile);
router.put('/profile', updateProfile);

export default router;