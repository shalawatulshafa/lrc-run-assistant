/**
 * analyzer.service.js
 * Diperbarui khusus untuk format Snapshot 7 Kolom terbaru dari ESP32
 * Format: sesi,mulai_lari,waktu_ms,breathPhase,step,spm,patternID
 */

export const analyzeRunData = (rawData) => {
    // 1. Validasi Input
    if (!rawData || typeof rawData !== 'string') return [];

    // Pisahkan baris per baris berdasarkan enter atau titik koma
    const rawLines = rawData.split(/[\n;]/).filter(row => row.trim() !== '');

    const sessionsMap = {};

    // 2. PARSING CSV (Disempurnakan untuk 7 Kolom)
    rawLines.forEach(line => {
        // 🔥 FITUR BARU: Melewati baris header (judul kolom) atau baris EOF
        if (line.toLowerCase().includes('sesi') || line.includes('EOF')) return;

        // Karena format tanggal adalah "15/05/2026, 17.00.53" (ada koma di dalamnya),
        // maka saat di-split dengan koma, array akan terpecah menjadi 8 bagian (indeks 0-7)
        const parts = line.split(',');
        
        // Pastikan baris ini memiliki data yang utuh (minimal 8 pecahan)
        if (parts.length < 8) return;

        const sessionId = parts[0].trim();
        // Menggabungkan kembali tanggal dan jam, serta membuang tanda kutip (")
        const rawDate = `${parts[1].replace(/"/g, '').trim()}, ${parts[2].replace(/"/g, '').trim()}`;
        
        // 🔥 PERBAIKAN INDEKS (Assign Variabel yang Benar)
        const timestamp = parseInt(parts[3]);
        const breathPhase = parseInt(parts[4]); // 1 (Inhale), -1 (Exhale), 0 (Netral)
        const step = parseInt(parts[5]);        // 1 (Langkah), 0 (Tidak ada)
        const spm = parseFloat(parts[6]);       // 90.0 (Data desimal)
        const patternID = parseInt(parts[7]);   // 0 (3:2), 1 (2:1), dst.

        // Inisialisasi sesi jika belum ada di Map
        if (!sessionsMap[sessionId]) {
            sessionsMap[sessionId] = {
                startDate: rawDate,
                targetPatternId: patternID, // Ambil target pola dari baris pertama sesi ini
                spmSum: 0,
                spmCount: 0,
                startTime: timestamp,
                endTime: timestamp,
                
                // Variabel untuk menghitung Napas & Langkah (LRC)
                currentPhase: null, // 'IN' atau 'EX'
                currentInhaleSteps: 0,
                currentExhaleSteps: 0,
                cycles: [],
                totalInhaleStepsAll: 0,
                totalExhaleStepsAll: 0,
                totalCycles: 0
            };
        }

        const session = sessionsMap[sessionId];
        
        // Update waktu akhir setiap kali ada baris baru
        session.endTime = Math.max(session.endTime, timestamp);

        // Kumpulkan rata-rata SPM
        if (!isNaN(spm) && spm > 0) {
            session.spmSum += spm;
            session.spmCount++;
        }

        // --- 3. LOGIKA LRC SNAPSHOT (Fase Napas + Langkah sekaligus) ---
        
        // A. Cek perubahan fase napas terlebih dahulu
        if (breathPhase === 1) { // Mulai Tarik Napas (INHALE)
            if (session.currentPhase === 'EX') {
                // Berarti 1 siklus napas (Tarik -> Hembus) telah selesai. Simpan datanya!
                if (session.currentInhaleSteps > 0 || session.currentExhaleSteps > 0) {
                    session.cycles.push({
                        in: session.currentInhaleSteps,
                        ex: session.currentExhaleSteps
                    });
                    session.totalInhaleStepsAll += session.currentInhaleSteps;
                    session.totalExhaleStepsAll += session.currentExhaleSteps;
                    session.totalCycles++;
                }
                // Reset hitungan langkah untuk siklus yang baru
                session.currentInhaleSteps = 0;
                session.currentExhaleSteps = 0;
            }
            session.currentPhase = 'IN';
        } 
        else if (breathPhase === -1) { // Mulai Hembus Napas (EXHALE)
            session.currentPhase = 'EX';
        }
        // (Jika breathPhase === 0, berarti masih netral, tetap di currentPhase sebelumnya)

        // B. Cek apakah ada langkah kaki di baris/waktu ini
        if (step === 1) {
            if (session.currentPhase === 'IN') {
                session.currentInhaleSteps++;
            } else if (session.currentPhase === 'EX') {
                session.currentExhaleSteps++;
            }
        }
    });

    // 4. MENGHITUNG KESIMPULAN PER SESI
    const convertPatternId = (id) => {
        const map = { 0: "3:2", 1: "2:1", 2: "2:2", 3: "3:3", 4: "4:4", 5: "4:3", 6: "1:1" };
        return map[id] || "3:2";
    };

    const mapPatternToY = (patternStr) => {
        const mapping = { "4:4": 7, "4:3": 6, "3:3": 5, "3:2": 4, "2:2": 3, "2:1": 2, "1:1": 1 };
        return mapping[patternStr] || 4;
    };

    const detectActualPattern = (inSteps, exSteps) => {
        const ratio = inSteps / (exSteps || 1);
        if (ratio >= 1.8) return "2:1";
        if (ratio >= 1.3) return "3:2";
        if (inSteps === exSteps) {
            if (inSteps >= 4) return "4:4";
            if (inSteps === 3) return "3:3";
            if (inSteps === 2) return "2:2";
            return "1:1";
        }
        return `${inSteps}:${exSteps}`;
    };

    const analyzedSessions = [];

    // Loop semua sesi yang sudah dikelompokkan
    for (const [sessionId, session] of Object.entries(sessionsMap)) {
        const targetPattern = convertPatternId(session.targetPatternId);
        
        // Hitung Durasi (ms ke menit:detik)
        const durationMs = session.endTime - session.startTime;
        const durationSeconds = Math.max(0, Math.floor(durationMs / 1000));
        const minutes = Math.floor(durationSeconds / 60);
        const seconds = durationSeconds % 60;
        const formattedDuration = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;

        // Evaluasi Kepatuhan & Persiapkan Data Grafik
        let matchCount = 0;
        let graphDataPoints = [];

        session.cycles.forEach(cycle => {
            const actualPattern = detectActualPattern(cycle.in, cycle.ex);
            
            // Cek kepatuhan (Apakah pola aslinya sama dengan target alat?)
            if (actualPattern === targetPattern || 
               (targetPattern === "3:2" && cycle.in === 3 && cycle.ex === 2) ||
               (targetPattern === "2:1" && cycle.in === 2 && cycle.ex === 1)) {
                matchCount++;
            }

            graphDataPoints.push({
                y: mapPatternToY(actualPattern),
                in: cycle.in,
                ex: cycle.ex
            });
        });

        // Hitung Kepatuhan (%)
        const compliance = session.totalCycles > 0 
            ? Math.round((matchCount / session.totalCycles) * 100) 
            : 0;

        // Smoothing Grafik (Agar garis di aplikasi Flutter tidak terlalu tajam/naik-turun drastis)
        let finalGraphData = [];
        for (let i = 0; i < graphDataPoints.length; i++) {
            let sumY = 0;
            let count = 0;
            for (let j = Math.max(0, i - 1); j <= Math.min(graphDataPoints.length - 1, i + 1); j++) {
                sumY += graphDataPoints[j].y;
                count++;
            }
            finalGraphData.push(parseFloat((sumY / count).toFixed(2)));
        }

        // Rata-Rata Rasio LRC Aktual (Napas : Langkah)
        const avgInhale = session.totalCycles > 0 ? (session.totalInhaleStepsAll / session.totalCycles).toFixed(1) : "0.0";
        const avgExhale = session.totalCycles > 0 ? (session.totalExhaleStepsAll / session.totalCycles).toFixed(1) : "0.0";

        // Masukkan hasil akhir untuk dikirim ke Flutter
        analyzedSessions.push({
            sessionNumber: parseInt(sessionId),
            startDate: session.startDate, 
            targetPattern: targetPattern,
            duration: formattedDuration,
            avgSpm: session.spmCount > 0 ? Math.round(session.spmSum / session.spmCount) : 0,
            compliance: compliance,
            avgLrc: `${avgInhale} : ${avgExhale}`,
            rawLrcData: finalGraphData
        });
    }

    return analyzedSessions;
};