import express from 'express';
import { syncRun, getRuns, getRunById, deleteRun } from '../controllers/run.controller.js';
import { verifyToken } from '../middleware/auth.js';

const router = express.Router();

router.use(verifyToken);

router.get('/', getRuns);
router.get('/:id', getRunById);
router.post('/sync', syncRun);
router.delete('/:id', deleteRun);

export default router;