import argparse
import re
from pathlib import Path

import matplotlib.pyplot as plt

LINE_RE = re.compile(
    r"sample=(?P<sample>-?\d+)\s+state=(?P<state>\S+)\s+timestep=(?P<timestep>-?\d+)"
    r"\s+dm=(?P<dm>[01]+)\s+L0=(?P<L0>[01]{8})\s+L1=(?P<L1>[01]{8})"
    r"\s+L2=(?P<L2>[01]{8})\s+L3=(?P<L3>[01]{8})\s+pred=(?P<pred>-?\d+)\s+match=(?P<match>-?\d+)"
)


def parse_log(file_path: Path):
    records = []
    with file_path.open("r", encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue

            m = LINE_RE.match(line)
            if not m:
                continue

            records.append(
                {
                    "sample": int(m.group("sample")),
                    "state": m.group("state"),
                    "timestep": int(m.group("timestep")),
                    "dm": m.group("dm"),
                    "L0": m.group("L0"),
                    "L1": m.group("L1"),
                    "L2": m.group("L2"),
                    "L3": m.group("L3"),
                    "pred": int(m.group("pred")),
                    "match": int(m.group("match")),
                }
            )
    return records


def spikes_from_bits(bitstring: str):
    # Treat left-most bit as neuron 0 for simple visual indexing.
    return [idx for idx, bit in enumerate(bitstring) if bit == "1"]


def build_raster_points(records):
    layer_keys = ["dm", "L0", "L1", "L2", "L3"]
    layer_sizes = {k: len(records[0][k]) for k in layer_keys}

    offsets = {}
    tick_positions = []
    tick_labels = []
    running_offset = 0
    for key in layer_keys:
        offsets[key] = running_offset
        tick_positions.append(running_offset + (layer_sizes[key] - 1) / 2)
        tick_labels.append(key.upper())
        running_offset += layer_sizes[key]

    x_points = []
    y_points = []
    for event_idx, rec in enumerate(records):
        for key in layer_keys:
            spikes = spikes_from_bits(rec[key])
            for neuron_idx in spikes:
                y = offsets[key] + neuron_idx
                x_points.append(event_idx)
                y_points.append(y)
    
    # Compute boundaries between layers for separator lines
    layer_boundaries = []
    for i in range(len(layer_keys) - 1):
        boundary = offsets[layer_keys[i]] + layer_sizes[layer_keys[i]]
        layer_boundaries.append(boundary-0.5)
    
    return x_points, y_points, tick_positions, tick_labels, layer_boundaries


def main():
    parser = argparse.ArgumentParser(
        description="Plot L0-L3 spike raster and match line from spike log"
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=Path(__file__).with_name("spike_raster_log.txt"),
        help="Path to spike_raster_log.txt",
    )
    parser.add_argument(
        "--state",
        choices=["all", "S_UPDATE", "S_DONE"],
        default="all",
        help="Filter records by state before plotting",
    )
    args = parser.parse_args()

    records = parse_log(args.input)
    if args.state != "all":
        records = [r for r in records if r["state"] == args.state]

    if not records:
        raise ValueError("No valid records found in log after parsing/filtering")

    raster_x, raster_y, tick_positions, tick_labels, layer_boundaries = build_raster_points(records)
    match_values = [r["match"] for r in records]
    xs = list(range(len(records)))

    fig, (ax_raster, ax_match) = plt.subplots(
        2,
        1,
        figsize=(12, 7),
        sharex=True,
        gridspec_kw={"height_ratios": [3, 1]},
    )

    ax_raster.scatter(raster_x, raster_y, s=12, marker="|", color="black")
    
    # Draw horizontal lines to separate layers
    for boundary in layer_boundaries:
        ax_raster.axhline(y=boundary, color="gray", linestyle="--", linewidth=0.9)
    
    ax_raster.set_title("Spike Raster (DM + L0-L3)")
    ax_raster.set_ylabel("Layer/Neuron")
    ax_raster.set_yticks(tick_positions)
    ax_raster.set_yticklabels(tick_labels)
    ax_raster.grid(True, alpha=0.25)

    ax_match.plot(xs, match_values, color="tab:red", linewidth=1.5)
    ax_match.set_title("Binary Classification Output (1=match, 0=mismatch)")
    ax_match.set_xlabel("Record Index")
    ax_match.set_ylabel("Match")
    ax_match.grid(True, alpha=0.25)

    plt.tight_layout()
    plt.show()


if __name__ == "__main__":
    main()
