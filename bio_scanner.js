// bio_scanner.js
// Javascript port of the Biometric Scanner Engine
// Mathematically matches biometric_service.dart

class BioScanner {
    constructor() {
        this.spriteFeatures = null;
        this.isInitialized = false;
        this.organisms = [];
    }

    async initialize() {
        if (this.isInitialized) return;
        try {
            const [resp, orgsResp] = await Promise.all([
                fetch('assets/ml/sprite_features.json'),
                fetch('assets/Organisms.json')
            ]);
            this.spriteFeatures = await resp.json();
            
            let orgs = await orgsResp.json();
            try {
                const orgs2Resp = await fetch('assets/Organisms2.json');
                const orgs2 = await orgs2Resp.json();
                orgs = orgs.concat(orgs2);
            } catch(e) {}
            this.organisms = orgs;
            
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
        ctx.imageSmoothingEnabled = false;
        ctx.drawImage(imgElement, dx, dy, dw, dh);
        
        const imgData = ctx.getImageData(0, 0, 128, 128).data;
        const width = 128, height = 128;
        
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

        const getPixel = (x, y) => {
            const i = (y * width + x) * 4;
            return [imgData[i], imgData[i+1], imgData[i+2]];
        };

        const getPixelSafe = (x, y) => {
            if (x < 0 || x >= width || y < 0 || y >= height) return [0,0,0];
            return getPixel(x, y);
        };

        const finalHueBins = {};
        for (let i = 0; i < 36; i++) finalHueBins[`h${i * 10}`] = 0;
        finalHueBins['hWhite'] = 0;
        finalHueBins['hBlack'] = 0;
        finalHueBins['hGrey'] = 0;

        let totalBrightness = 0, totalSaturation = 0;
        const colorCounts = {};
        let objectPixelCount = 0;
        let minX = width, maxX = 0, minY = height, maxY = 0;

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

        // Spatial Hue Bins
        const spatialHueBins = {};
        for (let gy = 0; gy < 3; gy++) {
            for (let gx = 0; gx < 3; gx++) {
                const startX = minX + Math.floor(gx * (maxX - minX) / 3);
                const endX = gx === 2 ? maxX : minX + Math.floor((gx + 1) * (maxX - minX) / 3);
                const startY = minY + Math.floor(gy * (maxY - minY) / 3);
                const endY = gy === 2 ? maxY : minY + Math.floor((gy + 1) * (maxY - minY) / 3);
                let gridPix = 0;
                const gridHue = {};
                for (let y = startY; y <= endY; y++) {
                    for (let x = startX; x <= endX; x++) {
                        if (mask[y * width + x]) {
                            const p = getPixel(x, y);
                            const h = this._rgbToHsv(p[0], p[1], p[2])[0];
                            const bin = Math.max(0, Math.min(35, Math.floor(h / 10)));
                            gridHue[bin] = (gridHue[bin] || 0) + 1;
                            gridPix++;
                        }
                    }
                }
                for (const [bin, count] of Object.entries(gridHue)) {
                    spatialHueBins[`g${gx}${gy}_h${bin * 10}`] = gridPix > 0 ? count / gridPix : 0;
                }
            }
        }

        let significantBins = 0;
        for (const [key, val] of Object.entries(finalHueBins)) {
            if (val > 0.02) significantBins++;
        }
        const hueComplexity = significantBins / 39.0;

        let perimeter = 0, fringePixels = 0;
        for (let y = 1; y < height - 1; y++) {
            for (let x = 1; x < width - 1; x++) {
                if (!mask[y * width + x]) continue;
                if (!mask[(y - 1) * width + x] || !mask[(y + 1) * width + x] || 
                    !mask[y * width + x - 1] || !mask[y * width + x + 1]) {
                    perimeter++;
                    fringePixels++;
                }
            }
        }
        const compactness = (perimeter * perimeter) / objectPixelCount;
        const jaggedness = fringePixels / Math.sqrt(objectPixelCount);

        let topHalf = 0, bottomHalf = 0, topThirdPixels = 0;
        const topThreshold = Math.floor(height * 0.4);
        const bottomThreshold = Math.floor(height * 0.6);
        const topThirdY = minY + Math.floor((maxY - minY + 1) / 3);
        
        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                if (!mask[y * width + x]) continue;
                if (y < topThreshold) topHalf++;
                if (y > bottomThreshold) bottomHalf++;
                if (y <= topThirdY) topThirdPixels++;
            }
        }
        const vBias = (topHalf + bottomHalf) > 0 ? bottomHalf / (topHalf + bottomHalf) : 0.5;
        const topHeavyBias = topHalf / objectPixelCount;
        const bottomHeavyBias = bottomHalf / objectPixelCount;

        let limbPixels = 0;
        const insetX = Math.floor((maxX - minX + 1) * 0.2);
        const insetY = Math.floor((maxY - minY + 1) * 0.2);
        for (let y = minY; y <= maxY; y++) {
            for (let x = minX; x <= maxX; x++) {
                if (mask[y * width + x] && 
                   (x < minX + insetX || x > maxX - insetX || y < minY + insetY || y > maxY - insetY)) {
                    limbPixels++;
                }
            }
        }
        const limbDensity = limbPixels / objectPixelCount;

        let hEdges = 0, vEdges = 0;
        let edgePixels = 0, totalEdgeCheck = 0;
        for (let y = 1; y < height - 1; y++) {
            for (let x = 1; x < width - 1; x++) {
                if (!mask[y * width + x]) continue;
                const p = getPixel(x, y), pR = getPixel(x+1, y), pD = getPixel(x, y+1);
                const lum = (p[0]+p[1]+p[2])/3, lumR = (pR[0]+pR[1]+pR[2])/3, lumD = (pD[0]+pD[1]+pD[2])/3;
                if (Math.abs(lum - lumR) > 30) hEdges++;
                if (Math.abs(lum - lumD) > 30) vEdges++;
                
                if (Math.abs(lum - lumR) + Math.abs(lum - lumD) > 40) edgePixels++;
                totalEdgeCheck++;
            }
        }
        const directionalEdgeBias = (hEdges + vEdges) > 0 ? (hEdges - vEdges) / (hEdges + vEdges) : 0.0;
        const edgeDensity = totalEdgeCheck > 0 ? edgePixels / totalEdgeCheck : 0.0;

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

        let maxRowPixels = -1, maxRowY = minY, minRowWidth = maxX - minX + 1, maxRowWidth = 0;
        for (let y = minY; y <= maxY; y++) {
            let rowW = 0;
            for (let x = minX; x <= maxX; x++) {
                if (mask[y * width + x]) rowW++;
            }
            if (rowW > 0) {
                if (rowW > maxRowPixels) { maxRowPixels = rowW; maxRowY = y; }
                if (rowW < minRowWidth) minRowWidth = rowW;
                if (rowW > maxRowWidth) maxRowWidth = rowW;
            }
        }
        const maxWidthRowBias = (maxY > minY) ? (maxRowY - minY) / (maxY - minY) : 0.5;
        const verticalThinning = maxRowWidth > 0 ? minRowWidth / maxRowWidth : 0.0;

        let totalX = 0, totalY = 0;
        for (let y = minY; y <= maxY; y++) {
            for (let x = minX; x <= maxX; x++) {
                if (mask[y * width + x]) {
                    totalX += x;
                    totalY += y;
                }
            }
        }
        const centroidY = totalY / objectPixelCount;
        const horizontalCentroidShift = (maxX > minX) ? (totalX / objectPixelCount - minX) / (maxX - minX) : 0.5;
        const yCentroid = centroidY / height;

        const bcMinX = minX + Math.floor((maxX - minX) * 0.35);
        const bcMaxX = maxX - Math.floor((maxX - minX) * 0.35);
        const bcMinY = maxY - Math.floor((maxY - minY) * 0.3);
        let bcPixels = 0;
        for (let y = bcMinY; y <= maxY; y++) {
            for (let x = bcMinX; x <= bcMaxX; x++) {
                if (mask[y * width + x]) bcPixels++;
            }
        }
        const bottomCenterDensity = bcPixels / Math.max(1, (bcMaxX - bcMinX + 1) * (maxY - bcMinY + 1));

        const cornerW = Math.max(1, Math.floor((maxX - minX) * 0.2));
        const cornerH = Math.max(1, Math.floor((maxY - minY) * 0.2));
        let cornerPixels = 0;
        for (let y = minY; y < minY + cornerH; y++) {
            for (let x = minX; x < minX + cornerW; x++) if (mask[y * width + x]) cornerPixels++;
            for (let x = maxX - cornerW + 1; x <= maxX; x++) if (mask[y * width + x]) cornerPixels++;
        }
        for (let y = maxY - cornerH + 1; y <= maxY; y++) {
            for (let x = minX; x < minX + cornerW; x++) if (mask[y * width + x]) cornerPixels++;
            for (let x = maxX - cornerW + 1; x <= maxX; x++) if (mask[y * width + x]) cornerPixels++;
        }
        const cornerDensity = cornerPixels / Math.max(1, cornerW * cornerH * 4.0);

        let diagPixels = 0, diagArea = 0;
        const boxW = Math.max(1, maxX - minX);
        const boxH = Math.max(1, maxY - minY);
        for (let y = minY; y <= maxY; y++) {
            for (let x = minX; x <= maxX; x++) {
                const nx = (x - minX) / boxW;
                const ny = (y - minY) / boxH;
                if (Math.abs(nx - ny) < 0.1 || Math.abs(nx - (1 - ny)) < 0.1) {
                    diagArea++;
                    if (mask[y * width + x]) diagPixels++;
                }
            }
        }
        const diagonalDensity = diagArea > 0 ? diagPixels / diagArea : 0.0;
        const midX = minX + Math.floor((maxX - minX) / 2);

        let maxColH = 0;
        let maxColX = minX;
        for (let x = minX; x <= maxX; x++) {
            let colH = 0;
            for (let y = minY; y <= maxY; y++) {
                if (mask[y * width + x]) colH++;
            }
            if (colH > maxColH) { maxColH = colH; maxColX = x; }
        }
        const maxHeightColBias = (maxX > minX) ? (maxColX - minX) / (maxX - minX) : 0.5;

        let sumYDist = 0;
        for (let y = minY; y <= maxY; y++) {
            for (let x = minX; x <= maxX; x++) {
                if (mask[y * width + x]) {
                    sumYDist += Math.pow(y - centroidY, 2);
                }
            }
        }
        const verticalMassDistribution = (maxY > minY) ? Math.sqrt(sumYDist / objectPixelCount) / (maxY - minY) : 0.0;

        const bilateralSym = hSym;

        let qMatches = 0, qTotal = 0;
        const midY = minY + Math.floor((maxY - minY) / 2);
        for (let qy = 0; qy < 2; qy++) {
            for (let qx = 0; qx < 2; qx++) {
                const qXStart = qx === 0 ? minX : midX;
                const qXEnd = qx === 0 ? midX : maxX;
                const qYStart = qy === 0 ? minY : midY;
                const qYEnd = qy === 0 ? midY : maxY;
                const qSym = this._calculateSymmetry(imgData, mask, width, height, qXStart, qXEnd, qYStart, qYEnd);
                qMatches += Math.floor(qSym[0] * 100) + Math.floor(qSym[1] * 100);
                qTotal += 200;
            }
        }
        const localSymmetry = qTotal > 0 ? qMatches / qTotal : 0.5;

        const lowerSym = this._calculateSymmetry(imgData, mask, width, height, minX, maxX, midY, maxY);
        const lowerQuadrantSymmetry = lowerSym[0];

        return {
            hueBins: finalHueBins,
            spatialHueBins: spatialHueBins,
            avgBrightness: totalBrightness / objectPixelCount,
            avgSaturation: totalSaturation / objectPixelCount,
            aspectRatio: (maxX - minX + 1) / (maxY - minY + 1),
            solidity: objectPixelCount / ((maxX - minX + 1) * (maxY - minY + 1)),
            verticalSymmetry: vSym,
            horizontalSymmetry: hSym,
            edgeDensity: edgeDensity,
            verticalBias: vBias,
            topHeavyBias: topHeavyBias,
            hueComplexity: hueComplexity,
            compactness: compactness,
            limbDensity: limbDensity,
            directionalEdgeBias: directionalEdgeBias,
            coreSolidity: coreSolidity,
            bottomHeavyBias: bottomHeavyBias,
            maxWidthRowBias: maxWidthRowBias,
            maxHeightColBias: maxHeightColBias,
            bottomCenterDensity: bottomCenterDensity,
            cornerDensity: cornerDensity,
            diagonalDensity: diagonalDensity,
            lowerQuadrantSymmetry: lowerQuadrantSymmetry,
            horizontalCentroidShift: horizontalCentroidShift,
            convexHullRatio: objectPixelCount / (((maxX - minX + 1) * (maxY - minY + 1)) / 2.0),
            verticalMassDistribution: verticalMassDistribution,
            colorGranularity: 0.0,
            fringeDensity: fringePixels / objectPixelCount,
            verticalThinning: verticalThinning,
            localSymmetry: localSymmetry,
            colorClustering: 0.0,
            yGradient: (maxY > minY) ? (centroidY - minY) / (maxY - minY) : 0.5,
            widthVariance: 0.0,
            shellIndex: 0.0,
            radialOverlap: 0.0,
            yCentroid: yCentroid,
            jaggedness: jaggedness,
            topThirdDensity: topThirdPixels / objectPixelCount,
            bilateralSym: bilateralSym
        };
    }

    _featureSimilarity(f1, f2, targetOrg) {
        let globalColorMatch = 0;
        for (const [key, val] of Object.entries(f1.hueBins)) {
            if (val === 0) continue;
            if (key === 'hWhite' || key === 'hBlack' || key === 'hGrey') {
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
            const effectiveF2 = exact + (prevVal * 0.4) + (nextVal * 0.4);
            globalColorMatch += Math.min(val, effectiveF2);
        }
        const colorScore = Math.max(0, Math.min(1.0, globalColorMatch));

        let spatialScore = colorScore;
        if (f1.spatialHueBins && f2.spatialHueBins) {
            let spatialSum = 0;
            let activeCells = 0;
            for (const [key, val] of Object.entries(f1.spatialHueBins)) {
                if (f2.spatialHueBins[key] !== undefined) {
                    spatialSum += Math.min(val, f2.spatialHueBins[key]);
                }
                activeCells++;
            }
            if (activeCells > 0) {
                spatialScore = Math.max(0, Math.min(1.0, spatialSum / activeCells));
            }
        }

        const aspectDiff = Math.abs(Math.log(f1.aspectRatio || 1) - Math.log(f2.aspectRatio || 1));
        const solidityDiff = Math.abs(f1.solidity - f2.solidity);
        const shapeScore = Math.pow(Math.max(0, 1.0 - (aspectDiff * 0.6)), 1.5) * 0.6 +
                           Math.pow(Math.max(0, 1.0 - (solidityDiff * 1.6)), 1.5) * 0.4;

        const symDiff = Math.abs(f1.bilateralSym - f2.bilateralSym) + Math.abs(f1.localSymmetry - f2.localSymmetry);
        const edgeDiff = Math.abs(f1.edgeDensity - f2.edgeDensity);
        const biasDiff = Math.abs(f1.directionalEdgeBias - f2.directionalEdgeBias);

        let patternImportance = 0.6;
        if (f1.edgeDensity > 0.12 && f2.edgeDensity > 0.12) {
            patternImportance = 0.8;
        }

        const patternScore = Math.max(0, 1.0 - (symDiff / 2.0)) * (1.0 - patternImportance) +
            (Math.max(0, 1.0 - edgeDiff) * 0.7 + Math.max(0, 1.0 - biasDiff) * 0.3) * patternImportance;

        const shadeScore = Math.max(0, 1.0 - Math.abs(f1.avgBrightness - f2.avgBrightness));
        const satScore = Math.max(0, 1.0 - Math.abs(f1.avgSaturation - f2.avgSaturation));
        const finalShadeScore = Math.max(0, shadeScore * 0.7 + satScore * 0.3);

        const structScore = (1.0 - Math.abs(f1.coreSolidity - f2.coreSolidity)) * 0.3 +
                            (1.0 - Math.abs(f1.convexHullRatio - f2.convexHullRatio)) * 0.3 +
                            (1.0 - Math.abs(f1.radialOverlap - f2.radialOverlap)) * 0.2 +
                            (1.0 - Math.abs(f1.shellIndex - f2.shellIndex)) * 0.2;

        const poseScore = (1.0 - Math.abs(f1.bottomHeavyBias - f2.bottomHeavyBias)) * 0.15 +
                          (1.0 - Math.abs(f1.maxWidthRowBias - f2.maxWidthRowBias)) * 0.15 +
                          (1.0 - Math.abs(f1.maxHeightColBias - f2.maxHeightColBias)) * 0.15 +
                          (1.0 - Math.abs(f1.yCentroid - f2.yCentroid)) * 0.15 +
                          (1.0 - Math.abs(f1.horizontalCentroidShift - f2.horizontalCentroidShift)) * 0.15 +
                          (1.0 - Math.abs(f1.verticalMassDistribution - f2.verticalMassDistribution)) * 0.15 +
                          (1.0 - Math.abs(f1.verticalThinning - f2.verticalThinning)) * 0.1;

        const detailScore = (1.0 - Math.abs(f1.colorGranularity - f2.colorGranularity)) * 0.2 +
                            (1.0 - Math.abs(f1.fringeDensity - f2.fringeDensity)) * 0.2 +
                            Math.max(0, Math.min(1.0, 1.0 - Math.abs(f1.jaggedness - f2.jaggedness) * 0.1)) * 0.15 +
                            (1.0 - Math.abs(f1.colorClustering - f2.colorClustering)) * 0.15 +
                            (1.0 - Math.abs(f1.widthVariance - f2.widthVariance)) * 0.15 +
                            (1.0 - Math.abs(f1.topThirdDensity - f2.topThirdDensity)) * 0.15;

        const advSymScore = (1.0 - Math.abs(f1.lowerQuadrantSymmetry - f2.lowerQuadrantSymmetry)) * 0.3 +
                            (1.0 - Math.abs(f1.localSymmetry - f2.localSymmetry)) * 0.3 +
                            (1.0 - Math.abs(f1.bilateralSym - f2.bilateralSym)) * 0.4;

        // Class Gate
        let classScore = 1.0;
        const detectedTaxon = 'unknown'; // we don't have taxonomy ai in JS fallback
        
        let structGate = 1.0;
        const targetClass = (targetOrg.class || targetOrg.animal_class || 'unknown').toLowerCase().trim();
        if (targetClass === 'fish') {
            if (f1.limbDensity > 0.12 || f1.jaggedness > 0.35) structGate *= 0.1;
        }
        if (targetClass === 'mammal' || targetClass === 'reptile') {
            if (f1.limbDensity < 0.04 && f1.jaggedness < 0.15) structGate *= 0.2;
        }

        const visualWeightColor = 0.10;
        const visualWeightSpatial = 0.05;
        const visualWeightShape = 0.20;
        const visualWeightPattern = 0.10;
        const visualWeightShade = 0.05;
        const visualWeightStruct = 0.30;
        const visualWeightPose = 0.15;
        const visualWeightDetail = 0.00;
        const visualWeightAdvSym = 0.05;

        const visualConfidence = Math.max(0, Math.min(1.0, 
            colorScore * visualWeightColor +
            spatialScore * visualWeightSpatial +
            finalShadeScore * visualWeightShade +
            shapeScore * visualWeightShape +
            patternScore * visualWeightPattern +
            structScore * visualWeightStruct +
            poseScore * visualWeightPose +
            detailScore * visualWeightDetail +
            advSymScore * visualWeightAdvSym
        ));

        return Math.max(0, Math.min(1.0, visualConfidence * classScore * structGate));
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
            
            const targetOrg = this.organisms.find(o => o.name === name) || {};
            const conf = this._featureSimilarity(inputFeature, targetFeature, targetOrg);
            
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
