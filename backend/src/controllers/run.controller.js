import prisma from '../lib/prisma.js';
import { ok, fail } from '../lib/apiResponse.js';
import { analyzeRunData } from '../services/analyzer.service.js';

// Fungsi untuk menerjemahkan format tanggal '14/05/2026, 15.29.48'
const parseCustomDate = (dateString) => {
    try {
        if (!dateString) return new Date();
        
        const parts = dateString.split(', ');
        if (parts.length !== 2) return new Date(dateString); 

        const datePart = parts[0]; 
        const timePart = parts[1]; 

        const dateSplit = datePart.split('/');
        const timeSplit = timePart.split('.');

        if (dateSplit.length !== 3 || timeSplit.length !== 3) return new Date();

        const day = parseInt(dateSplit[0], 10);
        // JS Date biasa menghitung bulan dari 0, tapi untuk string ISO kita pakai angka aslinya (1-12)
        const month = parseInt(dateSplit[1], 10); 
        const year = parseInt(dateSplit[2], 10);

        const hour = parseInt(timeSplit[0], 10);
        const minute = parseInt(timeSplit[1], 10);
        const second = parseInt(timeSplit[2], 10);

        // 🔥 PERBAIKAN: Format menjadi Standar ISO dengan zona waktu WIB (+07:00)
        // Kita beritahu database bahwa waktu ini adalah murni waktu Indonesia (WIB)
        const pad = (n) => n.toString().padStart(2, '0');
        const isoString = `${year}-${pad(month)}-${pad(day)}T${pad(hour)}:${pad(minute)}:${pad(second)}+07:00`;
        
        const finalDate = new Date(isoString);
        
        // Pastikan hasilnya valid
        if (isNaN(finalDate.getTime())) return new Date();
        
        return finalDate;
    } catch (error) {
        return new Date(); // Jika gagal, gunakan waktu saat ini sebagai pengaman
    }
};

// GET /runs
export const getRuns = async (req, res, next) => {
    try {
        const userId = req.user.userId;

        const runs = await prisma.run.findMany({
            where: { userId },
            orderBy: { date: 'desc' }, // Mengurutkan dari sesi lari terbaru
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

// POST /runs/sync (DIPERBARUI UNTUK MENCEGAH DUPLIKAT DATA MULTI-SESI)
export const syncRun = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { rawData } = req.body; 
    
    if (!rawData) {
        return fail(res, 'VALIDATION_ERROR', 'Data sensor diperlukan', 400);
    }

    // 1. Analisis seluruh data yang dikirim (bisa berisi 1 atau 10 sesi sekaligus)
    const analyzedSessions = analyzeRunData(rawData);

    if (!analyzedSessions || analyzedSessions.length === 0) {
        return fail(res, 'VALIDATION_ERROR', 'Tidak ada data sesi yang valid untuk disimpan', 400);
    }

    const savedRuns = [];

    // 2. Lakukan perulangan untuk menyimpan setiap sesi ke Database
    for (const session of analyzedSessions) {
        const parsedDate = parseCustomDate(session.startDate);

        // 🔥 PERBAIKAN: Cek apakah sesi dengan tanggal dan user ini sudah pernah diunduh
        const existingRun = await prisma.run.findFirst({
            where: {
                userId: userId,
                date: parsedDate,
                sessionNumber: session.sessionNumber
            }
        });

        let savedRun;

        if (existingRun) {
            // Jika sudah ada (duplikat), timpa datanya agar riwayat tidak berlipat ganda
            savedRun = await prisma.run.update({
                where: { id: existingRun.id },
                data: {
                    targetPattern: session.targetPattern, 
                    avgSpm: session.avgSpm,
                    compliance: session.compliance,
                    duration: session.duration,
                    rawLrcData: session.rawLrcData,
                    avgLrc: session.avgLrc,
                }
            });
        } else {
            // Jika belum ada, buat sesi baru
            savedRun = await prisma.run.create({
                data: {
                    userId: userId,
                    date: parsedDate,                      // Waktu asli dari alat ESP32
                    sessionNumber: session.sessionNumber,  // Nomor urut sesi
                    title: `Lari LRC Sesi ${session.sessionNumber}`, 
                    targetPattern: session.targetPattern, 
                    avgSpm: session.avgSpm,
                    compliance: session.compliance,
                    duration: session.duration,
                    rawLrcData: session.rawLrcData,
                    avgLrc: session.avgLrc, 
                },
            });
        }

        savedRuns.push({
            runId: savedRun.id,
            summary: session
        });
    }

    // 3. Kembalikan semua data yang berhasil disinkronisasi ke Aplikasi HP
    return ok(res, { 
        message: `${savedRuns.length} sesi lari berhasil diunduh dan disimpan!`,
        runs: savedRuns 
    }, 201);
    
  } catch (error) {
    next(error);
  }
};

// UPDATE /runs/:id (Update Judul)
export const updateRun = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const runId = req.params.id;
        const { title } = req.body;

        const run = await prisma.run.findFirst({
            where: { id: runId, userId: userId },
        });

        if (!run) {
            return fail(res, 'NOT_FOUND', 'Data lari tidak ditemukan', 404);
        }

        const updatedRun = await prisma.run.update({
            where: { id: runId },
            data: { title: title },
        });

        return ok(res, updatedRun);
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
            return fail(res, 'NOT_FOUND', 'Data lari tidak ditemukan', 404);
        }

        await prisma.run.delete({
            where: { id: runId },
        });

        return ok(res, { message: 'Data lari berhasil dihapus' })
    } catch (error) {
        next(error);
    }
};

// DELETE /runs
export const deleteAllRuns = async (req, res, next) => {
    try {
        const userId = req.user.userId;

        await prisma.run.deleteMany({
            where: { userId: userId },
        });

        return ok(res, { message: "Semua data lari berhasil dihapus secara permanen" });
    } catch (error) {
        next(error);
    }
};