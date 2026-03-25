import argparse
import os

parser = argparse.ArgumentParser()
parser.add_argument("--out", type=str, required=True, help="Output directory")
args = parser.parse_args()

# 書き出し先のパスを作成
path = os.path.join(args.out, "test.txt")

# ディレクトリが存在することを確認（念のため）
os.makedirs(args.out, exist_ok=True)

with open(path, mode='w') as f: # 'x'モードでもOK
    f.write("Success!")