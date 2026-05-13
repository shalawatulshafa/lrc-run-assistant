import express from 'express';
import { syncRun, getRuns, getRunById, deleteRun, deleteAllRuns, updateRun } from '../controllers/run.controller.js';
import { verifyToken } from '../middleware/auth.js';

const router = express.Router();

router.use(verifyToken);

router.get('/', getRuns);
router.get('/:id', getRunById);
router.post('/sync', syncRun);
router.patch('/:id', updateRun);
router.delete('/:id', deleteRun);
router.delete('/', verifyToken, deleteAllRuns);

export default router;