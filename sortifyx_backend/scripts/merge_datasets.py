"""
Merge TrashNet (6 classes) + Organic (1 class) into a single YOLOv8 dataset
with the SortifyX 7-class scheme.
"""
import shutil
from pathlib import Path

# ----------------------------------------------------------------------
# EDIT THESE TWO PATHS to match where you extracted the Roboflow zips:
# ----------------------------------------------------------------------
TRASHNET_DIR = r"C:\Users\user\Downloads\Y3S2 LAB\FYP2\TrashNet- A set of annotated images of trash that can be used for object detection.v20i.yolov8"
ORGANIC_DIR  = r"C:\Users\user\Downloads\Y3S2 LAB\FYP2\Organic.v1i.yolov8"
# ----------------------------------------------------------------------

OUTPUT_DIR = Path(__file__).resolve().parent.parent / "dataset"

TRASHNET_MAP = {0: 4, 1: 2, 2: 1, 3: 3, 4: 0, 5: 6}
ORGANIC_MAP = {0: 5}

TARGET_NAMES = ['plastic', 'metal', 'glass', 'paper', 'cardboard', 'organic', 'non_recyclable']
SPLITS = ('train', 'valid', 'test')


def remap_label_file(src_path, dst_path, class_map):
    lines_out = []
    with open(src_path, 'r') as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) < 5:
                continue
            try:
                old_id = int(parts[0])
            except ValueError:
                continue
            if old_id not in class_map:
                continue
            parts[0] = str(class_map[old_id])
            lines_out.append(' '.join(parts))
    if not lines_out:
        return False
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    with open(dst_path, 'w') as f:
        f.write('\n'.join(lines_out) + '\n')
    return True


def process_source(source_dir, prefix, class_map, stats):
    if not source_dir.exists():
        raise FileNotFoundError(f"Source not found: {source_dir}")
    for split in SPLITS:
        img_src = source_dir / split / 'images'
        lbl_src = source_dir / split / 'labels'
        if not img_src.exists() or not lbl_src.exists():
            continue
        img_dst = OUTPUT_DIR / split / 'images'
        lbl_dst = OUTPUT_DIR / split / 'labels'
        img_dst.mkdir(parents=True, exist_ok=True)
        lbl_dst.mkdir(parents=True, exist_ok=True)
        copied = 0
        for img_file in img_src.iterdir():
            if img_file.suffix.lower() not in ('.jpg', '.jpeg', '.png'):
                continue
            label_file = lbl_src / (img_file.stem + '.txt')
            if not label_file.exists():
                continue
            new_stem = f"{prefix}_{img_file.stem}"
            new_img = img_dst / (new_stem + img_file.suffix.lower())
            new_lbl = lbl_dst / (new_stem + '.txt')
            if remap_label_file(label_file, new_lbl, class_map):
                shutil.copy2(img_file, new_img)
                copied += 1
        stats[split] = stats.get(split, 0) + copied
        print(f"  [{prefix}] {split}: copied {copied} images")


def write_data_yaml():
    yaml_path = OUTPUT_DIR / 'data.yaml'
    with open(yaml_path, 'w') as f:
        f.write("# SortifyX merged dataset (TrashNet + Organic)\n")
        f.write("train: train/images\nval: valid/images\ntest: test/images\n\n")
        f.write(f"nc: {len(TARGET_NAMES)}\nnames:\n")
        for i, n in enumerate(TARGET_NAMES):
            f.write(f"  {i}: {n}\n")
    print(f"\nWrote {yaml_path}")


def main():
    for split in SPLITS:
        for sub in ('images', 'labels'):
            p = OUTPUT_DIR / split / sub
            if p.exists():
                shutil.rmtree(p)
    stats = {}
    print("Merging TrashNet...")
    process_source(Path(TRASHNET_DIR), 't', TRASHNET_MAP, stats)
    print("\nMerging Organic...")
    process_source(Path(ORGANIC_DIR), 'o', ORGANIC_MAP, stats)
    write_data_yaml()
    print("\nFinal counts:")
    for split, n in stats.items():
        print(f"  {split}: {n} images")
    print("\nDone. Run: python train_model.py")


if __name__ == '__main__':
    main()