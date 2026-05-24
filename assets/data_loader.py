import sqlite3
import pandas as pd
import os

def create_manifest(db_path, img_dir):
    conn = sqlite3.connect(db_path)
    # Adjust 'Animals' to your actual table name
    df = pd.read_sql_query("SELECT name, class, family FROM Animals", conn)
    conn.close()

    # Create full file paths
    df['filepath'] = df['name'].apply(lambda x: os.path.join(img_dir, f"{x}.png"))
    
    # Filter out records where the image file doesn't exist
    df = df[df['filepath'].apply(os.path.exists)]
    
    return df

if __name__ == "__main__":
    data = create_manifest('assets/Organisms.db', 'assets/sprites/')
    data.to_csv('assets/manifest.csv', index=False)