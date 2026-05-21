// bio_scanner.js
// Javascript port of the Biometric Scanner Engine

class BioScanner {
    constructor() {
        this.spriteFeatures = null;
        this.isInitialized = false;
    }

    async initialize() {
        if (this.isInitialized) return;
        try {
            const resp = await fetch('assets/ml/sprite_features.json');
            this.spriteFeatures = await resp.json();
            this.isInitialized = true;
        } catch (e) {
            console.error("BioScanner init failed:", e);
        }
    }

    _rgbToHsv(r, g, b) {
        let rf = r / 255.0, gf = g / 255.0, bf = b / 255.0;
        let maxV = Math.max(rf, gf, bf);
        let minV = Math.min(rf, gf, bf);
        let d = maxV - minV;
        let h = 0;
        if (d !== 0) {
            if (maxV === rf) h = (gf - bf) / d + (gf < bf ? 6 : 0);
            else if (maxV === gf) h = (bf - rf) / d + 2;
            else h = (rf - gf) / d + 4;
            h /= 6;
        }
        return [h * 360, maxV === 0 ? 0 : d / maxV, maxV];
    }

    _detectBackgroundAndGetMask(imgData, width, height) {
        const mask = new Array(width * height).fill(true);
        const prototypes = [];
        const samples = [
            [0, 0], [width - 1, 0], [0, height - 1], [width - 1, height - 1],
            [Math.floor(width / 2), 0], [Math.floor(width / 2), height - 1],
            [0, Math.floor(height / 2)], [width - 1, Math.floor(height / 2)]
        ];

        const getPixel = (x, y) => {
            const i = (y * width + x) * 4;
            return [imgData[i], imgData[i+1], imgData[i+2]];
        };

        for (const s of samples) {
            prototypes.push(getPixel(s[0], s[1]));
        }

        const centerX = width / 2.0;
        const centerY = height / 2.0;
        const maxDist = Math.sqrt(Math.pow(centerX, 2) + Math.pow(centerY, 2));

        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                const [r, g, b] = getPixel(x, y);
                let minStatsDist = 1000.0;
                
                for (const bp of prototypes) {
                    const d = Math.sqrt(
                        Math.pow(r - bp[0], 2) * 0.299 +
                        Math.pow(g - bp[1], 2) * 0.587 +
                        Math.pow(b - bp[2], 2) * 0.114
                    );
                    if (d < minStatsDist) minStatsDist = d;
                }

                const distFromCenter = Math.sqrt(Math.pow(x - centerX, 2) + Math.pow(y - centerY, 2)) / maxDist;
                
                let threshold;
                if (distFromCenter < 0.45) threshold = 6.0;
                else if (distFromCenter < 0.65) threshold = 6.0 + Math.pow((distFromCenter - 0.45) * 5.0, 2) * 20.0;
                else threshold = 26.0 + Math.pow((distFromCenter - 0.65) * 3.0, 2) * 120.0;

                if (minStatsDist < threshold) {
                    mask[y * width + x] = false;
                }
            }
        }
        return mask;
    }

    _calculateSymmetry(imgData, mask, width, height, minX, maxX, minY, maxY) {
        let hMatches = 0, vMatches = 0, hTotal = 0, vTotal = 0;
        
        const getPixel = (x, y) => {
            const i = (y * width + x) * 4;
            return [imgData[i], imgData[i+1], imgData[i+2]];
        };

        // Horizontal
        for (let y = minY; y <= maxY; y++) {
            for (let x = minX; x <= Math.floor((minX + maxX) / 2); x++) {
                const x2 = maxX - (x - minX);
                if (x2 < minX || x2 > maxX) continue;
                const p1 = getPixel(x, y), p2 = getPixel(x2, y);
                hTotal++;
                const d = Math.abs(p1[0] - p2[0]) + Math.abs(p1[1] - p2[1]) + Math.abs(p1[2] - p2[2]);
                if (d < 100) hMatches++;
            }
        }

        // Vertical
        for (let x = minX; x <= maxX; x++) {
            for (let y = minY; y <= Math.floor((minY + maxY) / 2); y++) {
                const y2 = maxY - (y - minY);
                if (y2 < minY || y2 > maxY) continue;
                const p1 = getPixel(x, y), p2 = getPixel(x, y2);
                vTotal++;
                const d = Math.abs(p1[0] - p2[0]) + Math.abs(p1[1] - p2[1]) + Math.abs(p1[2] - p2[2]);
                if (d < 100) vMatches++;
            }
        }

        return [
            hTotal > 0 ? hMatches / hTotal : 0.5,
            vTotal > 0 ? vMatches / vTotal : 0.5
        ];
    }

    async extractFeatures(imgElement) {
        const canvas = document.createElement('canvas');
        canvas.width = 128;
        canvas.height = 128;
        const ctx = canvas.getContext('2d');
        
        // Letterbox resize to 128x128
        const size = Math.max(imgElement.width, imgElement.height);
        const scale = 128 / size;
        const dw = imgElement.width * scale;
        const dh = imgElement.height * scale;
        const dx = (128 - dw) / 2;
        const dy = (128 - dh) / 2;
        
        ctx.fillStyle = 'rgba(0,0,0,0)';
        ctx.fillRect(0, 0, 128, 128);
        ctx.drawImage(imgElement, dx, dy, dw, dh);
        
        const imgData = ctx.getImageData(0, 0, 128, 128).data;
        const width = 128, height = 128;
        
        // Detect if has alpha transparency
        let hasAlpha = false;
        for (let i = 3; i < imgData.length; i += 4) {
            if (imgData[i] < 128) { hasAlpha = true; break; }
        }

        let mask;
        if (hasAlpha) {
            mask = new Array(width * height).fill(true);
            for (let i = 0; i < width * height; i++) {
                mask[i] = imgData[i * 4 + 3] >= 128;
            }
        } else {
            mask = this._detectBackgroundAndGetMask(imgData, width, height);
        }

        let objectPixelCount = 0;
        let minX = width, maxX = 0, minY = height, maxY = 0;
        const finalHueBins = {};
        for (let i = 0; i < 36; i++) finalHueBins[`h${i * 10}`] = 0;
        finalHueBins['hWhite'] = 0;
        finalHueBins['hBlack'] = 0;
        finalHueBins['hGrey'] = 0;

        let totalBrightness = 0, totalSaturation = 0;
        const colorCounts = {};

        const getPixel = (x, y) => {
            const i = (y * width + x) * 4;
            return [imgData[i], imgData[i+1], imgData[i+2]];
        };

        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                if (!mask[y * width + x]) continue;
                objectPixelCount++;
                if (x < minX) minX = x;
                if (x > maxX) maxX = x;
                if (y < minY) minY = y;
                if (y > maxY) maxY = y;

                const [r, g, b] = getPixel(x, y);
                const [hue, sat, val] = this._rgbToHsv(r, g, b);

                if (val < 0.15) finalHueBins['hBlack']++;
                else if (sat < 0.15) {
                    if (val > 0.8) finalHueBins['hWhite']++;
                    else finalHueBins['hGrey']++;
                } else {
                    const bin = Math.max(0, Math.min(35, Math.floor(hue / 10)));
                    finalHueBins[`h${bin * 10}`]++;
                }
                totalSaturation += sat;
                totalBrightness += val;
                
                const q = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
                colorCounts[q] = (colorCounts[q] || 0) + 1;
            }
        }

        if (objectPixelCount === 0) return null;

        for (const k in finalHueBins) finalHueBins[k] /= objectPixelCount;
        
        const [hSym, vSym] = this._calculateSymmetry(imgData, mask, width, height, minX, maxX, minY, maxY);

        // Core Solidity
        let corePixels = 0;
        const cMinX = minX + Math.floor((maxX - minX) * 0.25);
        const cMaxX = maxX - Math.floor((maxX - minX) * 0.25);
        const cMinY = minY + Math.floor((maxY - minY) * 0.25);
        const cMaxY = maxY - Math.floor((maxY - minY) * 0.25);
        for (let y = cMinY; y <= cMaxY; y++) {
            for (let x = cMinX; x <= cMaxX; x++) {
                if (mask[y * width + x]) corePixels++;
            }
        }
        const coreSolidity = corePixels / Math.max(1, (cMaxX - cMinX + 1) * (cMaxY - cMinY + 1));

        let topHalf = 0, bottomHalf = 0;
        const topThresh = Math.floor(height * 0.4);
        const botThresh = Math.floor(height * 0.6);
        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                if (!mask[y * width + x]) continue;
                if (y < topThresh) topHalf++;
                if (y > botThresh) bottomHalf++;
            }
        }

        // Edge density
        let edgePixels = 0, totalEdgeCheck = 0;
        for (let y = 1; y < height - 1; y++) {
            for (let x = 1; x < width - 1; x++) {
                if (!mask[y * width + x]) continue;
                const p = getPixel(x, y), pR = getPixel(x+1, y), pD = getPixel(x, y+1);
                const lum = (p[0]+p[1]+p[2])/3, lumR = (pR[0]+pR[1]+pR[2])/3, lumD = (pD[0]+pD[1]+pD[2])/3;
                if (Math.abs(lum - lumR) + Math.abs(lum - lumD) > 40) edgePixels++;
                totalEdgeCheck++;
            }
        }

        // Just basic features for JS fallback, matching database signature
        return {
            hueBins: finalHueBins,
            avgBrightness: totalBrightness / objectPixelCount,
            avgSaturation: totalSaturation / objectPixelCount,
            aspectRatio: (maxX - minX + 1) / (maxY - minY + 1),
            solidity: objectPixelCount / ((maxX - minX + 1) * (maxY - minY + 1)),
            verticalSymmetry: vSym,
            horizontalSymmetry: hSym,
            bilateralSym: hSym,
            localSymmetry: hSym, // approximate
            edgeDensity: totalEdgeCheck > 0 ? edgePixels / totalEdgeCheck : 0,
            directionalEdgeBias: 0.0,
            coreSolidity: coreSolidity,
            bottomHeavyBias: bottomHalf / objectPixelCount,
            maxWidthRowBias: 0.5,
            maxHeightColBias: 0.5,
            bottomCenterDensity: 0.0,
            cornerDensity: 0.0,
            diagonalDensity: 0.0,
            lowerQuadrantSymmetry: hSym,
            horizontalCentroidShift: 0.5,
            convexHullRatio: objectPixelCount / ((maxX - minX + 1) * (maxY - minY + 1) / 2.0),
            verticalMassDistribution: 0.2,
            colorGranularity: 0.0,
            fringeDensity: 0.1,
            verticalThinning: 0.5,
            colorClustering: 0.0,
            yGradient: 0.5,
            widthVariance: 0.0,
            shellIndex: 0.0,
            radialOverlap: 0.0,
            yCentroid: 0.5,
            jaggedness: 0.1,
            topThirdDensity: topHalf / objectPixelCount,
            limbDensity: 0.0,
            animalClass: 'unknown'
        };
    }

    _featureSimilarity(f1, f2, targetClass) {
        // Color match
        let globalColorMatch = 0;
        for (const [key, val] of Object.entries(f1.hueBins)) {
            if (val === 0) continue;
            if (['hWhite', 'hBlack', 'hGrey'].includes(key)) {
                globalColorMatch += Math.min(val, f2.hueBins[key] || 0);
                continue;
            }
            const hue = parseInt(key.replace('h', ''));
            if (isNaN(hue)) continue;
            const exact = f2.hueBins[key] || 0;
            const prevHue = (hue - 10 + 360) % 360;
            const nextHue = (hue + 10) % 360;
            const prevVal = f2.hueBins[`h${prevHue}`] || 0;
            const nextVal = f2.hueBins[`h${nextHue}`] || 0;
            globalColorMatch += Math.min(val, exact + prevVal * 0.4 + nextVal * 0.4);
        }
        const colorScore = Math.min(1.0, globalColorMatch);

        // Shape
        const aspectDiff = Math.abs(Math.log(f1.aspectRatio || 1) - Math.log(f2.aspectRatio || 1));
        const solidityDiff = Math.abs(f1.solidity - f2.solidity);
        const shapeScore = Math.pow(Math.max(0, 1 - aspectDiff * 0.6), 1.5) * 0.6 + 
                           Math.pow(Math.max(0, 1 - solidityDiff * 1.6), 1.5) * 0.4;

        // Pattern
        const symDiff = Math.abs(f1.bilateralSym - f2.bilateralSym) + Math.abs(f1.localSymmetry - f2.localSymmetry);
        const edgeDiff = Math.abs(f1.edgeDensity - f2.edgeDensity);
        const patternScore = Math.max(0, 1 - symDiff/2.0) * 0.4 + Math.max(0, 1 - edgeDiff) * 0.6;

        // Shade & Saturation
        const shadeScore = Math.max(0, 1 - Math.abs(f1.avgBrightness - f2.avgBrightness));
        const satScore = Math.max(0, 1 - Math.abs(f1.avgSaturation - f2.avgSaturation));
        const finalShadeScore = shadeScore * 0.7 + satScore * 0.3;

        // Structure
        const structScore = Math.max(0, 1 - Math.abs(f1.coreSolidity - f2.coreSolidity)) * 0.5 + 
                            Math.max(0, 1 - Math.abs(f1.convexHullRatio - f2.convexHullRatio)) * 0.5;

        // Combine
        const conf = colorScore * 0.35 + shapeScore * 0.25 + patternScore * 0.15 + finalShadeScore * 0.15 + structScore * 0.10;
        return conf;
    }

    async scan(imageElement, onProgress) {
        if (onProgress) onProgress("Initializing Scanner...", 10);
        await this.initialize();
        
        if (onProgress) onProgress("Extracting Signatures...", 30);
        const inputFeature = await this.extractFeatures(imageElement);
        if (!inputFeature) return null;

        if (onProgress) onProgress("Matching Bio-Data...", 60);
        const results = [];
        const entries = Object.entries(this.spriteFeatures);
        
        let i = 0;
        for (const [name, targetFeature] of entries) {
            i++;
            if (i % 100 === 0 && onProgress) onProgress("Matching Bio-Data...", 60 + (30 * (i / entries.length)));
            
            const conf = this._featureSimilarity(inputFeature, targetFeature, 'unknown');
            if (conf > 0.15) {
                results.push({ name, confidence: conf });
            }
        }

        if (onProgress) onProgress("Ranking Results...", 95);
        results.sort((a, b) => b.confidence - a.confidence);

        if (onProgress) onProgress("Complete", 100);
        return results.slice(0, 5);
    }
}

window.BioScannerService = new BioScanner();
