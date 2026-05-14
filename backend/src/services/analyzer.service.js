/**
 * analyzer.service.js
 * Fungsi untuk menganalisis data sensor dari ESP32/Mobile
 */

export const analyzeRunData = (rawData, targetPattern) => {
    // 1. PARSING: Mengubah string CSV dari ESP32 menjadi array objek
    // Format dari ESP32: timestamp,breathPhase,step,spm,patternID;
    if (!rawData || typeof rawData !== 'string') return null;

    const rawSamples = rawData.split(';')
        .filter(row => row.trim() !== '' && row !== 'EOF')
        .map(row => {
            const cols = row.split(',');
            return {
                timestamp: parseInt(cols[0]),
                breath: parseInt(cols[1]),    // 1 = Inhale, -1 = Exhale
                step: parseInt(cols[2]),      // 1 = Ada langkah, 0 = Tidak
                spm: parseInt(cols[3]),       // Nilai SPM saat itu
                patternId: parseInt(cols[4])  // ID Pola dari alat (0 atau 1)
            };
        });

    if (rawSamples.length === 0) return null;

    let totalSpm = 0, validSpmCount = 0;
    let correctCycles = 0, totalCycles = 0;
    let cycles = []; 

    // MAP RITME: Menggunakan 7 level standar untuk grafik
    const patternMap = {
        "1:1": 1, 
        "2:1": 2, 
        "2:2": 3, 
        "3:2": 4, 
        "3:3": 5, 
        "4:3": 6, 
        "4:4": 7
    };
    
    // Level target berdasarkan label ("3:2" -> level 4)
    const targetY = patternMap[targetPattern] || 4; 

    // 2. DEBOUNCE FILTER: Menghilangkan noise/lonjakan sesaat pada sensor napas
    let smoothedSamples = JSON.parse(JSON.stringify(rawSamples)); 
    for (let i = 1; i < smoothedSamples.length - 1; i++) {
        if (smoothedSamples[i].breath !== smoothedSamples[i-1].breath &&
            smoothedSamples[i].breath !== smoothedSamples[i+1].breath) {
            // Jika fase napas berubah hanya dalam 1 sample, anggap noise dan timpa
            smoothedSamples[i].breath = smoothedSamples[i-1].breath;
        }
    }

    let currentPhase = smoothedSamples[0].breath;
    let stepsInCurrentPhase = 0;
    let inhaleSteps = 0, exhaleSteps = 0;

    smoothedSamples.forEach((sample, index) => {
        // Akumulasi SPM untuk rata-rata
        if (sample.spm > 0) {
            totalSpm += sample.spm;
            validSpmCount++;
        }

        // Hitung langkah dalam fase saat ini
        if (sample.step === 1) {
            stepsInCurrentPhase++;
        }

        // Deteksi perubahan fase (Inhale -> Exhale atau sebaliknya)
        if (sample.breath !== currentPhase || index === smoothedSamples.length - 1) {
            if (currentPhase === 1) {
                inhaleSteps = stepsInCurrentPhase;
            } else {
                exhaleSteps = stepsInCurrentPhase;

                // Satu siklus lengkap terdeteksi (Inhale + Exhale)
                if (inhaleSteps + exhaleSteps >= 2) {
                    totalCycles++;
                    const detectedPattern = `${inhaleSteps}:${exhaleSteps}`;
                    let detectedY = 0;

                    const totalStepsInCycle = inhaleSteps + exhaleSteps;

                    // Mapping pola yang terdeteksi ke level 1-7
                    if (patternMap[detectedPattern]) {
                        detectedY = patternMap[detectedPattern];
                    } else {
                        // Pendekatan rasio jika pola tidak standar (pembulatan)
                        if (totalStepsInCycle >= 8) detectedY = 7;      // 4:4
                        else if (totalStepsInCycle === 7) detectedY = 6;// 4:3
                        else if (totalStepsInCycle === 6) detectedY = 5;// 3:3
                        else if (totalStepsInCycle === 5) detectedY = 4;// 3:2
                        else if (totalStepsInCycle === 4) detectedY = 3;// 2:2
                        else if (totalStepsInCycle === 3) detectedY = 2;// 2:1
                        else detectedY = 1;                             // 1:1
                    }

                    // Cek kepatuhan terhadap target
                    if (detectedY === targetY) { 
                        correctCycles++; 
                    }

                    // Simpan data siklus untuk grafik
                    cycles.push({
                        y: detectedY,
                        label: detectedPattern
                    });
                }
            }
            // Reset untuk fase berikutnya
            currentPhase = sample.breath;
            stepsInCurrentPhase = 0;
        }
    });

    // 3. SMOOTHING GRAFIK: Menggunakan Moving Average agar garis tidak patah-patah
    let finalGraphData = [];
    for (let i = 0; i < cycles.length; i++) {
        let sumY = 0;
        let count = 0;
        for (let j = Math.max(0, i - 1); j <= Math.min(cycles.length - 1, i + 1); j++) {
            sumY += cycles[j].y;
            count++;
        }
        // Kita hanya mengambil nilai Y (level 1-7) untuk dikirim ke Flutter Painter
        finalGraphData.push(parseFloat((sumY / count).toFixed(2)));
    }

    // 4. KALKULASI DURASI
    const firstTs = smoothedSamples[0].timestamp;
    const lastTs = smoothedSamples[smoothedSamples.length - 1].timestamp;
    const durationSeconds = Math.floor((lastTs - firstTs) / 1000000);

    const minutes = Math.floor(durationSeconds / 60);
    const seconds = durationSeconds % 60;
    const formattedDuration = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;

    // 5. HASIL AKHIR
    return {
        duration: formattedDuration, // Mengirim format "MM:SS" sesuai permintaan controller
        avgSpm: validSpmCount > 0 ? Math.round(totalSpm / validSpmCount) : 0,
        compliance: totalCycles > 0 ? Math.round((correctCycles / totalCycles) * 100) : 0,
        graphData: finalGraphData // Array angka level (misal: [4, 4.2, 3.8, ...])
    };
};