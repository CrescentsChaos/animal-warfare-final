import sqlite3
import json
import os

db_path = os.path.join('assets', 'ml', 'sprite_features.db')
out_path = os.path.join('assets', 'ml', 'sprite_features.json')

conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

cursor.execute("SELECT * FROM organism_features")
rows = cursor.fetchall()

features = {}
for row in rows:
    data = dict(row)
    # Parse JSON strings to objects where needed
    data['hue_bins'] = json.loads(data['hue_bins'])
    data['spatial_hue_bins'] = json.loads(data['spatial_hue_bins']) if data['spatial_hue_bins'] else None
    data['dominant_colors'] = json.loads(data['dominant_colors']) if data['dominant_colors'] else []
    
    # Store in dict by organism_name
    features[data['organism_name']] = {
        "organismName": data["organism_name"],
        "hueBins": data["hue_bins"],
        "spatialHueBins": data["spatial_hue_bins"],
        "dominantColors": data["dominant_colors"],
        "avgBrightness": data["avg_brightness"],
        "avgSaturation": data["avg_saturation"],
        "aspectRatio": data["aspect_ratio"],
        "solidity": data["solidity"],
        "verticalSymmetry": data["vertical_symmetry"],
        "horizontalSymmetry": data["horizontal_symmetry"],
        "edgeDensity": data["edge_density"],
        "coreSolidity": data["core_solidity"],
        "bottomHeavyBias": data["bottom_heavy_bias"],
        "maxWidthRowBias": data["max_width_row_bias"],
        "maxHeightColBias": data["max_height_col_bias"],
        "bottomCenterDensity": data["bottom_center_density"],
        "cornerDensity": data["corner_density"],
        "diagonalDensity": data["diagonal_density"],
        "lowerQuadrantSymmetry": data["lower_quadrant_symmetry"],
        "horizontalCentroidShift": data["horizontal_centroid_shift"],
        "convexHullRatio": data["convex_hull_ratio"],
        "verticalMassDistribution": data["vertical_mass_distribution"],
        "colorGranularity": data["color_granularity"],
        "fringeDensity": data["fringe_density"],
        "verticalThinning": data["vertical_thinning"],
        "localSymmetry": data["local_symmetry"],
        "colorClustering": data["color_clustering"],
        "yGradient": data["y_gradient"],
        "widthVariance": data["width_variance"],
        "shellIndex": data["shell_index"],
        "radialOverlap": data["radial_overlap"],
        "yCentroid": data["y_centroid"],
        "jaggedness": data["jaggedness"],
        "topThirdDensity": data["top_third_density"],
        "bilateralSym": data["bilateral_sym"],
        "verticalBias": data["vertical_bias"],
        "topHeavyBias": data["top_heavy_bias"],
        "hueComplexity": data["hue_complexity"],
        "compactness": data["compactness"],
        "limbDensity": data["limb_density"],
        "directionalEdgeBias": data["directional_edge_bias"],
        "animalClass": data["animal_class"],
    }

with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(features, f, separators=(',', ':'))

print(f"Exported {len(features)} features to {out_path}")
