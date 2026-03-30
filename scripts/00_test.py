"""
テスト用スクリプト
main.shを実行し、このスクリプトを呼び出すとresukts/yymmdd_hhmm_jobid/test.txtを作成してSccess!と書き込む。
その後results以下がrsyncされて管理ノード側のディレクトリ内に現れることを確認できれば問題なく利用可能です。
"""

import argparse
import os

parser = argparse.ArgumentParser()
parser.add_argument("--out", type=str, required=True, help="Output directory")
args = parser.parse_args()

# 書き出し先のパスを作成
path = os.path.join(args.out, "test.txt")

os.makedirs(args.out, exist_ok=True)

with open(path, mode='w') as f: 
    f.write("Success!")