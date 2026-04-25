import express from 'express';
import { syncRun, getRuns } from '../controllers/run.controller.js';
import { verifyToken } from '../middleware/auth.js';

const router = express.Router();

router.use(verifyToken);

router.post('/', syncRun);
router.get('/', getRuns);

export default router;