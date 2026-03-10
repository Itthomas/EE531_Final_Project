import argparse
from pathlib import Path

import matplotlib.pyplot as plt


def load_signal(file_path: Path):
    values = []
    with file_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                values.append(float(line))
    return values


def main():
    parser = argparse.ArgumentParser(description="Plot ECG signal from a text file.")
    parser.add_argument(
        "--input",
        type=Path,
        default=Path(__file__).with_name("ecg_input_100.txt"),
        help="Path to ECG text file (one sample per line).",
    )
    args = parser.parse_args()

    signal = load_signal(args.input)

    plt.figure(figsize=(10, 4))
    plt.plot(signal, linewidth=1.0)
    plt.title("ECG Signal")
    plt.xlabel("Sample Index")
    plt.ylabel("Amplitude")
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.show()


if __name__ == "__main__":
    main()
