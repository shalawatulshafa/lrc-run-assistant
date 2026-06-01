import prisma from '../lib/prisma.js';
import { ok, fail } from '../lib/apiResponse.js';
import { analyzeRunData } from '../services/analyzer.service.js';

// Menerjemahkan format tanggal dari ESP32 (WIB) ke objek Date UTC.
// Format yang valid: '14/05/2026, 15.29.48' (DD/MM/YYYY, HH.MM.SS).
// Lempar Error spesifik kalau input invalid — caller harus handle dan skip sesi
// agar tanggal palsu (mis. `new Date()` saat ini) tidak masuk ke database.
const parseCustomDate = (dateString) => {
    if (!dateString || typeof dateString !== 'string') {
        throw new Error('Tanggal kosong atau bukan string');
    }

    const parts = dateString.split(', ');
    if (parts.length !== 2) {
        throw new Error(`Format tanggal harus "DD/MM/YYYY, HH.MM.SS": "${dateString}"`);
    }

    const dateSplit = parts[0].split('/');
    const timeSplit = parts[1].split('.');
    if (dateSplit.length !== 3 || timeSplit.length !== 3) {
        throw new Error(`Bagian tanggal/waktu tidak lengkap: "${dateString}"`);
    }

    const day = parseInt(dateSplit[0], 10);
    const monthIndex = parseInt(dateSplit[1], 10) - 1; // JS bulan 0-based
    const year = parseInt(dateSplit[2], 10);
    const hour = parseInt(timeSplit[0], 10);
    const minute = parseInt(timeSplit[1], 10);
    const second = parseInt(timeSplit[2], 10);

    if ([day, monthIndex, year, hour, minute, second].some(Number.isNaN)) {
        throw new Error(`Komponen tanggal/waktu mengandung non-angka: "${dateString}"`);
    }

    // Range validation: tahun < 2020 biasanya menandakan RTC ESP32 belum di-sync
    // (boot ke epoch 1970 atau 2000). Tolak agar tanggal corrupt tidak masuk DB.
    if (
        year < 2020 || year > 2100 ||
        monthIndex < 0 || monthIndex > 11 ||
        day < 1 || day > 31 ||
        hour < 0 || hour > 23 ||
        minute < 0 || minute > 59 ||
        second < 0 || second > 59
    ) {
        throw new Error(`Komponen tanggal di luar rentang valid: "${dateString}"`);
    }

    // Konversi WIB → UTC dengan offset -7 jam.
    // 15:29 WIB tersimpan di DB sebagai 08:29 UTC.
    const finalDate = new Date(Date.UTC(year, monthIndex, day, hour - 7, minute, second));

    if (Number.isNaN(finalDate.getTime())) {
        throw new Error(`Tanggal tidak valid setelah konversi: "${dateString}"`);
    }

    return finalDate;
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

    const analyzedSessions = analyzeRunData(rawData);

    if (!analyzedSessions || analyzedSessions.length === 0) {
        return fail(res, 'VALIDATION_ERROR', 'Tidak ada data sesi yang valid untuk disimpan', 400);
    }

    const savedRuns = [];
    const failedSessions = [];

    // Lakukan perulangan untuk menyimpan setiap sesi ke Database.
    // Pakai upsert (atomic) terhadap compound unique (userId, date, sessionNumber)
    // agar sync paralel dari banyak device tidak menghasilkan duplikat.
    // Sesi dengan tanggal invalid di-skip (lihat parseCustomDate) — bukan disimpan
    // dengan timestamp palsu `new Date()` yang akan mengorupsi history user.
    for (const session of analyzedSessions) {
        let parsedDate;
        try {
            parsedDate = parseCustomDate(session.startDate);
        } catch (err) {
            console.error(
                `[syncRun] Skip sesi ${session.sessionNumber} (user ${userId}): ${err.message}`
            );
            failedSessions.push({
                sessionNumber: session.sessionNumber,
                startDate: session.startDate,
                error: err.message,
            });
            continue;
        }

        const savedRun = await prisma.run.upsert({
            where: {
                userId_date_sessionNumber: {
                    userId: userId,
                    date: parsedDate,
                    sessionNumber: session.sessionNumber,
                },
            },
            update: {
                targetPattern: session.targetPattern,
                avgSpm: session.avgSpm,
                compliance: session.compliance,
                duration: session.duration,
                rawLrcData: session.rawLrcData,
                avgLrc: session.avgLrc,
                rawCsv: session.rawCsv,
                avgLag: session.avgLag,
                phaseDrift: session.phaseDrift,
                consistencyScore: session.consistencyScore,
            },
            create: {
                userId: userId,
                date: parsedDate,
                sessionNumber: session.sessionNumber,
                title: `Lari LRC Sesi ${session.sessionNumber}`,
                targetPattern: session.targetPattern,
                avgSpm: session.avgSpm,
                compliance: session.compliance,
                duration: session.duration,
                rawLrcData: session.rawLrcData,
                avgLrc: session.avgLrc,
                rawCsv: session.rawCsv,
                avgLag: session.avgLag,
                phaseDrift: session.phaseDrift,
                consistencyScore: session.consistencyScore,
            },
        });

        savedRuns.push({
            runId: savedRun.id,
            summary: session,
        });
    }

    // Semua sesi gagal parse — kemungkinan besar RTC ESP32 belum di-sync
    if (savedRuns.length === 0 && failedSessions.length > 0) {
        return fail(
            res,
            'INVALID_SESSION_DATA',
            'Semua sesi gagal diproses karena tanggal tidak valid. Pastikan RTC alat sudah disinkronkan dengan HP.',
            400
        );
    }

    const message = failedSessions.length === 0
        ? `${savedRuns.length} sesi lari berhasil diunduh dan disimpan!`
        : `${savedRuns.length} sesi berhasil disimpan, ${failedSessions.length} sesi di-skip karena tanggal tidak valid.`;

    return ok(res, {
        message,
        runs: savedRuns,
        failedSessions,
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