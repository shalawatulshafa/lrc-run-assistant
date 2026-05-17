export const analyzeRunData = (rawData) => {
    if (!rawData || typeof rawData !== 'string') return [];

    const rawLines = rawData.split(/[\n;]/).filter(row => row.trim() !== '');
    const sessionsMap = {};

    rawLines.forEach(line => {
        if (line.toLowerCase().includes('sesi') || line.includes('EOF')) return;

        const parts = line.split(',');
        if (parts.length < 8) return;

        const sessionId = parts[0].trim();
        const rawDate = `${parts[1].replace(/"/g, '').trim()}, ${parts[2].replace(/"/g, '').trim()}`;
        const timestamp = parseInt(parts[3]);
        const breathPhase = parseInt(parts[4]); 
        const step = parseInt(parts[5]);        
        const spm = parseFloat(parts[6]);       
        const patternID = parseInt(parts[7]);   

        if (!sessionsMap[sessionId]) {
            sessionsMap[sessionId] = {
                startDate: rawDate,
                spmSum: 0,
                spmCount: 0,
                startTime: timestamp,
                endTime: timestamp,
                currentPhase: null, 
                currentInhaleSteps: 0,
                currentExhaleSteps: 0,
                cycles: [],
                targetPatternsUsed: new Set() // Melacak pola apa saja yang dipakai di sesi ini
            };
        }

        const session = sessionsMap[sessionId];
        session.endTime = Math.max(session.endTime, timestamp);
        session.targetPatternsUsed.add(patternID); // Daftarkan pola yang aktif

        if (!isNaN(spm) && spm > 0) {
            session.spmSum += spm;
            session.spmCount++;
        }

        if (breathPhase === 1) { // INHALE
            if (session.currentPhase === 'EX') {
                if (session.currentInhaleSteps > 0 || session.currentExhaleSteps > 0) {
                    session.cycles.push({
                        in: session.currentInhaleSteps,
                        ex: session.currentExhaleSteps,
                        // 🔥 SIMPAN POLA TARGET AKTIF PADA SIKLUS INI
                        activeTargetPatternId: patternID 
                    });
                }
                session.currentInhaleSteps = 0;
                session.currentExhaleSteps = 0;
            }
            session.currentPhase = 'IN';
        } 
        else if (breathPhase === -1) { // EXHALE
            session.currentPhase = 'EX';
        }

        if (step === 1) {
            if (session.currentPhase === 'IN') session.currentInhaleSteps++;
            else if (session.currentPhase === 'EX') session.currentExhaleSteps++;
        }
    });

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

    for (const [sessionId, session] of Object.entries(sessionsMap)) {
        const durationMs = session.endTime - session.startTime;
        const durationSeconds = Math.max(0, Math.floor(durationMs / 1000));
        const minutes = Math.floor(durationSeconds / 60);
        const seconds = durationSeconds % 60;
        const formattedDuration = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;

        let matchCount = 0;
        let totalCycles = 0;
        let graphDataPoints = [];
        
        // 🔥 VARIABEL KANTONG UNTUK MENGHITUNG RATA-RATA BERDASARKAN POLA
        const averagesMap = {}; 

        session.cycles.forEach(cycle => {
            const actualPattern = detectActualPattern(cycle.in, cycle.ex);
            const targetPatternStr = convertPatternId(cycle.activeTargetPatternId);

            // 1. Hitung Kepatuhan Dinamis (Dicocokkan dengan pola target SAAT ITU)
            if (actualPattern === targetPatternStr || 
               (targetPatternStr === "3:2" && cycle.in === 3 && cycle.ex === 2) ||
               (targetPatternStr === "2:1" && cycle.in === 2 && cycle.ex === 1)) {
                matchCount++;
            }
            totalCycles++;

            // 2. Kumpulkan langkah untuk dihitung rata-ratanya (Dipisah per pola)
            if (!averagesMap[targetPatternStr]) {
                averagesMap[targetPatternStr] = { inSum: 0, exSum: 0, count: 0 };
            }
            averagesMap[targetPatternStr].inSum += cycle.in;
            averagesMap[targetPatternStr].exSum += cycle.ex;
            averagesMap[targetPatternStr].count++;

            // 3. Persiapkan Data Grafik (Kini disisipkan atribut 'pattern' untuk warna)
            graphDataPoints.push({
                y: mapPatternToY(actualPattern),
                targetPattern: targetPatternStr
            });
        });

        const compliance = totalCycles > 0 
            ? Math.round((matchCount / totalCycles) * 100) 
            : 0;

        // 🔥 UBAH RATA-RATA MENJADI STRING JSON UNTUK DISIMPAN DI PRISMA
        const finalAvgLrcObj = {};
        for (const [patt, stats] of Object.entries(averagesMap)) {
            const avgIn = (stats.inSum / stats.count).toFixed(1);
            const avgEx = (stats.exSum / stats.count).toFixed(1);
            finalAvgLrcObj[patt] = `${avgIn} : ${avgEx}`;
        }
        // Contoh Output: '{"3:2": "3.1 : 2.0", "2:1": "2.0 : 1.1"}'
        const avgLrcJsonString = JSON.stringify(finalAvgLrcObj); 

        // Smoothing Grafik (Rata-rata pergeseran agar tidak tajam), tapi tetap simpan atribut pattern-nya
        let finalGraphData = [];
        for (let i = 0; i < graphDataPoints.length; i++) {
            let sumY = 0;
            let count = 0;
            for (let j = Math.max(0, i - 1); j <= Math.min(graphDataPoints.length - 1, i + 1); j++) {
                sumY += graphDataPoints[j].y;
                count++;
            }
            finalGraphData.push({
                y: parseFloat((sumY / count).toFixed(2)),
                pattern: graphDataPoints[i].targetPattern // Simpan identitas pola target di titik ini
            });
        }

        // Tentukan Judul Pola Sesi (Misal: Jika pakai 2 pola, akan jadi "3:2 & 2:1")
        const patternsArray = Array.from(session.targetPatternsUsed).map(id => convertPatternId(id));
        const sessionTargetPatternStr = patternsArray.join(" & ");

        analyzedSessions.push({
            sessionNumber: parseInt(sessionId),
            startDate: session.startDate, 
            targetPattern: sessionTargetPatternStr,
            duration: formattedDuration,
            avgSpm: session.spmCount > 0 ? Math.round(session.spmSum / session.spmCount) : 0,
            compliance: compliance,
            avgLrc: avgLrcJsonString, // Data sudah aman sebagai String Json
            rawLrcData: finalGraphData // Data sudah berupa array Objek dengan properti 'pattern'
        });
    }

    return analyzedSessions;
};